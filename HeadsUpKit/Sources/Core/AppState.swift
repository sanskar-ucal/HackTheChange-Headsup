import Foundation

/// One target in the calibration sequence, in the order the user is asked to look at them.
public enum CalibrationStep: Int, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case center
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
    /// The center again at the end: if the head pose drifted, calibration is redone.
    case centerCheck

    /// The steps whose captures define the mapping (all but the final center check).
    public static let fitSteps: [CalibrationStep] = [.center, .topLeft, .topRight, .bottomRight, .bottomLeft]

    public var next: CalibrationStep? {
        CalibrationStep(rawValue: rawValue + 1)
    }

    /// 1-based position for "step 2 of 5" style UI.
    public var number: Int { rawValue + 1 }

    public var prompt: String {
        switch self {
        case .center: return "Look at the center dot and hold still."
        case .topLeft: return "Now look at the top left corner."
        case .topRight: return "Now the top right corner."
        case .bottomRight: return "Now the bottom right corner."
        case .bottomLeft: return "Now the bottom left corner."
        case .centerCheck: return "Finally, look back at the center dot."
        }
    }

    /// Where the target dot is drawn, normalized 0…1 with a top-left origin.
    public func target(inset: Double) -> (x: Double, y: Double) {
        switch self {
        case .center, .centerCheck: return (0.5, 0.5)
        case .topLeft: return (inset, inset)
        case .topRight: return (1 - inset, inset)
        case .bottomRight: return (1 - inset, 1 - inset)
        case .bottomLeft: return (inset, 1 - inset)
        }
    }
}

/// Why tracking is paused.
public enum PauseReason: String, Sendable, Equatable {
    case user
    case headphonesDisconnected
}

/// Top-level state of the app.
public enum AppState: Sendable, Equatable {
    case needsPermissions
    case waitingForHeadphones
    case calibrating(CalibrationStep)
    /// First-run practice targets after calibration.
    case practicing
    /// A saved calibration exists but the yaw reference must be re-established
    /// (tilt-hold right, or hold still for a moment).
    case awaitingRecenter
    case tracking
    /// In-place scroll mode (double nod): the pointer is frozen and head pitch scrolls.
    case scrollMode
    /// Voice input is listening for speech to put into the focused text field.
    case listening
    /// Text was inserted: nod submits (Return), shake undoes, waiting keeps it.
    case voiceReview
    case paused

    /// Pointer moves may be posted.
    public var allowsPointerMotion: Bool { self == .tracking || self == .practicing }
    /// Clicks, key presses and scrolling may be posted.
    public var allowsActions: Bool {
        switch self {
        case .tracking, .scrollMode, .listening, .voiceReview: return true
        default: return false
        }
    }
    /// Any synthetic event at all.
    public var allowsEventPosting: Bool { allowsPointerMotion || allowsActions }

    public var isCalibrating: Bool {
        if case .calibrating = self { return true }
        return false
    }

    public var displayName: String {
        switch self {
        case .needsPermissions: return "Needs permissions"
        case .waitingForHeadphones: return "Waiting for AirPods"
        case .calibrating(let step): return "Calibrating (\(step.number) of \(CalibrationStep.allCases.count))"
        case .practicing: return "Practice"
        case .awaitingRecenter: return "Hold still to recenter"
        case .tracking: return "Tracking"
        case .scrollMode: return "Scroll mode"
        case .listening: return "Listening"
        case .voiceReview: return "Nod to submit, shake to undo"
        case .paused: return "Paused"
        }
    }
}
