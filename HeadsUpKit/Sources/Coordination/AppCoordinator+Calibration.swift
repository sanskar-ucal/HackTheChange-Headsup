import CoreGraphics
import Foundation

/// Hands-free calibration and the first-run practice that follows it.
extension AppCoordinator {
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

    func handleCalibration(_ pose: HeadPose) {
        guard var session = calibrationSession else { return }
        let update = session.process(pose)
        calibrationSession = session

        switch update {
        case let .progress(progress):
            calibrationProgress = progress
        case .rejected:
            calibrationProgress = 0
            calibrationMessage = "Hold your head still on the dot."
        case let .captured(_, next):
            calibrationProgress = 0
            calibrationMessage = nil
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
            let practicing = settings.practiceEnabled
            enterTracking(cursorAt: deps.cursor.currentPosition, glide: false, as: practicing ? .practicing : .tracking)
            glideToCenter(at: pose.timestamp)
            if practicing {
                practice = PracticeSession(settings: settings)
                announce("Calibration complete. Practice: point at each circle and nod.")
            } else {
                announce("Calibration complete. Nod to click, shake to cancel.")
            }
        case let .failed(error):
            deps.feedback.play(.error)
            calibrationMessage = error.userMessage
            calibrationSession = CalibrationSession(settings: settings)
            calibrationProgress = 0
            enter(.calibrating(.center))
            announce(error.userMessage + " " + CalibrationStep.center.prompt)
        }
    }

    // MARK: Practice

    /// Pointer moves normally; nods hit practice targets instead of clicking.
    func handlePractice(raw: HeadPose, filtered: HeadPose) {
        guard var session = practice, let output = engine?.process(raw: raw, filtered: filtered) else { return }
        if !applyGestureFreeze(output) { acceptTarget(output.target) }
        let rect = pointingRect
        let aspect = Double(rect.width / max(rect.height, 1))
        let pointer = engine?.normalized(output.target) ?? .center
        var changed = session.update(pointer: pointer, aspect: aspect, time: raw.timestamp)

        for case let .perform(gesture, point, _) in output.commands {
            switch (session.phase, gesture) {
            case (.running, .nod):
                let hit = session.registerNod(at: engine?.normalized(point) ?? pointer, aspect: aspect)
                deps.feedback.play(hit ? .select : .cancel)
                changed = true
            case let (.suggesting(value), .nod):
                var updated = settings
                updated.sensitivity = value
                deps.updateSettings(updated)
                apply(settings: updated)
                finishPractice("Sensitivity set. Nod to click, shake to cancel.")
                return
            case (.suggesting, .shake):
                finishPractice("Keeping your current sensitivity. Nod to click, shake to cancel.")
                return
            default:
                break
            }
        }
        if changed {
            if case let .suggesting(value) = session.phase, practice?.phase == .running {
                deps.feedback.play(.calibrationDone)
                announce(String(format: "Suggested sensitivity %.2f. Nod to accept, or shake to keep %.2f.",
                                value, session.currentSensitivity))
            }
            practice = session
        }
    }

    private func finishPractice(_ message: String) {
        deps.feedback.play(.select)
        practice = nil
        enter(.tracking)
        announce(message)
    }
}
