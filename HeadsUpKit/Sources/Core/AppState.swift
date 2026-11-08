import Foundation

/// One target in the calibration sequence, in the order the user is asked to look at them.
public enum CalibrationStep: Int, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case center
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

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
        case .bottomLeft: return "Finally, the bottom left corner."
        }
    }

    /// Where the target dot is drawn, normalized 0…1 with a top-left origin.
    public func target(inset: Double) -> (x: Double, y: Double) {
        switch self {
        case .center: return (0.5, 0.5)
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

/// Top-level state of the app. Synthetic input events are only ever posted in `.tracking`.
public enum AppState: Sendable, Equatable {
    case needsPermissions
    case waitingForHeadphones
    case calibrating(CalibrationStep)
    /// A saved calibration exists but the yaw reference must be re-established
    /// (tilt-hold right, or hold still for a moment).
    case awaitingRecenter
    case tracking
    case paused

    public var allowsEventPosting: Bool { self == .tracking }

    public var isCalibrating: Bool {
        if case .calibrating = self { return true }
        return false
    }

    public var displayName: String {
        switch self {
        case .needsPermissions: return "Needs permissions"
        case .waitingForHeadphones: return "Waiting for AirPods"
        case .calibrating(let step): return "Calibrating (\(step.number) of \(CalibrationStep.allCases.count))"
        case .awaitingRecenter: return "Hold still to recenter"
        case .tracking: return "Tracking"
        case .paused: return "Paused"
        }
    }
}
