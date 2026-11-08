import CoreGraphics
import Foundation

public struct MagnetConfig: Sendable, Equatable {
    public var enabled: Bool
    /// Points.
    public var snapRadius: Double
    /// 0…1 pull toward the target center at the target's edge, falling off to 0 at `snapRadius`.
    public var strength: Double
    /// Inside a target the pointer moves this fraction of the raw movement (1 = no stickiness).
    public var stickiness: Double
    /// Release when the raw point is farther than `snapRadius × releaseFactor`.
    public var releaseFactor: Double
    /// Degrees per second of raw head rotation that release immediately.
    public var releaseSpeed: Double
    /// Degrees the raw head pose may turn from where the snap began before releasing.
    public var releaseAngle: Double
    /// Snapping engages only after the head has turned slower than this…
    public var engageMaxSpeed: Double
    /// …for this long (seconds).
    public var engageStillTime: TimeInterval
    /// Targets bigger than this fraction of the screen are containers and ignored.
    public var maxTargetFraction: Double
    /// Roles that are never snapped to (text entry; clicking those should be deliberate).
    public var excludedRoles: Set<String>

    public static let textRoles: Set<String> = ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox"]

    public init(enabled: Bool = true, snapRadius: Double = 20, strength: Double = 0.3, stickiness: Double = 0.85,
                releaseFactor: Double = 1.4, releaseSpeed: Double = 20, releaseAngle: Double = 1.5,
                engageMaxSpeed: Double = 8, engageStillTime: TimeInterval = 0.15,
                maxTargetFraction: Double = 0.4, excludedRoles: Set<String> = MagnetConfig.textRoles) {
        self.enabled = enabled
        self.snapRadius = snapRadius
        self.strength = strength
        self.stickiness = stickiness
        self.releaseFactor = releaseFactor
        self.releaseSpeed = releaseSpeed
        self.releaseAngle = releaseAngle
        self.engageMaxSpeed = engageMaxSpeed
        self.engageStillTime = engageStillTime
        self.maxTargetFraction = maxTargetFraction
        self.excludedRoles = excludedRoles
    }

    public init(settings: HeadsUpSettings) {
        self.init(enabled: settings.snapEnabled, snapRadius: settings.snapRadius, strength: settings.magnetStrength,
                  stickiness: settings.snapStickiness, releaseFactor: settings.snapReleaseFactor,
                  releaseSpeed: settings.snapReleaseSpeedDegPerSec, releaseAngle: settings.snapReleaseAngleDegrees,
                  engageMaxSpeed: settings.snapEngageMaxSpeedDegPerSec, engageStillTime: settings.snapEngageStillTime,
                  maxTargetFraction: settings.snapMaxTargetScreenFraction)
    }
}

public struct MagnetResult: Sendable, Equatable {
    public var point: CGPoint
    public var target: ClickTarget?
    /// True on the sample where a new snap began (for the snap tick).
    public var didSnap: Bool
}

/// Gentle magnetic snapping to clickable targets. Pure logic: feed it the unsnapped pointer
/// position and the **raw** sensor pose (speed and angles come from the gyro and
/// attitude, never from filtered or mapped values).
public struct MagnetismEngine: Sendable {
    public var config: MagnetConfig
    /// Area of the pointing screen in points², for container exclusion.
    public var screenArea: Double
    public var targets: [ClickTarget] = []
    public private(set) var snapped: ClickTarget?
    private var stillSince: TimeInterval?
    private var anchorYaw = 0.0, anchorPitch = 0.0

    public init(config: MagnetConfig, screenArea: Double) {
        self.config = config
        self.screenArea = screenArea
    }

    public mutating func reset() {
        release()
        targets = []
    }

    public mutating func release() {
        snapped = nil
        stillSince = nil
    }

    /// Raw head speed in degrees per second (gyro yaw and pitch).
    public static func speed(of pose: HeadPose) -> Double {
        AngleMath.degrees(hypot(pose.rotationRate.yaw, pose.rotationRate.pitch))
    }

    /// - Parameter suspended: true during gestures and scroll mode; never snaps then.
    public mutating func process(raw: CGPoint, pose: HeadPose, suspended: Bool = false) -> MagnetResult {
        guard config.enabled, !suspended else {
            release()
            return MagnetResult(point: raw, target: nil, didSnap: false)
        }
        let t = pose.timestamp
        let speed = Self.speed(of: pose)
        if speed < config.engageMaxSpeed {
            stillSince = stillSince ?? t
        } else {
            stillSince = nil
        }

        if let current = snapped {
            let turned = hypot(AngleMath.degrees(AngleMath.wrap(pose.yaw - anchorYaw)),
                               AngleMath.degrees(pose.pitch - anchorPitch))
            if speed > config.releaseSpeed || turned > config.releaseAngle
                || Self.distance(from: raw, to: current.frame) > config.snapRadius * config.releaseFactor {
                release()  // also requires fresh stillness before snapping again
            }
        }

        var didSnap = false
        if snapped == nil, let since = stillSince, t - since >= config.engageStillTime,
           let best = bestTarget(near: raw) {
            snapped = best
            anchorYaw = pose.yaw
            anchorPitch = pose.pitch
            didSnap = true
        }
        guard let target = snapped else { return MagnetResult(point: raw, target: nil, didSnap: false) }
        return MagnetResult(point: pulled(raw, toward: target), target: target, didSnap: didSnap)
    }

    /// Candidates within `snapRadius`, excluding containers and text fields. Prefers
    /// closer, more central and larger targets.
    func bestTarget(near point: CGPoint) -> ClickTarget? {
        let maxArea = config.maxTargetFraction * screenArea
        var best: (target: ClickTarget, score: Double)?
        for target in targets
        where target.area > 0 && target.area <= maxArea && !config.excludedRoles.contains(target.role) {
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
