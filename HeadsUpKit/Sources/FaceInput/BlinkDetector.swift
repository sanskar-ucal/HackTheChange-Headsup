import Foundation

/// Blink detector tunables.
public struct BlinkConfig: Sendable, Equatable {
    public var closeRatio = 0.60
    public var openRatio = 0.80
    public var minDuration = 0.05
    public var maxDuration = 0.4
    public var requireBothEyes = true
    public var baselineWindow = 5.0
    public var minBaselineSamples = 15
    /// A "closure" this long is treated as a baseline mismatch (new user, new lighting).
    public var relearnAfter = 1.5

    public init() {}

    public init(settings: HeadsUpSettings) {
        let sensitivity = min(max(settings.blinkSensitivity, 0), 1)
        closeRatio = 0.5 + 0.2 * sensitivity
        openRatio = closeRatio + 0.2
        minDuration = settings.blinkMinDuration
        maxDuration = settings.blinkMaxDuration
        requireBothEyes = settings.blinkRequireBothEyes
        baselineWindow = settings.blinkBaselineWindow
    }
}

/// Why an eye closure didn't count as a blink.
public enum BlinkRejection: String, Sendable, Equatable {
    case tooShort
    case tooLong
}

/// Output of `BlinkDetector` for one frame.
public enum BlinkEvent: Sendable, Equatable {
    /// Both eyes just closed; `onset` is the first closed sample.
    case closed(onset: TimeInterval)
    case blink(onset: TimeInterval, duration: TimeInterval)
    case rejected(BlinkRejection)
}

/// Turns per-frame Eye Aspect Ratios into blinks.
public struct BlinkDetector: Sendable {
    private struct Timed: Sendable {
        var time: TimeInterval
        var left: Double
        var right: Double
    }

    public var config: BlinkConfig
    public private(set) var leftBaseline: Double?
    public private(set) var rightBaseline: Double?
    public private(set) var isClosed = false
    public private(set) var filteredLeft = 0.0
    public private(set) var filteredRight = 0.0

    private var recentLeft: [Double] = []
    private var recentRight: [Double] = []
    private var history: [Timed] = []
    private var closedAt: TimeInterval?
    private var longReported = false

    public init(config: BlinkConfig = BlinkConfig()) {
        self.config = config
    }

    public var leftCloseThreshold: Double? { leftBaseline.map { $0 * config.closeRatio } }
    public var rightCloseThreshold: Double? { rightBaseline.map { $0 * config.closeRatio } }

    /// Clears the in-progress closure and filter, keeping the learned baseline.
    public mutating func reset() {
        recentLeft.removeAll()
        recentRight.removeAll()
        isClosed = false
        closedAt = nil
        longReported = false
    }

    public mutating func process(_ sample: EyeSample, at time: TimeInterval) -> [BlinkEvent] {
        filteredLeft = Self.median3(&recentLeft, sample.leftEAR)
        filteredRight = Self.median3(&recentRight, sample.rightEAR)
        guard let leftBase = leftBaseline, let rightBase = rightBaseline else {
            learn(time)
            return []
        }

        let left = filteredLeft / max(leftBase, 1e-6)
        let right = filteredRight / max(rightBase, 1e-6)
        // Both eyes must cross the threshold, so winks never count unless the user opts out.
        let closedNow = config.requireBothEyes
            ? left < config.closeRatio && right < config.closeRatio
            : (left + right) / 2 < config.closeRatio
        let openNow = config.requireBothEyes
            ? left > config.openRatio && right > config.openRatio
            : (left + right) / 2 > config.openRatio

        guard isClosed, let start = closedAt else {
            if closedNow {
                isClosed = true
                closedAt = time
                longReported = false
                return [.closed(onset: time)]
            }
            learn(time)
            return []
        }

        let duration = time - start
        if openNow {
            isClosed = false
            closedAt = nil
            if longReported { return [] }
            if duration < config.minDuration { return [.rejected(.tooShort)] }
            if duration > config.maxDuration { return [.rejected(.tooLong)] }
            return [.blink(onset: start, duration: duration)]
        }
        if duration > config.relearnAfter {
            history.removeAll()
            leftBaseline = nil
            rightBaseline = nil
            reset()
            return []
        }
        if duration > config.maxDuration, !longReported {
            longReported = true
            return [.rejected(.tooLong)]
        }
        return []
    }

    /// Adds an open-eye sample and refreshes the rolling-median baseline.
    private mutating func learn(_ time: TimeInterval) {
        history.append(Timed(time: time, left: filteredLeft, right: filteredRight))
        let window = config.baselineWindow
        history.removeAll { time - $0.time > window }
        guard history.count >= config.minBaselineSamples else { return }
        leftBaseline = Self.median(history.map(\.left))
        rightBaseline = Self.median(history.map(\.right))
    }

    private static func median3(_ window: inout [Double], _ value: Double) -> Double {
        window.append(value)
        if window.count > 3 { window.removeFirst(window.count - 3) }
        return median(window)
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
