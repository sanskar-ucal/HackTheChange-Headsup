import Foundation

/// A head gesture HeadsUp can recognize.
public enum HeadGesture: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    case nod
    case doubleNod
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
    case candidateBegan(QuickGestureKind, onset: TimeInterval)
    case candidateCancelled(QuickGestureKind)
    case confirmed(HeadGesture, onset: TimeInterval)
    case holdProgress(HeadGesture, fraction: Double)
    case holdCancelled(HeadGesture)
}
