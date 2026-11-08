import Foundation

/// Direction badge shown on the pointer while scrolling.
public enum ScrollDirection: String, Sendable, Equatable {
    case up, down, left, right
    case none
}

/// What the pointer is doing, which decides its shape.
public enum PointerContext: Sendable, Equatable {
    case idle
    case hoveringClickable
    case pressing
    case scrolling(ScrollDirection)
    case dragHint
    case listening
    case paused
    case tiltProgress(Double)
}

/// Inputs the coordinator knows; resolved into a single `PointerContext`.
public struct PointerContextInputs: Sendable, Equatable {
    public var state: AppState
    public var isPressing: Bool
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

/// Picks the pointer context from app state, press, scroll and hold progress.
public enum PointerContextResolver {
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

    public static func direction(of velocity: ScrollVelocity) -> ScrollDirection? {
        if velocity.isZero { return nil }
        if abs(velocity.vertical) >= abs(velocity.horizontal) {
            return velocity.vertical > 0 ? .up : .down
        }
        return velocity.horizontal > 0 ? .left : .right
    }
}
