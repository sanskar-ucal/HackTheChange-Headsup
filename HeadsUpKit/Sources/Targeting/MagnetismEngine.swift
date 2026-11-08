import CoreGraphics
import Foundation

public struct MagnetConfig: Sendable, Equatable {
    public var enabled: Bool
    /// Points.
    public var snapRadius: Double
    /// 0…1 pull toward the target center at the target's edge, falling off to 0 at `snapRadius`.
    public var strength: Double
    /// Inside a target the pointer moves this fraction of the raw movement (easier to stay on).
    public var stickiness: Double
    /// Release when the raw point is farther than `snapRadius × releaseFactor`.
    public var releaseFactor: Double
    /// Degrees per second.
    public var releaseSpeed: Double
    public var engageMaxSpeed: Double
    /// Targets bigger than this fraction of the screen are containers and ignored.
    public var maxTargetFraction: Double

    public init(enabled: Bool = true, snapRadius: Double = 40, strength: Double = 0.6, stickiness: Double = 0.5,
                releaseFactor: Double = 1.4, releaseSpeed: Double = 40, engageMaxSpeed: Double = 20,
                maxTargetFraction: Double = 0.4) {
        self.enabled = enabled
        self.snapRadius = snapRadius
        self.strength = strength
        self.stickiness = stickiness
        self.releaseFactor = releaseFactor
        self.releaseSpeed = releaseSpeed
        self.engageMaxSpeed = engageMaxSpeed
        self.maxTargetFraction = maxTargetFraction
    }

    public init(settings: Settings) {
        self.init(enabled: settings.snapEnabled, snapRadius: settings.snapRadius, strength: settings.magnetStrength,
                  stickiness: settings.snapStickiness, releaseFactor: settings.snapReleaseFactor,
                  releaseSpeed: settings.snapReleaseSpeedDegPerSec, engageMaxSpeed: settings.snapEngageMaxSpeedDegPerSec,
                  maxTargetFraction: settings.snapMaxTargetScreenFraction)
    }
}

public struct MagnetResult: Sendable, Equatable {
    public var point: CGPoint
    public var target: ClickTarget?
    /// True on the sample where a new snap began (for the snap tick).
    public var didSnap: Bool
}

/// Magnetic snapping to clickable targets. Pure logic: feed it the unsnapped pointer
/// position, the head speed and the nearby targets.
public struct MagnetismEngine: Sendable {
    public var config: MagnetConfig
    /// Area of the pointing screen in points², for container exclusion.
    public var screenArea: Double
    public var targets: [ClickTarget] = []
    public private(set) var snapped: ClickTarget?

    public init(config: MagnetConfig, screenArea: Double) {
        self.config = config
        self.screenArea = screenArea
    }

    public mutating func reset() {
        snapped = nil
        targets = []
    }

    public mutating func release() {
        snapped = nil
    }

    /// - Parameter suspended: true during scroll mode and similar; never snaps then.
    public mutating func process(raw: CGPoint, headSpeed: Double, suspended: Bool = false) -> MagnetResult {
        guard config.enabled, !suspended else {
            snapped = nil
            return MagnetResult(point: raw, target: nil, didSnap: false)
        }
        if let current = snapped,
           headSpeed > config.releaseSpeed
            || Self.distance(from: raw, to: current.frame) > config.snapRadius * config.releaseFactor {
            snapped = nil
        }
        var didSnap = false
        if snapped == nil, headSpeed <= config.engageMaxSpeed, let best = bestTarget(near: raw) {
            snapped = best
            didSnap = true
        }
        guard let target = snapped else { return MagnetResult(point: raw, target: nil, didSnap: false) }
        return MagnetResult(point: pulled(raw, toward: target), target: target, didSnap: didSnap)
    }

    /// Candidates within `snapRadius`, excluding containers. Prefers closer, more central
    /// and larger targets.
    func bestTarget(near point: CGPoint) -> ClickTarget? {
        let maxArea = config.maxTargetFraction * screenArea
        var best: (target: ClickTarget, score: Double)?
        for target in targets where target.area > 0 && target.area <= maxArea {
            let edgeDistance = Self.distance(from: point, to: target.frame)
            guard edgeDistance <= config.snapRadius else { continue }
            let centerDistance = Double(hypot(point.x - target.center.x, point.y - target.center.y))
            let score = edgeDistance + 0.25 * centerDistance - 0.1 * target.area.squareRoot()
            if best == nil || score < best!.score { best = (target, score) }
        }
        return best?.target
    }

    func pulled(_ raw: CGPoint, toward target: ClickTarget) -> CGPoint {
        let c = target.center
        if target.frame.contains(raw) {
            let k = CGFloat(config.stickiness)
            return CGPoint(x: c.x + (raw.x - c.x) * k, y: c.y + (raw.y - c.y) * k)
        }
        let falloff = 1 - min(Self.distance(from: raw, to: target.frame) / max(config.snapRadius, 1), 1)
        let pull = CGFloat(config.strength * falloff)
        return CGPoint(x: raw.x + (c.x - raw.x) * pull, y: raw.y + (c.y - raw.y) * pull)
    }

    /// 0 inside the rectangle, otherwise the distance to its nearest edge.
    static func distance(from point: CGPoint, to rect: CGRect) -> Double {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return Double(hypot(dx, dy))
    }
}
