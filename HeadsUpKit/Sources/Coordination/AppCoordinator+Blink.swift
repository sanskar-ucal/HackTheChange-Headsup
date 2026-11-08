import CoreGraphics
import Foundation

/// Camera blink gestures: double blink = click, triple blink = Escape, as an alternative to
/// nod and shake. The camera runs only while the setting is on and HeadsUp is in use; blink
/// actions fire only while tracking and go through the same `perform` → `postAction` gate.
extension AppCoordinator {
    /// States in which the camera runs. Paused, calibrating, waiting for AirPods and missing
    /// permissions turn it off; the short voice and scroll modes keep it on to avoid
    /// relearning the open-eye baseline each time.
    static func cameraRuns(in state: AppState) -> Bool {
        switch state {
        case .tracking, .scrollMode, .listening, .voiceReview, .awaitingRecenter, .practicing: return true
        case .needsPermissions, .waitingForHeadphones, .calibrating, .paused: return false
        }
    }

    /// Starts or stops the camera to match the setting and state. Idempotent.
    func updateBlinkCapture() {
        let wanted = isStarted && settings.blinkGesturesEnabled && Self.cameraRuns(in: state)
        guard let source = deps.blinkSource else {
            cameraStatus = settings.blinkGesturesEnabled ? .noCamera : .off
            return
        }
        guard wanted != blinkCaptureActive else {
            if !blinkCaptureActive { cameraStatus = idleCameraStatus(source) }
            return
        }
        blinkCaptureActive = wanted
        eyeClassifier.reset()
        resetBlinkSequence()
        if wanted {
            cameraStatus = .starting
            source.start { [weak self] event in self?.handleBlinkSource(event) }
        } else {
            source.stop()
            cameraStatus = idleCameraStatus(source)
            telemetry.blink = BlinkReadout()
        }
    }

    /// Stops and restarts the camera, e.g. after granting access in System Settings.
    public func retryBlinkCamera() {
        if blinkCaptureActive {
            blinkCaptureActive = false
            deps.blinkSource?.stop()
        }
        updateBlinkCapture()
    }

    func applyBlinkSettings(_ newSettings: HeadsUpSettings, turningOn: Bool) {
        eyeClassifier.configuration = EyeOpennessClassifier.Configuration(settings: newSettings)
        blinkRecognizer.configuration = BlinkSequenceRecognizer.Configuration(settings: newSettings)
        // Ask for camera access when the user turns the feature on, not later mid-use.
        if turningOn, let source = deps.blinkSource, source.authorization == .notDetermined {
            cameraStatus = .requestingAccess
            source.requestAccess { [weak self] _ in self?.updateBlinkCapture() }
            return
        }
        updateBlinkCapture()
    }

    func resetBlinkSequence() {
        blinkRecognizer.reset()
        blinkClickPoint = nil
    }

    func handleBlinkSource(_ event: BlinkSourceEvent) {
        // Late events after stop() never act.
        guard blinkCaptureActive else { return }
        switch event {
        case let .status(status):
            cameraStatus = status
            if status != .running {
                eyeClassifier.reset()
                resetBlinkSequence()
                publishBlinkReadout(face: .waitingForCamera, eyesClosed: false)
            }
        case let .observation(observation):
            guard cameraStatus == .running else { return }
            handle(eyes: observation)
        }
    }

    func handle(eyes observation: EyeObservation) {
        var eyesClosed: Bool?
        let face: BlinkReadout.Face
        switch observation.reading {
        case let .eyes(openness):
            eyesClosed = eyeClassifier.classify(openness, at: observation.timestamp)
            face = eyeClassifier.isLearning ? .learning : .tracked
        case .noFace: face = .noFace
        case .multipleFaces: face = .multipleFaces
        case .eyesNotFound: face = .eyesNotFound
        }

        guard state == .tracking else {
            resetBlinkSequence()
            publishBlinkReadout(face: face, eyesClosed: eyesClosed ?? false)
            return
        }

        let before = blinkRecognizer.blinkCount
        let command = blinkRecognizer.process(eyesClosed: eyesClosed, at: observation.timestamp)
        if blinkRecognizer.blinkCount == 2, before != 2 { blinkClickPoint = deps.cursor.currentPosition }
        publishBlinkReadout(face: face, eyesClosed: eyesClosed ?? false, command: command)

        switch command {
        case .select:
            let point = blinkClickPoint ?? deps.cursor.currentPosition
            blinkClickPoint = nil
            logBlink("double blink confirmed: click")
            perform(.doubleBlink, at: point)
        case .cancel:
            blinkClickPoint = nil
            logBlink("triple blink confirmed: Escape")
            perform(.tripleBlink, at: deps.cursor.currentPosition)
        case nil:
            if blinkRecognizer.blinkCount == 0 { blinkClickPoint = nil }
        }
    }

    /// Blink actions appear in the same gesture log as nods and shakes.
    private func logBlink(_ line: String) {
        telemetry.appendGestureLog(line)
        Self.log.debug("gesture \(line, privacy: .public)")
    }

    private func idleCameraStatus(_ source: BlinkSource) -> CameraStatus {
        guard settings.blinkGesturesEnabled else { return .off }
        switch source.authorization {
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined, .authorized: return .standby
        }
    }

    private func publishBlinkReadout(face: BlinkReadout.Face, eyesClosed: Bool, command: BlinkCommand? = nil) {
        var readout = telemetry.blink
        readout.face = face
        readout.eyesClosed = eyesClosed
        readout.pendingBlinks = blinkRecognizer.blinkCount
        readout.blinksSeen = blinkRecognizer.totalBlinks
        if let command { readout.lastCommand = command }
        if readout != telemetry.blink { telemetry.blink = readout }
    }
}
