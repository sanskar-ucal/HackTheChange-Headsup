import Combine
import Foundation

/// Live values for the tuning readout, published at a throttled rate so the UI doesn't
/// re-render at the full motion rate.
@MainActor
public final class LiveTelemetry: ObservableObject {
    @Published public internal(set) var pose: HeadPose?
    @Published public internal(set) var samplesPerSecond: Double = 0
    /// The most recent rate measured while HeadsUp was not the frontmost app; nil until
    /// one has been measured. This is the background-delivery check.
    @Published public internal(set) var backgroundSamplesPerSecond: Double?
    @Published public internal(set) var isAppActive = true

    public init() {}
}
