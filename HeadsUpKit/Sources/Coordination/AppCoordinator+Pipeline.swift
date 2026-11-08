import CoreGraphics
import Foundation

/// Per-sample processing: filtering, tilt-holds, calibration, recentering and tracking.
extension AppCoordinator {
    func handle(pose sensorPose: HeadPose) {
        recorder.record(sensorPose)
        meter.recordSample()
        if !isHeadphonesConnected { handleConnection(.connected) }

        let raw = sensorPose.adjusted(
            invertYaw: settings.invertYaw, invertPitch: settings.invertPitch, invertRoll: settings.invertRoll)
        let filtered = poseFilter.filter(raw)
        lastFilteredPose = filtered
        publishTelemetry(filtered)

        switch state {
        case .needsPermissions, .waitingForHeadphones:
            break
        case .calibrating:
            handleCalibration(filtered)
        case .awaitingRecenter:
            handleTilt(raw)
            if state == .awaitingRecenter { handleAutoRecenter(filtered) }
        case .paused:
            handleTilt(raw)
        case .tracking:
            handleTilt(raw)
            if state == .tracking { handleTracking(raw: raw, filtered: filtered) }
        }
    }

    // MARK: Tilt-hold (works in tracking, awaitingRecenter and paused)

    private func handleTilt(_ pose: HeadPose) {
        for event in tilt.process(pose) {
            switch event {
            case let .holdProgress(gesture, fraction):
                if isTiltAvailable(gesture) { holdProgress = HoldProgress(gesture: gesture, fraction: fraction) }
            case .holdCancelled:
                holdProgress = nil
            case let .confirmed(gesture, _):
                holdProgress = nil
                guard isTiltAvailable(gesture) else { continue }
                lastGesture = gesture
                switch dispatcher.action(for: gesture) {
                case .togglePause:
                    togglePause()
                case .recenter:
                    recenter()
                case .click, .escape:
                    let point = deps.cursor.currentPosition
                    post { dispatcher.dispatch(gesture, at: point) }
                case .none:
                    break
                }
            case .candidateBegan, .candidateCancelled:
                break
            }
        }
    }

    /// While paused only the pause toggle works, so the user can always resume.
    private func isTiltAvailable(_ gesture: HeadGesture) -> Bool {
        state != .paused || dispatcher.action(for: gesture) == .togglePause
    }

    // MARK: Recentering

    /// Makes the current pose neutral (keeping the calibrated ranges) and puts the cursor
    /// in the center of the screen.
    public func recenter() {
        guard state == .tracking || state == .awaitingRecenter,
              let pose = lastFilteredPose, let current = calibration else { return }
        let updated = current.recentered(to: CapturedPose(pose))
        calibration = updated
        deps.calibrationStore.save(updated)
        tilt.rollReference = pose.roll
        needsRecenter = false
        enterTracking(cursorAt: nil)
        moveToCenter(at: pose.timestamp)
        deps.feedback.play(.recentered)
    }

    private func handleAutoRecenter(_ pose: HeadPose) {
        // A tilted head means the user is doing a tilt-hold, not holding still for recenter.
        let roll = abs(AngleMath.wrap(pose.roll - tilt.rollReference))
        if roll > tilt.config.threshold * tilt.config.releaseFraction {
            stillness.reset()
            return
        }
        let progress = stillness.update(pose)
        holdProgress = progress > 0 ? HoldProgress(gesture: .tiltHoldRight, fraction: progress) : nil
        if progress >= 1 {
            stillness.reset()
            recenter()
        }
    }

    private func moveToCenter(at time: TimeInterval) {
        guard let center = engine?.centerPoint else { return }
        post { deps.cursor.move(to: center) }
        engine?.noteCursor(at: center, time: time)
    }

    // MARK: Tracking

    private func handleTracking(raw: HeadPose, filtered: HeadPose) {
        let commands = engine?.process(raw: raw, filtered: filtered) ?? []
        for command in commands {
            switch command {
            case let .move(point):
                post { deps.cursor.move(to: point) }
            case let .perform(gesture, point):
                lastGesture = gesture
                post { dispatcher.dispatch(gesture, at: point) }
            }
        }
    }

    // MARK: Calibration

    func beginCalibration() {
        guard isHeadphonesConnected else {
            enter(.waitingForHeadphones)
            return
        }
        calibrationSession = CalibrationSession(settings: settings)
        calibrationProgress = 0
        calibrationMessage = nil
        enter(.calibrating(.center))
        announce(CalibrationStep.center.prompt)
    }

    private func handleCalibration(_ pose: HeadPose) {
        guard var session = calibrationSession else { return }
        let update = session.process(pose)
        calibrationSession = session

        switch update {
        case let .progress(progress):
            calibrationProgress = progress
        case let .captured(_, next):
            calibrationProgress = 0
            deps.feedback.play(.calibrationStep)
            enter(.calibrating(next))
            announce(next.prompt)
        case let .finished(result):
            calibration = result
            deps.calibrationStore.save(result)
            tilt.rollReference = result.neutralRoll
            needsRecenter = false
            calibrationSession = nil
            calibrationMessage = nil
            calibrationProgress = 0
            deps.feedback.play(.calibrationDone)
            enterTracking(cursorAt: nil)
            moveToCenter(at: pose.timestamp)
            announce("Calibration complete. Nod to click, shake to cancel.")
        case let .failed(error):
            deps.feedback.play(.error)
            calibrationMessage = error.userMessage
            calibrationSession = CalibrationSession(settings: settings)
            calibrationProgress = 0
            enter(.calibrating(.center))
            announce(error.userMessage + " " + CalibrationStep.center.prompt)
        }
    }

    // MARK: Telemetry

    private func publishTelemetry(_ pose: HeadPose) {
        let interval = 1 / max(settings.telemetryRateHz, 1)
        guard abs(pose.timestamp - lastTelemetryTime) >= interval else { return }
        lastTelemetryTime = pose.timestamp
        telemetry.pose = pose
    }

    /// Called once per diagnostics interval on the wall clock, so a stall in background
    /// delivery shows up as 0 samples/s rather than a stale number.
    func reportSampleRate(interval: TimeInterval) {
        let rate = meter.takeRate(interval: interval)
        let active = deps.isAppActive()
        telemetry.samplesPerSecond = rate
        telemetry.isAppActive = active
        if !active { telemetry.backgroundSamplesPerSecond = rate }
        guard isHeadphonesConnected else { return }
        Self.log.info(
            "motion samples/s=\(rate, format: .fixed(precision: 1), privacy: .public) frontmost=\(active, privacy: .public)")
    }
}
