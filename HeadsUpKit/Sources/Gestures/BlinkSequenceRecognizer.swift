import Foundation

/// The meanings deliberately match the existing nod (select) and shake (cancel) gestures.
public enum BlinkCommand: Sendable, Equatable {
    case select
    case cancel
}

/// Turns a time series of BOTH eyes being closed/open into a double- or triple-blink command.
/// Pure Swift, no camera dependency; can be tested without hardware.
///
/// A blink is a closure lasting `minClosure…maxClosure`. Blinks belong to one sequence while
/// each closure starts within `sequenceWindow` of the previous blink's reopening. The third
/// blink cancels at once; two blinks select only after the eyes stayed open for the whole
/// window, so a triple blink never selects first. Anything ambiguous (a too-short or
/// too-long closure, lost tracking, a frame gap) abandons the sequence without an action.
public struct BlinkSequenceRecognizer: Sendable {
    public struct Configuration: Sendable, Equatable {
        /// Ignore extremely short closures (tracking noise, quick reflex blinks) and long
        /// closures (resting eyes).
        public var minClosure: TimeInterval = 0.1
        public var maxClosure: TimeInterval = 0.45
        /// Longest eyes-open time between the blinks of one sequence. Two blinks select
        /// once the eyes have stayed open this long without a third.
        public var sequenceWindow: TimeInterval = 0.5
        public var actionCooldown: TimeInterval = 0.85
        /// Reset a partial sequence if camera frames stop arriving.
        public var maxFrameGap: TimeInterval = 0.35

        public init() {}

        public init(settings: HeadsUpSettings) {
            minClosure = settings.blinkMinClosure
            maxClosure = max(settings.blinkMaxClosure, settings.blinkMinClosure)
            sequenceWindow = settings.blinkSequenceWindow
            actionCooldown = settings.blinkCooldown
        }
    }

    public var configuration: Configuration
    /// Valid blinks in the current, unresolved sequence.
    public private(set) var blinkCount = 0
    /// Every valid blink counted since creation (for a live "blink seen" indicator).
    public private(set) var totalBlinks = 0
    public private(set) var isClosed = false

    private var closedAt: TimeInterval?
    private var lastBlinkAt: TimeInterval?
    private var lastSampleAt: TimeInterval?
    private var cooldownUntil: TimeInterval = -.infinity

    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// - Parameters:
    ///   - eyesClosed: true only if *both* eyes appear closed, false when open,
    ///                 nil if the face/camera can't be tracked reliably.
    ///   - timestamp: monotonic seconds (e.g. ProcessInfo.processInfo.systemUptime).
    /// - Returns: select only after waiting for a possible third blink;
    ///            cancel immediately after the third valid blink.
    public mutating func process(eyesClosed: Bool?, at timestamp: TimeInterval) -> BlinkCommand? {
        guard timestamp.isFinite, let eyesClosed else {
            reset()
            return nil
        }
        if let previous = lastSampleAt {
            if timestamp < previous {
                reset()
                cooldownUntil = -.infinity
            } else if timestamp - previous > configuration.maxFrameGap {
                reset()
            }
        }
        lastSampleAt = timestamp
        let wasClosed = isClosed
        isClosed = eyesClosed

        if timestamp < cooldownUntil {
            // A closure that began during the cooldown never counts, even if it ends after it.
            closedAt = nil
            return nil
        }

        if eyesClosed {
            if !wasClosed {
                if let last = lastBlinkAt, timestamp - last > configuration.sequenceWindow {
                    clearSequence()
                }
                closedAt = timestamp
            } else if let started = closedAt, timestamp - started > configuration.maxClosure {
                // Eyes held closed: resting, not blinking.
                clearSequence()
            }
            return nil
        }

        if wasClosed {
            // Eye reopening completes a blink; only count deliberate-duration closures.
            guard let started = closedAt else { return nil }
            closedAt = nil
            let duration = timestamp - started
            guard (configuration.minClosure...configuration.maxClosure).contains(duration) else {
                clearSequence()
                return nil
            }
            blinkCount += 1
            totalBlinks += 1
            lastBlinkAt = timestamp
            if blinkCount >= 3 {
                clearSequence()
                cooldownUntil = timestamp + configuration.actionCooldown
                return .cancel
            }
            return nil
        }

        // Eyes stayed open: resolve the sequence once no further blink began in time.
        if blinkCount > 0, let last = lastBlinkAt, timestamp - last >= configuration.sequenceWindow {
            let command: BlinkCommand? = blinkCount == 2 ? .select : nil
            clearSequence()
            if let command {
                cooldownUntil = timestamp + configuration.actionCooldown
                return command
            }
        }
        return nil
    }

    /// Call when blink control is disabled, the camera stops, or the app leaves tracking.
    /// The action cooldown is kept, so a reset never allows a quicker repeat.
    public mutating func reset() {
        clearSequence()
        isClosed = false
        lastSampleAt = nil
    }

    private mutating func clearSequence() {
        blinkCount = 0
        closedAt = nil
        lastBlinkAt = nil
    }
}
