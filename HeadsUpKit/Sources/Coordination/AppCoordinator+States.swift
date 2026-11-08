import CoreGraphics
import Foundation

/// State transitions: headphones, pause/resume, and the single event gates.
extension AppCoordinator {
    func handleConnection(_ change: HeadphoneConnection) {
        switch change {
        case .connected:
            guard !isHeadphonesConnected else { return }
            isHeadphonesConnected = true
            if state == .waitingForHeadphones || (state == .paused && pauseReason == .headphonesDisconnected) {
                pauseReason = nil
                proceed()
            }
        case .disconnected:
            guard isHeadphonesConnected else { return }
            isHeadphonesConnected = false
            needsRecenter = true  // the yaw reference resets on reconnect
            poseFilter.reset()
            switch state {
            case .tracking, .awaitingRecenter, .calibrating, .practicing, .scrollMode, .listening, .voiceReview:
                pause(reason: .headphonesDisconnected)
            case .needsPermissions, .waitingForHeadphones, .paused:
                break
            }
        }
    }

    // MARK: Commands (gestures, menu, hotkey)

    public func togglePause() {
        switch state {
        case .paused: resume()
        case .tracking, .awaitingRecenter, .calibrating, .practicing, .scrollMode, .listening, .voiceReview:
            pause(reason: .user)
        case .needsPermissions, .waitingForHeadphones: break
        }
    }

    public func recalibrate() {
        guard permissionStatus.isReady else { return }
        beginCalibration()
    }

    func pause(reason: PauseReason) {
        if state == .listening { deps.speech.cancel() }
        pauseReason = reason
        calibrationSession = nil
        practice = nil
        enter(.paused)
        deps.feedback.play(.paused)
        switch reason {
        case .user: announce("Paused. Tilt your head left and hold to resume.")
        case .headphonesDisconnected: announce("Headphones disconnected. HeadsUp is paused.")
        }
    }

    func resume() {
        pauseReason = nil
        deps.feedback.play(.resumed)
        proceed()
        if state == .tracking { announce("Resumed.") }
    }

    /// Moves to whichever state the current conditions allow.
    func proceed() {
        if !permissionStatus.isReady {
            enter(.needsPermissions)
        } else if !isHeadphonesConnected {
            enter(.waitingForHeadphones)
        } else if calibration == nil {
            beginCalibration()
        } else if needsRecenter {
            stillness.reset()
            enter(.awaitingRecenter)
            announce("Look at the center of the screen and hold still to recenter.")
        } else {
            enterTracking(cursorAt: deps.cursor.currentPosition, glide: true)
        }
    }

    func enter(_ newState: AppState) {
        holdProgress = nil
        pointerFrozen = false
        frozenPoint = nil
        freezeUntil = nil
        releaseGlidePending = false
        scrollVelocity = .zero
        if newState != .listening && newState != .voiceReview { transcript = "" }
        state = newState
        switch newState {
        case .needsPermissions, .waitingForHeadphones: deps.keepAlive.stop()
        default: deps.keepAlive.start()
        }
        updatePointerContext()
    }

    /// Builds a fresh tracking pipeline starting from the real cursor position.
    /// - Parameter glide: ease to the head position over `glideDuration` once it is known.
    func enterTracking(cursorAt point: CGPoint, glide: Bool, as newState: AppState = .tracking) {
        guard let calibration else { return }
        var engine = TrackingEngine(calibration: calibration, geometry: deps.screenGeometry(), settings: settings)
        engine.reset()
        self.engine = engine
        animator.place(at: point)
        lastPostedPoint = point
        pointerTarget = nil
        glideOnNextTarget = glide
        enter(newState)
    }

    /// Returns to plain tracking after scroll mode or voice input, keeping the pointer where it is.
    func returnToTracking() {
        engine?.resetGestures()
        enter(.tracking)
    }

    /// Gate for pointer moves.
    func postMotion(_ body: () -> Void) {
        guard state.allowsPointerMotion else { return }
        body()
    }

    /// Gate for clicks, keys, scrolling and text input.
    func postAction(_ body: () -> Void) {
        guard state.allowsActions else { return }
        body()
    }

    func announce(_ text: String) {
        deps.announcer.announce(text)
    }
}
