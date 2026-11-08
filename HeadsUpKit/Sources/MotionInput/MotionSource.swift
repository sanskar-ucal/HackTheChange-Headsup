import Foundation

/// Whether head-tracking headphones are currently delivering motion.
public enum HeadphoneConnection: Sendable, Equatable {
    case connected
    case disconnected
}

/// A producer of head poses (AirPods today; an iPhone relay or a recording later).
///
/// Each stream supports a single consumer and lives as long as the source, across
/// `start()` / `stop()` cycles.
public protocol MotionSource: AnyObject, Sendable {
    var poses: AsyncStream<HeadPose> { get }
    var connectionChanges: AsyncStream<HeadphoneConnection> { get }
    /// Whether this Mac can deliver headphone motion at all.
    var isMotionAvailable: Bool { get }
    func start()
    func stop()
}

/// Counts samples per wall-clock interval. Used to verify that motion keeps arriving
/// while HeadsUp is in the background.
public struct SampleRateMeter: Sendable {
    private var count = 0

    public init() {}

    public mutating func recordSample() { count += 1 }

    /// Returns the samples per second since the previous call and starts a new interval.
    public mutating func takeRate(interval: TimeInterval) -> Double {
        defer { count = 0 }
        guard interval > 0 else { return 0 }
        return Double(count) / interval
    }
}
