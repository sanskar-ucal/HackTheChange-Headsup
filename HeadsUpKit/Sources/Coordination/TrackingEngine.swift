import CoreGraphics
import Foundation

/// The pointing + gesture pipeline used while tracking. A pure value type: per sensor
/// sample it computes where the pointer *should* be (the display-rate `PointerAnimator`
/// gets it there smoothly) and which gestures fired.
///
/// Gestures are recognized from the **raw** pose, before anything else, so an onset freezes
/// the target, magnetism and edge scrolling in the same sample. On confirm the action
/// carries the onset time (for rollback to where the pointer was just before the gesture)
/// and the target the pointer was snapped to at onset, if any.
public struct TrackingEngine: Sendable {
    public enum Command: Sendable, Equatable {
        /// `point` is the snapped target's center, or the target position just before `onset`.
        case perform(HeadGesture, at: CGPoint, onset: TimeInterval, snapped: ClickTarget?)
    }

    public struct Output: Sendable, Equatable {
        /// Where the pointer should go (global top-left).
        public var target: CGPoint
        /// The unsnapped head position, used to query nearby targets.
        public var rawPoint: CGPoint
        public var commands: [Command]
        public var overshoot: EdgeOvershoot
        /// Raw gyro speed, degrees per second.
        public var headSpeed: Double
        public var snapped: ClickTarget?
        public var didSnap: Bool
        public var isFrozen: Bool
        /// A gesture candidate began on this sample.
        public var didFreeze: Bool
        /// A nod/shake candidate was confirmed or rejected on this sample.
        public var decision: GestureDecision?
    }

    public var mapper: PointerMapper
    public var geometry: ScreenGeometry {
        didSet { magnet.screenArea = Self.area(of: pointingRect) }
    }
    public var recognizer: DoubleNodRecognizer
    public var magnet: MagnetismEngine
    public var spanAllDisplays: Bool
    public var lookback: TimeInterval

    public private(set) var history: CursorHistory
    public private(set) var isFrozen = false
    private var heldPoint: CGPoint?
    private var snappedAtOnset: ClickTarget?
    private var lastTarget: CGPoint?
    /// The most recent snap and when it was last active. A nod's first samples (before the
    /// onset threshold) are fast enough to release the snap, so the onset looks back this far.
    private var lastSnap: (target: ClickTarget, time: TimeInterval)?
    static let snapMemory: TimeInterval = 0.25

    public init(calibration: Calibration, geometry: ScreenGeometry, settings: HeadsUpSettings) {
        mapper = PointerMapper(calibration: calibration, config: PointerMapper.Config(settings: settings))
        self.geometry = geometry
        recognizer = DoubleNodRecognizer(settings: settings)
        spanAllDisplays = settings.spanAllDisplays
        magnet = MagnetismEngine(
            config: MagnetConfig(settings: settings),
            screenArea: Self.area(of: geometry.pointingRect(spanAllDisplays: settings.spanAllDisplays)))
        history = CursorHistory(duration: settings.cursorHistoryDuration)
        lookback = settings.gestureOnsetLookback
    }

    public mutating func apply(_ settings: HeadsUpSettings) {
        mapper.config = PointerMapper.Config(settings: settings)
        recognizer.inner.config = NodShakeConfig(settings: settings)
        recognizer.config = DoubleNodConfig(settings: settings)
        magnet.config = MagnetConfig(settings: settings)
        history.duration = settings.cursorHistoryDuration
        spanAllDisplays = settings.spanAllDisplays
        magnet.screenArea = Self.area(of: pointingRect)
        lookback = settings.gestureOnsetLookback
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

    /// Restarts gesture, mapping and snapping state.
    public mutating func reset() {
        recognizer.reset()
        mapper.reset()
        magnet.release()
        history.removeAll()
        isFrozen = false
        heldPoint = nil
        snappedAtOnset = nil
        lastTarget = nil
        lastSnap = nil
    }

    /// Restarts only the gesture state (after leaving a mode such as scroll or listening).
    public mutating func resetGestures() {
        recognizer.reset()
        isFrozen = false
        heldPoint = nil
    }

    /// - Parameters:
    ///   - raw: unfiltered sensor pose: gesture recognition and snapping speed use it.
    ///   - filtered: smoothed pose for pointing.
    public mutating func process(raw: HeadPose, filtered: HeadPose) -> Output {
        let t = raw.timestamp
        let mapped = mapper.map(filtered)
        let rawPoint = geometry.clamp(geometry.point(for: mapped.point, in: pointingRect))
        let headSpeed = MagnetismEngine.speed(of: raw)
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
                heldPoint = lastTarget ?? rawPoint
                snappedAtOnset = magnet.snapped
                    ?? lastSnap.flatMap { t - $0.time <= Self.snapMemory ? $0.target : nil }
            case .candidateCancelled:
                unfreeze()
            case let .confirmed(gesture, onset):
                let snapped = snappedAtOnset
                let point = snapped?.center ?? history.point(at: onset - lookback) ?? heldPoint ?? rawPoint
                commands.append(.perform(gesture, at: point, onset: onset, snapped: snapped))
                unfreeze()
                magnet.release()
                lastSnap = nil
                actionPoint = point
            case .holdProgress, .holdCancelled:
                break
            }
        }

        var target: CGPoint
        var didSnap = false
        if isFrozen {
            target = heldPoint ?? rawPoint  // snapping is suspended during a candidate
        } else if let actionPoint {
            target = actionPoint
        } else {
            let result = magnet.process(raw: rawPoint, pose: raw)
            target = result.point
            didSnap = result.didSnap
        }

        if let snapped = magnet.snapped { lastSnap = (snapped, t) }
        history.append(target, at: t)
        lastTarget = target
        let decision = recognizer.inner.decisionCount != decisionsBefore ? recognizer.inner.lastDecision : nil
        return Output(
            target: target, rawPoint: rawPoint, commands: commands,
            overshoot: isFrozen ? .zero : mapped.overshoot, headSpeed: headSpeed,
            snapped: isFrozen ? snappedAtOnset : magnet.snapped, didSnap: didSnap, isFrozen: isFrozen,
            didFreeze: didFreeze, decision: decision)
    }

    /// Records a cursor position set from outside (e.g. recentering to screen center).
    public mutating func noteCursor(at point: CGPoint, time: TimeInterval) {
        lastTarget = point
        history.append(point, at: time)
    }

    private mutating func unfreeze() {
        isFrozen = false
        heldPoint = nil
        snappedAtOnset = nil
    }

    private static func area(of rect: CGRect) -> Double {
        Double(rect.width * rect.height)
    }
}
