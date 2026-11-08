import CoreGraphics
import Foundation

/// The pointing + gesture pipeline used while tracking. A pure value type: per sensor
/// sample it computes where the pointer *should* be (the display-rate `PointerAnimator`
/// gets it there) and which gestures fired.
///
/// Gestures are recognized from the **raw** pose, before anything else. The moment a nod
/// or shake starts, the target freezes and edge scrolling stops; a confirmed gesture acts
/// at the frozen spot. Fast pitch-dominant movement below the onset threshold (the first
/// samples of a nod) already holds the target, so a nod's own up/down movement never moves
/// the pointer.
public struct TrackingEngine: Sendable {
    public enum Command: Sendable, Equatable {
        /// `point` is where the target was frozen when the gesture began.
        case perform(HeadGesture, at: CGPoint, onset: TimeInterval)
    }

    public struct Output: Sendable, Equatable {
        /// Where the pointer should go (global top-left).
        public var target: CGPoint
        public var commands: [Command]
        public var overshoot: EdgeOvershoot
        public var isFrozen: Bool
        /// A gesture candidate began on this sample.
        public var didFreeze: Bool
        /// A nod/shake candidate was confirmed or rejected on this sample.
        public var decision: GestureDecision?
    }

    public var mapper: PointerMapper
    public var geometry: ScreenGeometry
    public var recognizer: DoubleNodRecognizer
    public var spanAllDisplays: Bool
    public var lookback: TimeInterval
    /// Radians per second.
    public var preHoldRate: Double

    public private(set) var history: CursorHistory
    public private(set) var isFrozen = false
    private var heldPoint: CGPoint?
    private var lastTarget: CGPoint?

    public init(calibration: Calibration, geometry: ScreenGeometry, settings: HeadsUpSettings) {
        mapper = PointerMapper(calibration: calibration, config: PointerMapper.Config(settings: settings))
        self.geometry = geometry
        recognizer = DoubleNodRecognizer(settings: settings)
        spanAllDisplays = settings.spanAllDisplays
        history = CursorHistory(duration: settings.cursorHistoryDuration)
        lookback = settings.gestureOnsetLookback
        preHoldRate = AngleMath.radians(settings.nodPreHoldRateDegPerSec)
    }

    public mutating func apply(_ settings: HeadsUpSettings) {
        mapper.config = PointerMapper.Config(settings: settings)
        recognizer.inner.config = NodShakeConfig(settings: settings)
        recognizer.config = DoubleNodConfig(settings: settings)
        history.duration = settings.cursorHistoryDuration
        spanAllDisplays = settings.spanAllDisplays
        lookback = settings.gestureOnsetLookback
        preHoldRate = AngleMath.radians(settings.nodPreHoldRateDegPerSec)
    }

    public var pointingRect: CGRect { geometry.pointingRect(spanAllDisplays: spanAllDisplays) }

    public var centerPoint: CGPoint {
        geometry.clamp(geometry.point(for: .center, in: pointingRect))
    }

    /// Normalized position of `point` within the pointing rectangle.
    public func normalized(_ point: CGPoint) -> NormalizedPoint {
        let rect = pointingRect
        return NormalizedPoint(x: Double((point.x - rect.minX) / max(rect.width, 1)),
                               y: Double((point.y - rect.minY) / max(rect.height, 1)))
    }

    /// Restarts gesture and freeze state.
    public mutating func reset() {
        recognizer.reset()
        history.removeAll()
        isFrozen = false
        heldPoint = nil
        lastTarget = nil
    }

    /// Restarts only the gesture state (after leaving a mode such as scroll or listening).
    public mutating func resetGestures() {
        recognizer.reset()
        isFrozen = false
        heldPoint = nil
    }

    /// - Parameters:
    ///   - raw: unfiltered sensor pose: gesture recognition uses it.
    ///   - filtered: One Euro filtered pose for pointing.
    public mutating func process(raw: HeadPose, filtered: HeadPose) -> Output {
        let t = raw.timestamp
        let mapped = mapper.map(filtered)
        let headPoint = geometry.clamp(geometry.point(for: mapped.point, in: pointingRect))
        let decisionsBefore = recognizer.inner.decisionCount
        let events = recognizer.process(raw)

        var commands: [Command] = []
        var didFreeze = false
        var actionPoint: CGPoint?
        for event in events {
            switch event {
            case .candidateBegan:
                guard !isFrozen else { continue }
                isFrozen = true
                didFreeze = true
                heldPoint = lastTarget ?? headPoint
            case .candidateCancelled:
                unfreeze()
            case let .confirmed(gesture, onset):
                let point = heldPoint ?? history.point(at: onset - lookback) ?? lastTarget ?? headPoint
                commands.append(.perform(gesture, at: point, onset: onset))
                unfreeze()
                actionPoint = point
            case .holdProgress, .holdCancelled:
                break
            }
        }

        let pitchRate = abs(raw.rotationRate.pitch)
        let preHold = pitchRate >= preHoldRate && pitchRate > 2 * abs(raw.rotationRate.yaw)
        let target: CGPoint
        if isFrozen {
            target = heldPoint ?? headPoint
        } else if let actionPoint {
            target = actionPoint
        } else if preHold {
            target = lastTarget ?? headPoint
        } else {
            target = headPoint
        }

        history.append(target, at: t)
        lastTarget = target
        let decision = recognizer.inner.decisionCount != decisionsBefore ? recognizer.inner.lastDecision : nil
        return Output(
            target: target, commands: commands,
            overshoot: isFrozen || preHold ? .zero : mapper.map(raw).overshoot,
            isFrozen: isFrozen, didFreeze: didFreeze, decision: decision)
    }

    /// Records a cursor position set from outside (e.g. recentering to screen center).
    public mutating func noteCursor(at point: CGPoint, time: TimeInterval) {
        lastTarget = point
        history.append(point, at: time)
    }

    private mutating func unfreeze() {
        isFrozen = false
        heldPoint = nil
    }
}
