import Foundation

/// A head gesture HeadsUp can recognize.
public enum HeadGesture: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case nod
    case shake
    case tiltHoldLeft
    case tiltHoldRight
}

/// The kind of quick gesture a candidate may turn into.
public enum QuickGestureKind: String, Sendable, Equatable {
    case nod
    case shake

    public var gesture: HeadGesture {
        switch self {
        case .nod: return .nod
        case .shake: return .shake
        }
    }
}

/// Output of a gesture recognizer for one pose sample.
public enum GestureEvent: Sendable, Equatable {
    /// A quick gesture may be starting; `onset` is the timestamp of the triggering sample.
    case candidateBegan(QuickGestureKind, onset: TimeInterval)
    /// The candidate turned out not to be a gesture.
    case candidateCancelled(QuickGestureKind)
    /// A gesture was recognized. For quick gestures `onset` is when the candidate began.
    case confirmed(HeadGesture, onset: TimeInterval)
    /// A hold gesture is in progress; fraction is 0…1.
    case holdProgress(HeadGesture, fraction: Double)
    /// A hold gesture was abandoned before completing.
    case holdCancelled(HeadGesture)
}
