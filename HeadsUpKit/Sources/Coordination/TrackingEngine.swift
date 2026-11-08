import CoreGraphics
import Foundation

/// The pointing + nod/shake pipeline used while tracking. A pure value type: it decides
/// what the cursor should do and the coordinator carries the commands out.
///
/// Onset rollback: a nod moves the head down, which would drag the cursor down. When a
/// candidate begins, the cursor freezes. If the gesture is confirmed, the action happens
/// at the cursor position from just before the onset (from `CursorHistory`). If not, the
/// cursor glides back to the head position instead of jumping.
public struct TrackingEngine: Sendable {
    public enum Command: Sendable, Equatable {
        case move(CGPoint)
        case perform(HeadGesture, at: CGPoint)
    }

    public var mapper: PointerMapper
    public var geometry: ScreenGeometry
    public var recognizer: NodShakeRecognizer
    public var spanAllDisplays: Bool
    public var lookback: TimeInterval
    public var minPostInterval: TimeInterval
    public var blendDuration: TimeInterval

    public private(set) var history: CursorHistory
    public private(set) var isFrozen = false
    private var heldPoint: CGPoint?
    private var blendOrigin: CGPoint?
    private var blendStart: TimeInterval?
    private var lastPosted: CGPoint?
    private var lastPostTime: TimeInterval = -.infinity

    public init(calibration: Calibration, geometry: ScreenGeometry, settings: Settings) {
        mapper = PointerMapper(
            calibration: calibration, sensitivity: settings.sensitivity, deadZoneDegrees: settings.deadZoneDegrees)
        self.geometry = geometry
        recognizer = NodShakeRecognizer(config: NodShakeConfig(settings: settings))
        history = CursorHistory(duration: settings.cursorHistoryDuration)
        spanAllDisplays = settings.spanAllDisplays
        lookback = settings.gestureOnsetLookback
        minPostInterval = 1 / max(settings.maxEventRateHz, 1)
        blendDuration = settings.resumeBlendDuration
    }

    public mutating func apply(_ settings: Settings) {
        mapper.sensitivity = settings.sensitivity
        mapper.deadZone = AngleMath.radians(settings.deadZoneDegrees)
        recognizer.config = NodShakeConfig(settings: settings)
        history.duration = settings.cursorHistoryDuration
        spanAllDisplays = settings.spanAllDisplays
        lookback = settings.gestureOnsetLookback
        minPostInterval = 1 / max(settings.maxEventRateHz, 1)
        blendDuration = settings.resumeBlendDuration
    }

    public var pointingRect: CGRect { geometry.pointingRect(spanAllDisplays: spanAllDisplays) }

    public var centerPoint: CGPoint {
        geometry.clamp(geometry.point(for: .center, in: pointingRect))
    }

    /// Restarts gesture/blend state. If `cursorAt` is given, the cursor glides from there to
    /// the head position on the next samples (used when resuming).
    public mutating func reset(cursorAt point: CGPoint?) {
        recognizer.reset()
        mapper.reset()
        history.removeAll()
        isFrozen = false
        heldPoint = nil
        lastPosted = point
        blendOrigin = point
        blendStart = nil
        lastPostTime = -.infinity
    }

    /// - Parameters:
    ///   - raw: unfiltered pose (gesture recognition needs the raw rates and angles).
    ///   - filtered: smoothed pose for pointing.
    public mutating func process(raw: HeadPose, filtered: HeadPose) -> [Command] {
        let t = raw.timestamp
        let target = geometry.clamp(geometry.point(for: mapper.map(filtered), in: pointingRect))
        var commands: [Command] = []

        for event in recognizer.process(raw) {
            switch event {
            case .candidateBegan:
                isFrozen = true
                heldPoint = lastPosted ?? target
            case .candidateCancelled:
                beginBlend(from: heldPoint ?? lastPosted ?? target, at: t)
            case let .confirmed(gesture, onset):
                let point = history.point(at: onset - lookback) ?? heldPoint ?? lastPosted ?? target
                commands.append(.perform(gesture, at: point))
                lastPosted = point
                lastPostTime = t
                beginBlend(from: point, at: t)
            case .holdProgress, .holdCancelled:
                break
            }
        }

        if isFrozen {
            history.append(heldPoint ?? target, at: t)
            return commands
        }

        var point = target
        if let origin = blendOrigin {
            let start = blendStart ?? t
            blendStart = start
            let fraction = blendDuration > 0 ? (t - start) / blendDuration : 1
            if fraction >= 1 {
                blendOrigin = nil
                blendStart = nil
            } else {
                point = Self.interpolate(origin, target, fraction: fraction)
            }
        }

        history.append(point, at: t)
        // Allow a little timing slack so a 60 Hz cap doesn't drop samples arriving at 60 Hz.
        if point != lastPosted, t - lastPostTime >= minPostInterval * 0.9 {
            commands.append(.move(point))
            lastPosted = point
            lastPostTime = t
        }
        return commands
    }

    /// Records a cursor position set from outside (e.g. recentering to screen center).
    public mutating func noteCursor(at point: CGPoint, time: TimeInterval) {
        lastPosted = point
        history.append(point, at: time)
    }

    private mutating func beginBlend(from point: CGPoint, at time: TimeInterval) {
        isFrozen = false
        heldPoint = nil
        blendOrigin = point
        blendStart = time
    }

    private static func interpolate(_ a: CGPoint, _ b: CGPoint, fraction: Double) -> CGPoint {
        let f = CGFloat(fraction * fraction * (3 - 2 * fraction))  // smoothstep
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }
}
