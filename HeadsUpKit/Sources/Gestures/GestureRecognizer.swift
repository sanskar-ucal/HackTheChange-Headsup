import Foundation

/// Turns a stream of head poses into gesture events.
public protocol GestureRecognizer: Sendable {
    mutating func process(_ pose: HeadPose) -> [GestureEvent]
    mutating func reset()
}
