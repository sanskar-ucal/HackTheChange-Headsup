import Combine
import Foundation

/// Live values for the tuning readout.
@MainActor
public final class LiveTelemetry: ObservableObject {
    @Published public internal(set) var pose: HeadPose?
    @Published public internal(set) var samplesPerSecond: Double = 0
    @Published public internal(set) var backgroundSamplesPerSecond: Double?
    @Published public internal(set) var isAppActive = true
    @Published public internal(set) var pointerLatencyMs: Double?
    @Published public internal(set) var gestureLog: [String] = []

    func appendGestureLog(_ line: String) {
        gestureLog.append(line)
        if gestureLog.count > 12 { gestureLog.removeFirst(gestureLog.count - 12) }
    }

    public init() {}
}
