import XCTest
@testable import HeadsUpKit

final class OneEuroFilterTests: XCTestCase {
    private func makeFilter() -> OneEuroFilter {
        OneEuroFilter(minCutoff: 1.0, beta: 0.01, dCutoff: 1.0)
    }

    func testFirstSamplePassesThrough() {
        var filter = makeFilter()
        XCTAssertEqual(filter.filter(5, at: 0), 5)
    }

    func testConvergesToConstantInput() {
        var filter = makeFilter()
        _ = filter.filter(0, at: 0)
        var output = 0.0
        for i in 1...100 { output = filter.filter(10, at: Double(i) / 25) }
        XCTAssertEqual(output, 10, accuracy: 0.01)
    }

    func testReducesJitter() {
        var filter = makeFilter()
        var rawVariance = 0.0, filteredVariance = 0.0
        for i in 0..<250 {
            let t = Double(i) / 25
            let noise = 0.5 * sin(91.7 * t) + 0.3 * sin(53.3 * t)
            let output = filter.filter(noise, at: t)
            if i > 25 {
                rawVariance += noise * noise
                filteredVariance += output * output
            }
        }
        XCTAssertLessThan(filteredVariance, rawVariance * 0.3)
    }

    func testFollowsFastMovementWithLowLag() {
        var filter = makeFilter()
        // 60 °/s ramp: after 1 s the output should be close to the input.
        var output = 0.0
        for i in 0...25 { output = filter.filter(60 * Double(i) / 25, at: Double(i) / 25) }
        XCTAssertGreaterThan(output, 45)
    }

    func testNonIncreasingTimestampReturnsPrevious() {
        var filter = makeFilter()
        _ = filter.filter(1, at: 1)
        XCTAssertEqual(filter.filter(100, at: 1), 1)
        XCTAssertEqual(filter.filter(100, at: 0.5), 1)
    }

    func testResetForgetsHistory() {
        var filter = makeFilter()
        _ = filter.filter(1, at: 0)
        _ = filter.filter(2, at: 0.04)
        filter.reset()
        XCTAssertEqual(filter.filter(50, at: 0.08), 50)
    }

    func testPoseFilterHandlesYawWrapAround() {
        var filter = PoseFilter(minCutoff: 1, beta: 0.01, dCutoff: 1)
        let start = AngleMath.radians(178)
        var output = HeadPose(timestamp: 0, yaw: 0, pitch: 0, roll: 0)
        // Turn steadily from 178° through ±180° to -176°.
        for i in 0..<10 {
            let yaw = AngleMath.wrap(start + AngleMath.radians(Double(i)))
            output = filter.filter(HeadPose(timestamp: Double(i) / 25, yaw: yaw, pitch: 0, roll: 0))
            // The output must stay near the seam, never swing through 0°.
            XCTAssertGreaterThan(abs(output.yaw), AngleMath.radians(170), "sample \(i)")
        }
        XCTAssertLessThan(abs(AngleMath.wrap(output.yaw - AngleMath.radians(-175))), AngleMath.radians(4))
    }
}
