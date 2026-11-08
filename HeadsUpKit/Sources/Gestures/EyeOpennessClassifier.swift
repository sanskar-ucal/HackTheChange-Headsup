import Foundation

/// Turns raw eye openness (eye height ÷ width from face landmarks) into open/closed.
///
/// Eye shape, glasses, camera angle and lighting all change the raw number, so it is judged
/// relative to a learned open-eye baseline: the 85th percentile of the first samples (robust
/// to blinks while learning), then slowly adapted while the eyes are clearly open.
/// Hysteresis (`closedRatio` < `reopenRatio`) stops a noisy reading from flickering.
public struct EyeOpennessClassifier: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// Closed below this fraction of the baseline…
        public var closedRatio: Double = 0.55
        /// …and open again above this fraction.
        public var reopenRatio: Double = 0.75
        public var baselineSampleCount: Int = 24
        /// Per-sample weight of the baseline adaptation (about 3 s at 30 Hz).
        public var adaptationRate: Double = 0.01
        /// Relearn the baseline after the eyes were not seen for this long (the user moved).
        public var relearnAfter: TimeInterval = 2.0

        public init() {}

        public init(settings: HeadsUpSettings) {
            closedRatio = settings.blinkClosedRatio
            reopenRatio = max(settings.blinkReopenRatio, settings.blinkClosedRatio + 0.1)
        }
    }

    public var configuration: Configuration
    public private(set) var baseline: Double?
    public var isLearning: Bool { baseline == nil }

    private var samples: [Double] = []
    private var isClosed = false
    private var lastSampleAt: TimeInterval?

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// - Returns: true if closed, false if open, nil while learning the baseline or for an
    ///   invalid reading.
    public mutating func classify(_ openness: Double, at timestamp: TimeInterval) -> Bool? {
        if let last = lastSampleAt, timestamp < last || timestamp - last > configuration.relearnAfter {
            reset()
        }
        lastSampleAt = timestamp
        guard openness.isFinite, openness > 0 else { return nil }

        guard let reference = baseline else {
            samples.append(openness)
            guard samples.count >= max(configuration.baselineSampleCount, 1) else { return nil }
            let sorted = samples.sorted()
            baseline = sorted[Int(Double(sorted.count - 1) * 0.85)]
            samples.removeAll()
            isClosed = false
            return false
        }

        let relative = openness / max(reference, 0.001)
        if isClosed {
            if relative > configuration.reopenRatio { isClosed = false }
        } else if relative < configuration.closedRatio {
            isClosed = true
        }
        if !isClosed, relative > configuration.reopenRatio {
            baseline = reference + (openness - reference) * configuration.adaptationRate
        }
        return isClosed
    }

    /// Forgets the baseline (camera restarted, face lost for a while).
    public mutating func reset() {
        baseline = nil
        samples.removeAll()
        isClosed = false
        lastSampleAt = nil
    }
}
