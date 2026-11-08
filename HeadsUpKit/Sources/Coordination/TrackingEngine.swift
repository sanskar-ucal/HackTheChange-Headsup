import CoreGraphics
import Foundation

/// The pointing + gesture pipeline used while tracking. A pure value type: per sensor
/// sample it computes where the pointer *should* be (the display-rate `PointerAnimator`
/// gets it there smoothly) and which gestures fired.
///
/// Onset rollback: a nod moves the head down, which would drag the pointer down. When a
/// candidate begins the target freezes. If the gesture is confirmed the action happens at
/// the position from just before the onset (from `CursorHistory`), or at the center of the
/// target the pointer was snapped to. If not, the target simply follows the head again.
public struct TrackingEngine: Sendable {
    public enum Command: Sendable, Equatable {
        case perform(HeadGesture, at: CGPoint)
    }

    public struct Output: Sendable, Equatable {
        /// Where the pointer should go (global top-left).
        public var target: CGPoint
        /// The unsnapped head position, used to query nearby targets.
        public var rawPoint: CGPoint
        public var commands: [Command]
        public var overshoot: EdgeOvershoot
        public var headSpeed: Double
        public var snapped: ClickTarget?
        public var didSnap: Bool
        public var isFrozen: Bool
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
    }

    /// Restarts only the gesture state (after leaving a mode such as scroll or listening).
    public mutating func resetGestures() {
        recognizer.reset()
        isFrozen = false
        heldPoint = nil
    }

    /// - Parameters:
    ///   - raw: unfiltered pose (gesture recognition needs the raw rates and angles).
    ///   - filtered: smoothed pose for pointing.
    public mutating func process(raw: HeadPose, filtered: HeadPose) -> Output {
        let t = raw.timestamp
        let mapped = mapper.map(filtered)
        let rawPoint = geometry.clamp(geometry.point(for: mapped.point, in: pointingRect))
        var magnetResult = MagnetResult(point: rawPoint, target: snappedAtOnset ?? magnet.snapped, didSnap: false)
        if !isFrozen {
            // While a gesture is in progress the snap is held (a nod is fast and would release it).
            magnetResult = magnet.process(raw: rawPoint, headSpeed: mapped.headSpeed)
        }
        var target = magnetResult.point
        var commands: [Command] = []

        for event in recognizer.process(raw) {
            switch event {
            case .candidateBegan:
                guard !isFrozen else { continue }
                isFrozen = true
                heldPoint = lastTarget ?? target
                snappedAtOnset = magnet.snapped
            case .candidateCancelled:
                unfreeze()
            case let .confirmed(gesture, onset):
                let point = snappedAtOnset?.center
                    ?? history.point(at: onset - lookback) ?? heldPoint ?? target
                commands.append(.perform(gesture, at: point))
                unfreeze()
                target = point
            case .holdProgress, .holdCancelled:
                break
            }
        }

        if isFrozen { target = heldPoint ?? target }
        history.append(target, at: t)
        lastTarget = target
        return Output(
            target: target, rawPoint: rawPoint, commands: commands,
            overshoot: isFrozen ? .zero : mapped.overshoot, headSpeed: mapped.headSpeed,
            snapped: isFrozen ? snappedAtOnset : magnet.snapped, didSnap: magnetResult.didSnap, isFrozen: isFrozen)
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
