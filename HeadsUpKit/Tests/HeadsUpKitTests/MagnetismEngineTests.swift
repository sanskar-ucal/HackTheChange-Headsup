import CoreGraphics
import XCTest
@testable import HeadsUpKit

final class MagnetismEngineTests: XCTestCase {
    private let screenArea = 1440.0 * 900.0
    private let button = ClickTarget(frame: CGRect(x: 100, y: 100, width: 40, height: 20), role: "AXButton")

    private func engine(_ targets: [ClickTarget], config: MagnetConfig = MagnetConfig()) -> MagnetismEngine {
        var engine = MagnetismEngine(config: config, screenArea: screenArea)
        engine.targets = targets
        return engine
    }

    /// Raw pose: angles in degrees, `rate` = yaw rotation rate in °/s.
    private func pose(_ t: Double, yaw: Double = 0, pitch: Double = 0, rate: Double = 1) -> HeadPose {
        HeadPose(timestamp: t, yaw: AngleMath.radians(yaw), pitch: AngleMath.radians(pitch), roll: 0,
                 rotationRate: RotationRate(pitch: 0, yaw: AngleMath.radians(rate), roll: 0))
    }

    /// Holds the head still at `raw` long enough to engage (150 ms at 20 Hz).
    @discardableResult
    private func settle(_ magnet: inout MagnetismEngine, at raw: CGPoint, from t: Double = 0) -> MagnetResult {
        var result = MagnetResult(point: raw, target: nil, didSnap: false)
        for i in 0...3 { result = magnet.process(raw: raw, pose: pose(t + Double(i) * 0.05)) }
        return result
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    func testGentleDefaults() {
        let config = MagnetConfig(settings: .defaults)
        XCTAssertEqual(config.snapRadius, 20)
        XCTAssertEqual(config.strength, 0.3)
        XCTAssertEqual(config.stickiness, 0.85)
        XCTAssertEqual(config.engageMaxSpeed, 8)
        XCTAssertEqual(config.engageStillTime, 0.15)
        XCTAssertEqual(config.releaseSpeed, 20)
        XCTAssertEqual(config.releaseAngle, 1.5)
    }

    func testSnapsOnlyAfterBeingStill() {
        var magnet = engine([button])
        let raw = CGPoint(x: 125, y: 135)  // 15 pt below the button
        XCTAssertNil(magnet.process(raw: raw, pose: pose(0)).target)
        XCTAssertNil(magnet.process(raw: raw, pose: pose(0.1)).target, "still only 100 ms")
        let result = magnet.process(raw: raw, pose: pose(0.15))
        XCTAssertEqual(result.target, button)
        XCTAssertTrue(result.didSnap)
        XCTAssertEqual(result.point.y, 135 + (110 - 135) * 0.075, accuracy: 1e-9, "0.3 × (1 − 15/20)")
        XCTAssertLessThan(distance(result.point, button.center), distance(raw, button.center))
    }

    func testNoSnapWhileMoving() {
        var magnet = engine([button])
        for i in 0..<40 {
            let result = magnet.process(raw: CGPoint(x: 120, y: 110), pose: pose(Double(i) * 0.05, rate: 10))
            XCTAssertNil(result.target, "10 °/s is above the 8 °/s engage speed")
        }
    }

    func testReleasesOnSmallDeliberateMovement() {
        var magnet = engine([button])
        let raw = CGPoint(x: 120, y: 110)
        XCTAssertNotNil(settle(&magnet, at: raw).target)
        XCTAssertNotNil(magnet.process(raw: raw, pose: pose(0.2, yaw: 1.0)).target, "1° is within the anchor")
        XCTAssertNil(magnet.process(raw: raw, pose: pose(0.25, yaw: 1.6)).target, "1.6° from the anchor releases")
        XCTAssertNil(magnet.process(raw: raw, pose: pose(0.3, yaw: 1.6)).target, "needs fresh stillness to re-snap")
    }

    func testReleasesOnSpeed() {
        var magnet = engine([button])
        let raw = CGPoint(x: 120, y: 110)
        XCTAssertNotNil(settle(&magnet, at: raw).target)
        XCTAssertNil(magnet.process(raw: raw, pose: pose(0.2, rate: 25)).target)
    }

    func testStickinessInsideTargetIsGentle() {
        var magnet = engine([button])
        let result = settle(&magnet, at: CGPoint(x: 130, y: 112))
        XCTAssertEqual(result.point.x, 120 + 10 * 0.85, accuracy: 1e-9)
        XCTAssertEqual(result.point.y, 110 + 2 * 0.85, accuracy: 1e-9)
    }

    func testNoSnapBeyondRadiusAndReleaseOutsideIt() {
        var magnet = engine([button])
        XCTAssertNil(settle(&magnet, at: CGPoint(x: 120, y: 145)).target, "25 pt is beyond 20 pt")
        var other = engine([button])
        XCTAssertNotNil(settle(&other, at: CGPoint(x: 120, y: 135)).target)
        XCTAssertNotNil(other.process(raw: CGPoint(x: 120, y: 145), pose: pose(0.2)).target, "25 pt < 20 × 1.4")
        XCTAssertNil(other.process(raw: CGPoint(x: 120, y: 150), pose: pose(0.25)).target, "30 pt releases")
    }

    func testNeverSnapsWhenSuspendedOrDisabled() {
        var magnet = engine([button])
        for i in 0...4 {
            XCTAssertNil(magnet.process(raw: CGPoint(x: 120, y: 110), pose: pose(Double(i) * 0.05), suspended: true).target)
        }
        var disabled = engine([button], config: MagnetConfig(enabled: false))
        XCTAssertEqual(settle(&disabled, at: CGPoint(x: 125, y: 115)).point, CGPoint(x: 125, y: 115))
    }

    func testNeverSnapsToTextFieldsOrContainers() {
        let field = ClickTarget(frame: CGRect(x: 100, y: 100, width: 200, height: 24), role: "AXTextField")
        let search = ClickTarget(frame: CGRect(x: 100, y: 100, width: 200, height: 24), role: "AXSearchField")
        let window = ClickTarget(frame: CGRect(x: 0, y: 0, width: 1200, height: 800), role: "AXGroup")
        var magnet = engine([field, search, window])
        XCTAssertNil(settle(&magnet, at: CGPoint(x: 150, y: 110)).target)
    }

    func testCompetingTargetsPreferCentralThenLarger() {
        let small = ClickTarget(frame: CGRect(x: 205, y: 195, width: 10, height: 10), role: "AXButton")
        let wide = ClickTarget(frame: CGRect(x: 150, y: 190, width: 45, height: 30), role: "AXButton")
        var magnet = engine([wide, small])
        XCTAssertEqual(settle(&magnet, at: CGPoint(x: 200, y: 200)).target, small,
                       "same edge distance: the more central one wins")

        let little = ClickTarget(frame: CGRect(x: 310, y: 290, width: 20, height: 20), role: "AXLink")
        let big = ClickTarget(frame: CGRect(x: 260, y: 280, width: 30, height: 40), role: "AXButton")
        var other = engine([little, big])
        XCTAssertEqual(settle(&other, at: CGPoint(x: 300, y: 300)).target, big,
                       "similar distance: the larger one wins")
    }

    func testTargetCacheValidity() {
        var cache = TargetCache(maxAge: 1)
        let box = CGRect(x: 0, y: 0, width: 400, height: 400)
        cache.store([button], box: box, pid: 42, time: 10)
        XCTAssertEqual(cache.lookup(point: CGPoint(x: 200, y: 200), pid: 42, time: 10.5, margin: 100), [button])
        XCTAssertNil(cache.lookup(point: CGPoint(x: 350, y: 200), pid: 42, time: 10.5, margin: 100), "near the box edge")
        XCTAssertNil(cache.lookup(point: CGPoint(x: 200, y: 200), pid: 7, time: 10.5, margin: 100), "other app")
        XCTAssertNil(cache.lookup(point: CGPoint(x: 200, y: 200), pid: 42, time: 12, margin: 100), "stale")
        cache.invalidate()
        XCTAssertNil(cache.lookup(point: CGPoint(x: 200, y: 200), pid: 42, time: 10.5, margin: 100))
    }
}
