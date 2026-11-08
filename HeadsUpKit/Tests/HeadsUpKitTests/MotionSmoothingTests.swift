import CoreGraphics
import XCTest
@testable import HeadsUpKit

final class PointerAnimatorTests: XCTestCase {
    func testSpringSettlesWithin40MillisecondsWithoutOvershoot() {
        var animator = PointerAnimator(stiffness: HeadsUpSettings.defaults.pointerSpringStiffness)
        animator.place(at: .zero)
        let target = CGPoint(x: 100, y: 0)
        var position = CGPoint.zero
        for frame in 1...8 {  // 8 frames at 200 Hz = 40 ms
            position = animator.step(toward: target, now: Double(frame) / 200, dt: 1.0 / 200.0).position
            XCTAssertLessThanOrEqual(position.x, 100, "critically damped: never overshoots")
        }
        XCTAssertGreaterThan(position.x, 98, "within 2 % after 40 ms")
        XCTAssertLessThanOrEqual(position.x, 100.5, "critically damped: no overshoot")
    }

    func testSpringRemovesSensorStepping() {
        // The target jumps every 40 ms (25 Hz); at 120 Hz frames the pointer moves every frame.
        var animator = PointerAnimator(stiffness: 5000)
        animator.place(at: .zero)
        var positions: [CGFloat] = []
        for frame in 1...24 {
            let t = Double(frame) / 120
            let target = CGPoint(x: 10 * floor(t / 0.04), y: 0)
            positions.append(animator.step(toward: target, now: t, dt: 1.0 / 120).position.x)
        }
        let moving = zip(positions, positions.dropFirst()).filter { $1 > $0 + 0.01 }.count
        XCTAssertGreaterThan(moving, 18, "smooth motion instead of 25 Hz steps")
    }

    func testGlideReachesExactPointAndReportsToken() {
        var animator = PointerAnimator(stiffness: 5000)
        animator.place(at: .zero)
        animator.glide(to: CGPoint(x: 200, y: 100), duration: 0.15, token: 7)
        var finished: Int?
        var last = CGPoint.zero
        for frame in 0...20 {
            let step = animator.step(toward: .zero, now: Double(frame) / 60, dt: 1.0 / 60)
            last = step.position
            if let token = step.finishedGlide { finished = token; break }
        }
        XCTAssertEqual(finished, 7)
        XCTAssertEqual(last, CGPoint(x: 200, y: 100))
    }
}

final class ScrollCurveTests: XCTestCase {
    func testOvershootToSpeedCurve() {
        let speed = { ScrollCurve.speed(beyond: $0, deadZone: 3, ramp: 10, maxSpeed: 1500) }
        XCTAssertEqual(speed(0), 0)
        XCTAssertEqual(speed(3), 0, "no scrolling until the engage overshoot")
        XCTAssertEqual(speed(8), 375, accuracy: 1e-9, "eased: half-way is a quarter speed")
        XCTAssertEqual(speed(13), 1500, accuracy: 1e-9)
        XCTAssertEqual(speed(40), 1500, accuracy: 1e-9, "capped")
        XCTAssertLessThan(speed(5), speed(6))
    }

    func testEdgePushDirectionAndSettings() {
        var settings = HeadsUpSettings.defaults
        XCTAssertGreaterThan(ScrollVelocity.edgePush(EdgeOvershoot(up: 8), settings: settings).vertical, 0)
        XCTAssertLessThan(ScrollVelocity.edgePush(EdgeOvershoot(down: 8), settings: settings).vertical, 0)
        XCTAssertEqual(ScrollVelocity.edgePush(EdgeOvershoot(left: 8), settings: settings).horizontal, 0,
                       "horizontal edge scrolling is off by default")
        settings.horizontalEdgeScroll = true
        XCTAssertGreaterThan(ScrollVelocity.edgePush(EdgeOvershoot(left: 8), settings: settings).horizontal, 0)
        settings.scrollSpeed = 2
        XCTAssertEqual(ScrollVelocity.edgePush(EdgeOvershoot(up: 8), settings: settings).vertical, 930, accuracy: 1e-9)
        settings.edgeScrollEnabled = false
        XCTAssertTrue(ScrollVelocity.edgePush(EdgeOvershoot(up: 20), settings: settings).isZero)
    }

    func testScrollModeNeutralZoneAndDirection() {
        var mode = ScrollModeRecognizer(settings: .defaults, entryPitch: 0)
        func velocity(_ pitch: Double) -> Double {
            mode.velocity(for: HeadPose(timestamp: 0, yaw: 0, pitch: AngleMath.radians(pitch), roll: 0)).vertical
        }
        XCTAssertEqual(velocity(1.5), 0, "inside the 2° neutral zone")
        XCTAssertGreaterThan(velocity(6), 0, "look up = scroll up")
        XCTAssertLessThan(velocity(-6), 0)
        XCTAssertGreaterThan(velocity(10), velocity(6), "speed scales with angle")
    }

    func testScrollModeCapturesNeutralAfterSettling() {
        var mode = ScrollModeRecognizer(settings: .defaults)
        let pose = { (t: Double, pitch: Double) in HeadPose(timestamp: t, yaw: 0, pitch: AngleMath.radians(pitch), roll: 0) }
        XCTAssertTrue(mode.velocity(for: pose(0, -12)).isZero, "still mid-nod")
        XCTAssertTrue(mode.velocity(for: pose(0.5, 0)).isZero)
        XCTAssertEqual(AngleMath.degrees(mode.entryPitch ?? 99), 0, accuracy: 1e-9)
        XCTAssertTrue(mode.velocity(for: pose(0.6, 1)).isZero)
    }
}
