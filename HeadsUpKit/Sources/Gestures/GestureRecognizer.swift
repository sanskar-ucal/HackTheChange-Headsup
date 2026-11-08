import Foundation

/// Turns a stream of head poses into gesture events. Recognizers are value types fed one
/// sample at a time, which keeps them deterministic and easy to test with synthetic traces.
public protocol GestureRecognizer: Sendable {
    mutating func process(_ pose: HeadPose) -> [GestureEvent]
    mutating func reset()
}
