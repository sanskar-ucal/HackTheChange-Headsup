import CoreGraphics
import Foundation

/// Per-sample processing: filtering, tilt-holds, calibration, recentering and tracking.
extension AppCoordinator {
    func handle(pose sensorPose: HeadPose) {
        let interval = Self.signposter.beginInterval("pose")
        defer { Self.signposter.endInterval("pose", interval) }
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
            handleCalibration(raw)
        case .awaitingRecenter:
            handleTilt(raw)
            if state == .awaitingRecenter { handleAutoRecenter(filtered) }
        case .paused:
            handleTilt(raw)
        case .tracking:
            handleTilt(raw)
            if state == .tracking { handleTracking(raw: raw, filtered: filtered) }
        case .practicing:
            handleTilt(raw)
            if state == .practicing { handlePractice(raw: raw, filtered: filtered) }
        case .scrollMode:
            handleTilt(raw)
            if state == .scrollMode { handleScrollMode(raw: raw, filtered: filtered) }
        case .listening, .voiceReview:
            handleTilt(raw)
            if state == .listening || state == .voiceReview { handleVoiceGestures(raw) }
        }
        fallbackFrameIfStalled()
    }

    // MARK: Tilt-hold

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
                case .togglePause: togglePause()
                case .recenter: recenter()
                case .toggleScrollMode: enterScrollMode()
                case .click, .escape:
                    let point = deps.cursor.currentPosition
                    postAction { dispatcher.dispatch(gesture, at: point) }
                case .none: break
                }
            case .candidateBegan, .candidateCancelled:
                break
            }
        }
    }

    /// While paused or using voice input only the pause toggle works, so the user can always resume.
    private func isTiltAvailable(_ gesture: HeadGesture) -> Bool {
        switch state {
        case .paused, .listening, .voiceReview: return dispatcher.action(for: gesture) == .togglePause
        default: return true
        }
    }

    // MARK: Recentering

    /// Makes the current pose neutral.
    public func recenter() {
        guard state == .tracking || state == .awaitingRecenter,
              let pose = lastFilteredPose, let current = calibration else { return }
        let updated = current.recentered(to: CapturedPose(pose))
        calibration = updated
        deps.calibrationStore.save(updated)
        tilt.rollReference = pose.roll
        needsRecenter = false
        enterTracking(cursorAt: deps.cursor.currentPosition, glide: false)
        glideToCenter(at: pose.timestamp)
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

    func glideToCenter(at time: TimeInterval) {
        guard let center = engine?.centerPoint else { return }
        animator.glide(to: center, duration: settings.glideDuration)
        pointerTarget = center
        engine?.noteCursor(at: center, time: time)
    }

    // MARK: Tracking

    private func handleTracking(raw: HeadPose, filtered: HeadPose) {
        guard let output = engine?.process(raw: raw, filtered: filtered) else { return }
        // A just-released freeze waits for the next (re-filtered) sample as its target.
        if !applyGestureFreeze(output) { acceptTarget(output.target) }

        scrollVelocity = ScrollVelocity.edgePush(output.overshoot, settings: settings)

        for case let .perform(gesture, point, _) in output.commands {
            perform(gesture, at: frozenPoint ?? point)
        }
    }

    /// The moment a gesture starts, freeze the real cursor exactly where it is.
    @discardableResult
    func applyGestureFreeze(_ output: TrackingEngine.Output) -> Bool {
        if let decision = output.decision { logGesture(decision) }
        if output.didFreeze {
            let here = lastPostedPoint ?? animator.position ?? deps.cursor.currentPosition
            animator.place(at: here)
            frozenPoint = here
            pointerFrozen = true
            freezeUntil = nil
        } else if !output.isFrozen, pointerFrozen, freezeUntil == nil {
            releasePointer()
            return true
        }
        return false
    }

    /// Ends a freeze by gliding (no jump) from the frozen spot to the head-pointed position.
    func releasePointer() {
        pointerFrozen = false
        freezeUntil = nil
        frozenPoint = nil
        poseFilter.reset()
        pointerTarget = nil
        releaseGlidePending = true
    }

    func logGesture(_ decision: GestureDecision) {
        telemetry.appendGestureLog(decision.logLine)
        Self.log.debug("gesture \(decision.logLine, privacy: .public)")
    }

    func acceptTarget(_ point: CGPoint) {
        pointerTarget = point
        targetUpdatedAt = deps.clock()
        if releaseGlidePending, !pointerFrozen {
            releaseGlidePending = false
            animator.glide(to: point, duration: settings.releaseGlideDuration)
        }
        if glideOnNextTarget {
            glideOnNextTarget = false
            animator.glide(to: point, duration: settings.glideDuration)
        }
    }

    private func perform(_ gesture: HeadGesture, at point: CGPoint) {
        lastGesture = gesture
        switch dispatcher.action(for: gesture) {
        case .click:
            // A nod on the scroll-to-top button sends the key instead of a mouse click, so the
            // browser never sees a click near its toolbar.
            let onTopButton = isOnScrollToTopButton(point)
            if onTopButton {
                scrollToTop()
            } else {
                // Click exactly at the frozen spot, then keep the cursor still like a mouse ("Hold after click").
                postAction { dispatcher.dispatch(gesture, at: point) }
            }
            animator.place(at: point)
            lastPostedPoint = point
            frozenPoint = point
            pointerFrozen = true
            freezeUntil = deps.clock() + settings.holdAfterClick
            pressingUntil = deps.clock() + 0.2
            if !onTopButton { didPerformClick() }
        case .escape:
            postAction { dispatcher.dispatch(gesture, at: point) }
        case .toggleScrollMode:
            enterScrollMode()
        case .togglePause:
            togglePause()
        case .recenter:
            recenter()
        case .none:
            break
        }
    }

    // MARK: Telemetry

    private func publishTelemetry(_ pose: HeadPose) {
        let interval = 1 / max(settings.telemetryRateHz, 1)
        guard abs(pose.timestamp - lastTelemetryTime) >= interval else { return }
        lastTelemetryTime = pose.timestamp
        telemetry.pose = pose
    }
}
