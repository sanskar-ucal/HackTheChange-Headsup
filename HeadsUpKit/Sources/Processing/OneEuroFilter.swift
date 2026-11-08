import Foundation

/// The 1€ filter (Casiez et al., 2012): an adaptive low-pass filter whose cutoff rises with the signal's speed.
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var dCutoff: Double

    private var previousValue: Double?
    private var previousDerivative: Double = 0
    private var previousTime: TimeInterval?

    public init(minCutoff: Double, beta: Double, dCutoff: Double) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }

    public mutating func reset() {
        previousValue = nil
        previousDerivative = 0
        previousTime = nil
    }

    public mutating func filter(_ value: Double, at time: TimeInterval) -> Double {
        guard let lastValue = previousValue, let lastTime = previousTime else {
            previousValue = value
            previousTime = time
            return value
        }
        let dt = time - lastTime
        guard dt > 0 else { return lastValue }

        let derivative = (value - lastValue) / dt
        let smoothedDerivative = Self.lowPass(
            derivative, previous: previousDerivative, alpha: Self.alpha(cutoff: dCutoff, dt: dt))
        let cutoff = minCutoff + beta * abs(smoothedDerivative)
        let result = Self.lowPass(value, previous: lastValue, alpha: Self.alpha(cutoff: cutoff, dt: dt))

        previousValue = result
        previousDerivative = smoothedDerivative
        previousTime = time
        return result
    }

    static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * .pi * max(cutoff, 1e-6))
        return 1 / (1 + tau / dt)
    }

    private static func lowPass(_ value: Double, previous: Double, alpha: Double) -> Double {
        alpha * value + (1 - alpha) * previous
    }
}
