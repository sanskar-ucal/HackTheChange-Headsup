import Foundation

/// One target in the calibration sequence, in the order the user is asked to look at them.
public enum CalibrationStep: Int, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case center
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft
    case centerCheck

    public static let fitSteps: [CalibrationStep] = [.center, .topLeft, .topRight, .bottomRight, .bottomLeft]

    public var next: CalibrationStep? {
        CalibrationStep(rawValue: rawValue + 1)
    }

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
    case practicing
    case awaitingRecenter
    case tracking
    case scrollMode
    case listening
    case voiceReview
    case paused

    public var allowsPointerMotion: Bool { self == .tracking || self == .practicing }
    public var allowsActions: Bool {
        switch self {
        case .tracking, .scrollMode, .listening, .voiceReview: return true
        default: return false
        }
    }
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
