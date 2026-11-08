import Combine
import Foundation

/// What blink detection currently sees, for the live indicator in Settings.
public struct BlinkReadout: Sendable, Equatable {
    public enum Face: Sendable, Equatable {
        case waitingForCamera
        /// Learning the open-eye baseline.
        case learning
        case tracked
        case noFace
        case multipleFaces
        case eyesNotFound
    }

    public var face: Face = .waitingForCamera
    public var eyesClosed = false
    /// Blinks in the current, unresolved sequence.
    public var pendingBlinks = 0
    /// Valid blinks counted while tracking.
    public var blinksSeen = 0
    public var lastCommand: BlinkCommand?

    public init() {}
}

/// Live values for the tuning readout, published at a throttled rate so the UI doesn't
/// re-render at the full motion rate.
@MainActor
public final class LiveTelemetry: ObservableObject {
    /// Changes only on blink transitions, not on every camera frame.
    @Published public internal(set) var blink = BlinkReadout()
    @Published public internal(set) var pose: HeadPose?
    @Published public internal(set) var samplesPerSecond: Double = 0
    /// The most recent rate measured while HeadsUp was not the frontmost app; nil until
    /// one has been measured. This is the background-delivery check.
    @Published public internal(set) var backgroundSamplesPerSecond: Double?
    @Published public internal(set) var isAppActive = true
    /// Sensor sample → posted cursor move, milliseconds (target: under 30 ms).
    @Published public internal(set) var pointerLatencyMs: Double?
    /// Recent nod/shake candidates: confirmed or rejected, with the reason (newest last).
    @Published public internal(set) var gestureLog: [String] = []

    func appendGestureLog(_ line: String) {
        gestureLog.append(line)
        if gestureLog.count > 12 { gestureLog.removeFirst(gestureLog.count - 12) }
    }

    public init() {}
}
