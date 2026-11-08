import CoreGraphics
import Foundation

/// Webcam blink controls: camera lifecycle, blink → action routing and live telemetry.
extension AppCoordinator {
    var blinksActive: Bool {
        settings.clickInput.blinksActive(blinkEnabled: settings.blinkEnabled)
    }

    /// The camera only runs while blink controls are on and HeadsUp is tracking.
    func updateCamera() {
        guard let source = deps.faceSource else { return }
        let shouldRun = blinksActive && state == .tracking
        if blinksActive, !shouldRun { requestCameraAccessIfNeeded() }
        if shouldRun, !source.isRunning {
            blinkTelemetry.camera = .starting
            source.start()
        } else if !shouldRun, source.isRunning {
            source.stop()
            blinkTelemetry.camera = .off
            blinkTelemetry.fps = 0
            cameraFpsWindowStart = nil
        }
        if !shouldRun { resetBlinks() }
    }

    /// Asks for camera access as soon as blink controls are turned on, so the prompt doesn't wait for tracking.
    private func requestCameraAccessIfNeeded() {
        guard !cameraAccessRequested, deps.permissions.currentStatus().camera == .notDetermined else { return }
        cameraAccessRequested = true
        logCamera("camera permission: not determined (asking)")
        deps.permissions.requestCamera()
    }

    public func retryCamera() {
        deps.faceSource?.stop()
        updateCamera()
    }

    /// Plays the click cue so the user can check the AirPods route and volume.
    public func playTestSound() {
        deps.feedback.play(.select)
    }

    public func openCameraSettings() {
        deps.permissions.openCameraSettings()
    }

    func handleCameraFailure(_ message: String) {
        let camera = deps.permissions.currentStatus().camera
        blinkTelemetry.camera = camera == .denied || camera == .restricted ? .denied : .failed(message)
        blinkTelemetry.fps = 0
        logCamera("camera error: \(message)")
        resetBlinks()
        guard !cameraRetryPending else { return }
        cameraRetryPending = true
        deps.schedule(5) { [weak self] in
            guard let self else { return }
            self.cameraRetryPending = false
            switch self.blinkTelemetry.camera {
            case .failed, .denied: self.updateCamera()
            case .off, .starting, .running: break
            }
        }
    }

    func logCamera(_ line: String) {
        telemetry.appendGestureLog(line)
        Self.log.info("\(line, privacy: .public)")
    }

    /// Frames per second over 1 s windows, logged every 5 s.
    private func measureCameraRate(at time: TimeInterval) {
        guard let start = cameraFpsWindowStart else {
            cameraFpsWindowStart = time
            cameraFrameCount = 0
            return
        }
        cameraFrameCount += 1
        let elapsed = time - start
        guard elapsed >= 1 else { return }
        blinkTelemetry.fps = Double(cameraFrameCount) / elapsed
        cameraFpsWindowStart = time
        cameraFrameCount = 0
        if time - lastCameraFpsLog >= 5 {
            lastCameraFpsLog = time
            logCamera(String(format: "camera frames/s: %.1f", blinkTelemetry.fps))
        }
    }

    func handle(faceFrame frame: FaceFrame) {
        measureCameraRate(at: frame.timestamp)
        let quality = blinkQuality.assess(frame)
        var sequenceEvents: [BlinkSequenceEvent] = []
        let headMoving = headRateDegPerSec > settings.blinkMaxHeadRateDegPerSec
        if quality != .ok || state != .tracking || !blinksActive || headMoving {
            blinkDetector.reset()
            sequenceEvents += blinkSequence.reset()
        } else if let eyes = frame.eyes {
            for event in blinkDetector.process(eyes, at: frame.timestamp) {
                if case .closed = event {
                    // The click lands where the pointer was when the first blink began.
                    if blinkSequence.count == 0 {
                        blinkAnchor = lastPostedPoint ?? deps.cursor.currentPosition
                    } else {
                        holdPointerForBlink()
                    }
                }
                sequenceEvents += blinkSequence.handle(event)
            }
            sequenceEvents += blinkSequence.update(now: frame.timestamp)
        }
        for event in sequenceEvents { handleBlinkSequence(event) }
        publishBlinkTelemetry(frame: frame, quality: quality)
    }

    private func handleBlinkSequence(_ event: BlinkSequenceEvent) {
        switch event {
        case let .counting(count, _):
            blinkSequenceCount = count
        case let .recognized(pattern, _):
            blinkSequenceCount = 0
            let gesture: HeadGesture = pattern == .double ? .doubleBlink : .tripleBlink
            let point = blinkAnchor ?? lastPostedPoint ?? deps.cursor.currentPosition
            let action = dispatcher.action(for: gesture)
            blinkHold = false
            perform(gesture, at: point)
            if action != .click, pointerFrozen, freezeUntil == nil { releasePointer() }
            blinkTelemetry.lastAction = pattern == .double ? "Double blink → Click" : "Triple blink → Escape"
            blinkAnchor = nil
        case .cancelled:
            blinkSequenceCount = 0
            blinkAnchor = nil
            endBlinkHold()
        }
    }

    private func holdPointerForBlink() {
        guard !blinkHold, !pointerFrozen, let anchor = blinkAnchor else { return }
        blinkHold = true
        animator.place(at: anchor)
        frozenPoint = anchor
        pointerFrozen = true
        freezeUntil = nil
    }

    private func endBlinkHold() {
        guard blinkHold else { return }
        blinkHold = false
        if pointerFrozen, freezeUntil == nil { releasePointer() }
    }

    func resetBlinks() {
        blinkDetector.reset()
        _ = blinkSequence.reset()
        blinkAnchor = nil
        blinkSequenceCount = 0
        endBlinkHold()
    }

    func configureBlinks(_ newSettings: HeadsUpSettings) {
        blinkDetector.config = BlinkConfig(settings: newSettings)
        blinkSequence.config = BlinkSequenceConfig(settings: newSettings)
        blinkQuality = BlinkQualityMonitor(settings: newSettings)
    }

    private func publishBlinkTelemetry(frame: FaceFrame, quality: BlinkQuality) {
        let telemetry = blinkTelemetry
        if telemetry.camera != .running { telemetry.camera = .running }
        if telemetry.quality != quality { telemetry.quality = quality }
        if telemetry.sequenceCount != blinkSequenceCount { telemetry.sequenceCount = blinkSequenceCount }
        guard frame.timestamp - telemetry.lastPublish >= 1.0 / 15 else { return }
        telemetry.lastPublish = frame.timestamp
        telemetry.leftEAR = blinkDetector.filteredLeft
        telemetry.rightEAR = blinkDetector.filteredRight
        telemetry.leftThreshold = blinkDetector.leftCloseThreshold
        telemetry.rightThreshold = blinkDetector.rightCloseThreshold
    }
}
