import Foundation

/// Double-nod timing, in seconds.
public struct DoubleNodConfig: Sendable, Equatable {
    public var enabled: Bool
    /// Both nod onsets must fall within this window.
    public var window: TimeInterval
    /// After the first nod finishes, how long to wait for a second nod to start.
    public var wait: TimeInterval
    public var cooldown: TimeInterval

    public init(settings: HeadsUpSettings) {
        enabled = settings.doubleNodEnabled
        window = settings.doubleNodWindow
        wait = settings.doubleNodWait
        cooldown = settings.gestureCooldown
    }
}

/// Wraps `NodShakeRecognizer` and tells single nods from double nods.
public struct DoubleNodRecognizer: GestureRecognizer {
    public var inner: NodShakeRecognizer
    public var config: DoubleNodConfig

    private struct Pending: Sendable {
        var onset: TimeInterval
        var confirmedAt: TimeInterval
        var settledAt: TimeInterval?
        var secondStarted = false
    }

    private var pending: Pending?

    public init(inner: NodShakeRecognizer, config: DoubleNodConfig) {
        self.inner = inner
        self.config = config
    }

    public init(settings: HeadsUpSettings) {
        self.init(inner: NodShakeRecognizer(config: NodShakeConfig(settings: settings)),
                  config: DoubleNodConfig(settings: settings))
    }

    public var isAwaitingSecondNod: Bool { pending != nil }

    public mutating func reset() {
        inner.reset()
        pending = nil
    }

    public mutating func process(_ pose: HeadPose) -> [GestureEvent] {
        let events = inner.process(pose)
        guard config.enabled else { return events }
        let t = pose.timestamp
        var output: [GestureEvent] = []

        for event in events {
            switch event {
            case let .confirmed(.nod, onset):
                if let first = pending {
                    pending = nil
                    if onset - first.onset <= config.window {
                        inner.startCooldown(until: t + config.cooldown)
                        output.append(.confirmed(.doubleNod, onset: first.onset))
                    } else {
                        output.append(.confirmed(.nod, onset: first.onset))
                        hold(onset: onset, at: t)
                    }
                } else {
                    hold(onset: onset, at: t)
                }
            case .candidateBegan(.nod, _) where pending != nil:
                pending?.secondStarted = true
            case .candidateBegan(.shake, _) where pending != nil:
                output += resolveSingle(at: t)
                output.append(event)
            case .candidateCancelled where pending?.secondStarted == true:
                output += resolveSingle(at: t)
            default:
                output.append(event)
            }
        }

        if var waiting = pending, !waiting.secondStarted {
            if waiting.settledAt == nil && !inner.needsRearm { waiting.settledAt = t }
            pending = waiting
            if let settled = waiting.settledAt, t - settled >= config.wait {
                output += resolveSingle(at: t)
            } else if t - waiting.onset > config.window {
                output += resolveSingle(at: t)
            }
        }
        return output
    }

    private mutating func hold(onset: TimeInterval, at time: TimeInterval) {
        pending = Pending(onset: onset, confirmedAt: time)
        inner.clearCooldown()
    }

    private mutating func resolveSingle(at time: TimeInterval) -> [GestureEvent] {
        guard let first = pending else { return [] }
        pending = nil
        inner.startCooldown(until: first.confirmedAt + config.cooldown)
        return [.confirmed(.nod, onset: first.onset)]
    }
}
