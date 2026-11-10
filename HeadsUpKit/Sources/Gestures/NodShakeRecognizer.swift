import Foundation

/// Thresholds for `NodShakeRecognizer`, in radians, radians/second and seconds.
public struct NodShakeConfig: Sendable, Equatable {
    public var onsetRate: Double
    public var crossAxisMax: Double
    public var nodWindow: TimeInterval
    public var nodMinAmplitude: Double
    public var shakeWindow: TimeInterval
    public var shakeMinAmplitude: Double
    public var shakeMinDirectionChanges: Int
    public var cooldown: TimeInterval

    public init(settings: HeadsUpSettings) {
        onsetRate = AngleMath.radians(settings.gestureOnsetRateDegPerSec)
        crossAxisMax = AngleMath.radians(settings.gestureCrossAxisMaxDegPerSec)
        nodWindow = settings.nodWindow
        nodMinAmplitude = AngleMath.radians(settings.nodMinAmplitudeDegrees)
        shakeWindow = settings.shakeWindow
        shakeMinAmplitude = AngleMath.radians(settings.shakeMinAmplitudeDegrees)
        shakeMinDirectionChanges = settings.shakeMinDirectionChanges
        cooldown = settings.gestureCooldown
    }
}

/// Why a nod/shake candidate was confirmed or rejected, for the tuning log.
public struct GestureDecision: Sendable, Equatable {
    public var kind: QuickGestureKind
    public var confirmed: Bool
    public var reason: String
    public var onset: TimeInterval
    public var time: TimeInterval

    public var logLine: String {
        String(format: "%@ %@ after %.0f ms: %@", kind.rawValue, confirmed ? "confirmed" : "rejected",
               (time - onset) * 1000, reason)
    }
}

/// Rotation-rate state machine for nods (pitch) and shakes (yaw).
public struct NodShakeRecognizer: GestureRecognizer {
    public var config: NodShakeConfig

    private struct NodCandidate: Sendable {
        var onset: TimeInterval
        var startPitch: Double
        var direction: Double
        var maxExcursion: Double = 0
        var reversed = false
    }

    private struct ShakeCandidate: Sendable {
        var onset: TimeInterval
        var direction: Double
        var swingStartYaw: Double
        var extremeYaw: Double
        var directionChanges = 0
    }

    private enum Phase: Sendable {
        case idle
        case nod(NodCandidate)
        case shake(ShakeCandidate)
    }

    private var phase = Phase.idle
    private var cooldownUntil: TimeInterval = -.infinity
    /// True after a confirm/cancel until both rates drop below the onset rate.
    public private(set) var needsRearm = false
    /// The latest candidate outcome; `decisionCount` increments with each one.
    public private(set) var lastDecision: GestureDecision?
    public private(set) var decisionCount = 0

    public init(config: NodShakeConfig) {
        self.config = config
    }

    public var isCandidateActive: Bool {
        if case .idle = phase { return false }
        return true
    }

    /// Lets a follow-up gesture start immediately (used for double nods).
    public mutating func clearCooldown() {
        cooldownUntil = -.infinity
    }

    public mutating func startCooldown(until time: TimeInterval) {
        cooldownUntil = max(cooldownUntil, time)
    }

    public mutating func reset() {
        phase = .idle
        cooldownUntil = -.infinity
        needsRearm = false
    }

    public mutating func process(_ pose: HeadPose) -> [GestureEvent] {
        switch phase {
        case .idle:
            return detectOnset(pose)
        case .nod(var candidate):
            return updateNod(&candidate, pose)
        case .shake(var candidate):
            return updateShake(&candidate, pose)
        }
    }

    private mutating func detectOnset(_ pose: HeadPose) -> [GestureEvent] {
        let pitchRate = pose.rotationRate.pitch
        let yawRate = pose.rotationRate.yaw
        if needsRearm {
            if max(abs(pitchRate), abs(yawRate)) < config.onsetRate { needsRearm = false }
            return []
        }
        guard pose.timestamp >= cooldownUntil else { return [] }

        let t = pose.timestamp
        if abs(pitchRate) >= config.onsetRate && abs(pitchRate) >= abs(yawRate) {
            phase = .nod(NodCandidate(onset: t, startPitch: pose.pitch, direction: pitchRate > 0 ? 1 : -1))
            return [.candidateBegan(.nod, onset: t)]
        }
        if abs(yawRate) >= config.onsetRate {
            phase = .shake(ShakeCandidate(
                onset: t, direction: yawRate > 0 ? 1 : -1, swingStartYaw: pose.yaw, extremeYaw: pose.yaw))
            return [.candidateBegan(.shake, onset: t)]
        }
        return []
    }

    private mutating func updateNod(_ c: inout NodCandidate, _ pose: HeadPose) -> [GestureEvent] {
        let excursion = AngleMath.degrees(c.maxExcursion)
        if abs(pose.rotationRate.yaw) > config.crossAxisMax {
            return cancel(.nod, onset: c.onset, at: pose.timestamp, reason: String(
                format: "yaw rate %.0f°/s > %.0f°/s (head turned)",
                AngleMath.degrees(abs(pose.rotationRate.yaw)), AngleMath.degrees(config.crossAxisMax)))
        }
        if pose.timestamp - c.onset > config.nodWindow {
            let reason = c.reversed
                ? String(format: "excursion %.1f° < %.1f°", excursion, AngleMath.degrees(config.nodMinAmplitude))
                : String(format: "no return movement within %.0f ms (excursion %.1f°)", config.nodWindow * 1000, excursion)
            return cancel(.nod, onset: c.onset, at: pose.timestamp, reason: reason)
        }
        c.maxExcursion = max(c.maxExcursion, abs(pose.pitch - c.startPitch))
        if pose.rotationRate.pitch * c.direction <= -config.onsetRate {
            c.reversed = true
        }
        if c.reversed && c.maxExcursion >= config.nodMinAmplitude {
            return confirm(.nod, onset: c.onset, at: pose.timestamp, reason: String(
                format: "excursion %.1f°", AngleMath.degrees(c.maxExcursion)))
        }
        phase = .nod(c)
        return []
    }

    private mutating func updateShake(_ c: inout ShakeCandidate, _ pose: HeadPose) -> [GestureEvent] {
        if abs(pose.rotationRate.pitch) > config.crossAxisMax {
            return cancel(.shake, onset: c.onset, at: pose.timestamp, reason: String(
                format: "pitch rate %.0f°/s > %.0f°/s", AngleMath.degrees(abs(pose.rotationRate.pitch)),
                AngleMath.degrees(config.crossAxisMax)))
        }
        if pose.timestamp - c.onset > config.shakeWindow {
            return cancel(.shake, onset: c.onset, at: pose.timestamp, reason: String(
                format: "%ld of %ld direction changes in time", c.directionChanges, config.shakeMinDirectionChanges))
        }
        if AngleMath.wrap(pose.yaw - c.extremeYaw) * c.direction > 0 {
            c.extremeYaw = pose.yaw
        }
        if pose.rotationRate.yaw * c.direction <= -config.onsetRate {
            let swing = abs(AngleMath.wrap(c.extremeYaw - c.swingStartYaw))
            guard swing >= config.shakeMinAmplitude else {
                return cancel(.shake, onset: c.onset, at: pose.timestamp, reason: String(
                    format: "half-swing %.1f° < %.1f°", AngleMath.degrees(swing),
                    AngleMath.degrees(config.shakeMinAmplitude)))
            }
            c.directionChanges += 1
            c.swingStartYaw = c.extremeYaw
            c.extremeYaw = pose.yaw
            c.direction = -c.direction
            if c.directionChanges >= config.shakeMinDirectionChanges {
                return confirm(.shake, onset: c.onset, at: pose.timestamp,
                               reason: "\(c.directionChanges) direction changes")
            }
        }
        phase = .shake(c)
        return []
    }

    private mutating func cancel(_ kind: QuickGestureKind, onset: TimeInterval, at time: TimeInterval,
                                 reason: String) -> [GestureEvent] {
        phase = .idle
        needsRearm = true
        record(GestureDecision(kind: kind, confirmed: false, reason: reason, onset: onset, time: time))
        return [.candidateCancelled(kind)]
    }

    private mutating func confirm(_ gesture: HeadGesture, onset: TimeInterval, at time: TimeInterval,
                                  reason: String) -> [GestureEvent] {
        phase = .idle
        needsRearm = true
        cooldownUntil = time + config.cooldown
        record(GestureDecision(kind: gesture == .shake ? .shake : .nod, confirmed: true, reason: reason,
                               onset: onset, time: time))
        return [.confirmed(gesture, onset: onset)]
    }

    private mutating func record(_ decision: GestureDecision) {
        lastDecision = decision
        decisionCount += 1
    }
}
