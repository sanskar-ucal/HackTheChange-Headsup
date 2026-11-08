import Foundation
@testable import HeadsUpKit

/// Synthesizes 25 Hz head-pose traces from simple motion components.
enum TraceSynth {
    static let rate = 25.0

    struct Component {
        let value: (Double) -> Double
        let rate: (Double) -> Double
    }

    static func trace(
        duration: Double, start: Double = 0,
        yaw: [Component] = [], pitch: [Component] = [], roll: [Component] = []
    ) -> [HeadPose] {
        let count = Int((duration * rate).rounded())
        return (0..<count).map { i in
            let t = start + Double(i) / rate
            func total(_ parts: [Component], _ f: (Component) -> (Double) -> Double) -> Double {
                parts.reduce(0) { $0 + f($1)(t) }
            }
            return HeadPose(
                timestamp: t,
                yaw: AngleMath.radians(total(yaw) { $0.value }),
                pitch: AngleMath.radians(total(pitch) { $0.value }),
                roll: AngleMath.radians(total(roll) { $0.value }),
                rotationRate: RotationRate(
                    pitch: AngleMath.radians(total(pitch) { $0.rate }),
                    yaw: AngleMath.radians(total(yaw) { $0.rate }),
                    roll: AngleMath.radians(total(roll) { $0.rate })))
        }
    }

    static func constant(_ v: Double) -> Component {
        Component(value: { _ in v }, rate: { _ in 0 })
    }

    static func pan(_ degPerSec: Double) -> Component {
        Component(value: { degPerSec * $0 }, rate: { _ in degPerSec })
    }

    static func nod(at start: Double, amplitude: Double = 15, period: Double = 0.6) -> Component {
        Component(
            value: { t in
                let u = t - start
                return (0...period).contains(u) ? -amplitude * (1 - cos(2 * .pi * u / period)) / 2 : 0
            },
            rate: { t in
                let u = t - start
                return (0...period).contains(u) ? -amplitude * .pi / period * sin(2 * .pi * u / period) : 0
            })
    }

    static func shake(at start: Double, amplitude: Double = 15, period: Double = 0.6) -> Component {
        Component(
            value: { t in
                let u = t - start
                return (0...period).contains(u) ? amplitude * sin(2 * .pi * u / period) : 0
            },
            rate: { t in
                let u = t - start
                return (0...period).contains(u) ? amplitude * 2 * .pi / period * cos(2 * .pi * u / period) : 0
            })
    }

    static func plateau(_ value: Double, from start: Double, to end: Double, ramp: Double = 0.2) -> Component {
        Component(
            value: { t in
                if t < start || t > end + ramp { return 0 }
                if t < start + ramp { return value * (t - start) / ramp }
                if t > end { return value * (1 - (t - end) / ramp) }
                return value
            },
            rate: { t in
                if t >= start && t < start + ramp { return value / ramp }
                if t > end && t <= end + ramp { return -value / ramp }
                return 0
            })
    }

    static func jitter(angle: Double, rate: Double, seed: Double) -> Component {
        Component(
            value: { t in angle * (0.6 * sin(91.7 * t + seed) + 0.4 * sin(53.3 * t + 2 * seed)) },
            rate: { t in rate * (0.6 * sin(77.1 * t + 3 * seed) + 0.4 * cos(41.9 * t + seed)) })
    }

    static func noise(_ seed: Double) -> Component {
        jitter(angle: 0.05, rate: 2, seed: seed)
    }

    static func fixture(_ name: String) throws -> [HeadPose] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "csv", subdirectory: "Fixtures") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try PoseCSV.decode(String(contentsOf: url, encoding: .utf8))
    }
}

extension Array where Element == GestureEvent {
    var confirmedGestures: [HeadGesture] {
        compactMap { if case let .confirmed(g, _) = $0 { return g } else { return nil } }
    }
}

extension GestureRecognizer {
    mutating func run(_ poses: [HeadPose]) -> [GestureEvent] {
        poses.flatMap { process($0) }
    }
}
