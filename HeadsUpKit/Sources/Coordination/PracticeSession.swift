import Foundation

/// First-run practice after calibration: three large targets to point at and nod on.
public struct PracticeSession: Sendable, Equatable {
    public struct Target: Sendable, Equatable {
        public var center: NormalizedPoint
        public var hit = false
        public var reachTime: Double?
    }

    public enum Phase: Sendable, Equatable {
        case running
        case suggesting(Double)
        case finished
    }

    public private(set) var targets: [Target] = [
        Target(center: NormalizedPoint(x: 0.25, y: 0.35)),
        Target(center: NormalizedPoint(x: 0.75, y: 0.35)),
        Target(center: NormalizedPoint(x: 0.5, y: 0.72)),
    ]
    public private(set) var phase: Phase = .running
    public let radius: Double
    public let currentSensitivity: Double
    private let duration: TimeInterval
    private var startTime: TimeInterval?
    private var insideIndex: Int?
    public private(set) var overshoots = 0

    public init(settings: HeadsUpSettings) {
        radius = settings.practiceTargetRadius
        currentSensitivity = settings.sensitivity
        duration = settings.practiceDuration
    }

    public var hits: Int { targets.filter(\.hit).count }

    @discardableResult
    public mutating func update(pointer: NormalizedPoint, aspect: Double, time: TimeInterval) -> Bool {
        guard phase == .running else { return false }
        let start = startTime ?? time
        startTime = start
        let index = targetIndex(at: pointer, aspect: aspect)
        var changed = false
        if index != insideIndex {
            if let left = insideIndex, !targets[left].hit { overshoots += 1 }
            if let entered = index, targets[entered].reachTime == nil {
                targets[entered].reachTime = time - start
            }
            insideIndex = index
            changed = true
        }
        if hits == targets.count || time - start >= duration {
            phase = .suggesting(suggestedSensitivity())
            changed = true
        }
        return changed
    }

    public mutating func registerNod(at pointer: NormalizedPoint, aspect: Double) -> Bool {
        guard phase == .running, let index = targetIndex(at: pointer, aspect: aspect), !targets[index].hit else {
            return false
        }
        targets[index].hit = true
        return true
    }

    public mutating func finish() {
        phase = .finished
    }

    public func suggestedSensitivity() -> Double {
        let reached = targets.compactMap(\.reachTime)
        let averageReach = reached.isEmpty ? .infinity : reached.reduce(0, +) / Double(reached.count)
        var suggestion = currentSensitivity
        if Double(overshoots) / Double(targets.count) > 1.5 {
            suggestion -= 0.1
        } else if averageReach > 4 || reached.count < targets.count {
            suggestion += 0.1
        }
        return (min(max(suggestion, 0.25), 1.5) * 20).rounded() / 20
    }

    private func targetIndex(at pointer: NormalizedPoint, aspect: Double) -> Int? {
        targets.firstIndex { target in
            let dx = (pointer.x - target.center.x) * aspect
            let dy = pointer.y - target.center.y
            return (dx * dx + dy * dy).squareRoot() <= radius
        }
    }
}
