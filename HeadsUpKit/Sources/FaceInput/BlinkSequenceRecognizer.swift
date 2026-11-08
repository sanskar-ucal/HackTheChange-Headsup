import Foundation

/// Blink sequences that trigger an action.
public enum BlinkPattern: String, Sendable, Equatable {
    case double
    case triple
}

/// Output of `BlinkSequenceRecognizer`.
public enum BlinkSequenceEvent: Sendable, Equatable {
    /// `count` blinks so far; `firstOnset` is when the first one began.
    case counting(Int, firstOnset: TimeInterval)
    case recognized(BlinkPattern, firstOnset: TimeInterval)
    /// The sequence ended without an action (1 or 4+ blinks, a long closure, or a reset).
    case cancelled
}

/// Sequence timing, in seconds.
public struct BlinkSequenceConfig: Sendable, Equatable {
    public var maxGap = 0.45
    public var cooldown = 0.7

    public init() {}

    public init(settings: HeadsUpSettings) {
        maxGap = settings.blinkMaxGap
        cooldown = settings.blinkCooldown
    }
}

/// Groups blinks into sequences.
public struct BlinkSequenceRecognizer: Sendable {
    public var config: BlinkSequenceConfig
    public private(set) var count = 0
    private var firstOnset: TimeInterval = 0
    private var lastEnd: TimeInterval = 0
    private var closurePending = false
    private var cooldownUntil: TimeInterval = -.infinity

    public init(config: BlinkSequenceConfig = BlinkSequenceConfig()) {
        self.config = config
    }

    public mutating func handle(_ event: BlinkEvent) -> [BlinkSequenceEvent] {
        switch event {
        case .closed:
            closurePending = true
            return []
        case let .blink(onset, duration):
            closurePending = false
            guard onset >= cooldownUntil else { return [] }
            if count == 0 { firstOnset = onset }
            count += 1
            lastEnd = onset + duration
            return [.counting(count, firstOnset: firstOnset)]
        case .rejected(.tooShort):
            closurePending = false
            return []
        case .rejected(.tooLong):
            closurePending = false
            return reset()
        }
    }

    /// Call on every frame; resolves the sequence once the gap after the last blink has passed.
    public mutating func update(now: TimeInterval) -> [BlinkSequenceEvent] {
        guard count > 0, !closurePending, now - lastEnd > config.maxGap else { return [] }
        let pattern: BlinkPattern? = count == 2 ? .double : count == 3 ? .triple : nil
        let onset = firstOnset
        count = 0
        guard let pattern else { return [.cancelled] }
        cooldownUntil = now + config.cooldown
        return [.recognized(pattern, firstOnset: onset)]
    }

    public mutating func reset() -> [BlinkSequenceEvent] {
        let hadSequence = count > 0
        count = 0
        closurePending = false
        return hadSequence ? [.cancelled] : []
    }
}
