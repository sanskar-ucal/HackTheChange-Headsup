import Foundation

public enum ScrollDirection: String, Sendable, Equatable {
    case up, down, left, right
    /// Scroll mode is active but not currently moving.
    case none
}

/// What the pointer is doing, which decides its shape.
public enum PointerContext: Sendable, Equatable {
    case idle
    case hoveringClickable
    case pressing
    case scrolling(ScrollDirection)
    /// Reserved for a future drag mode.
    case dragHint
    case listening
    case paused
    case tiltProgress(Double)
}

/// Inputs the coordinator knows; resolved into a single `PointerContext`.
public struct PointerContextInputs: Sendable, Equatable {
    public var state: AppState
    public var isPressing: Bool
    /// Non-nil while scrolling (edge push or scroll mode).
    public var scrollDirection: ScrollDirection?
    public var holdFraction: Double?

    public init(state: AppState, isPressing: Bool = false,
                scrollDirection: ScrollDirection? = nil, holdFraction: Double? = nil) {
        self.state = state
        self.isPressing = isPressing
        self.scrollDirection = scrollDirection
        self.holdFraction = holdFraction
    }
}

public enum PointerContextResolver {
    /// Priority: listening > paused > pressing > scrolling > tilt progress > idle.
    /// (`.hoveringClickable` is kept for the pointer styles but is not produced.)
    public static func context(for inputs: PointerContextInputs) -> PointerContext {
        switch inputs.state {
        case .listening, .voiceReview: return .listening
        case .paused: return .paused
        default: break
        }
        if inputs.isPressing { return .pressing }
        if inputs.state == .scrollMode { return .scrolling(inputs.scrollDirection ?? .none) }
        if let direction = inputs.scrollDirection { return .scrolling(direction) }
        if let fraction = inputs.holdFraction { return .tiltProgress(fraction) }
        return .idle
    }

    /// Direction of a scroll velocity, or nil when not scrolling.
    public static func direction(of velocity: ScrollVelocity) -> ScrollDirection? {
        if velocity.isZero { return nil }
        if abs(velocity.vertical) >= abs(velocity.horizontal) {
            return velocity.vertical > 0 ? .up : .down
        }
        return velocity.horizontal > 0 ? .left : .right
    }
}
