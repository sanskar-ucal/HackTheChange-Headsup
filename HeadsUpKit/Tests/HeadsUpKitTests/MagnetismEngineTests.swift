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

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    func testPullsTowardNearbyTargetCenter() {
        var magnet = engine([button])
        let raw = CGPoint(x: 125, y: 150)  // 30 pt below the button
        let result = magnet.process(raw: raw, headSpeed: 5)
        XCTAssertEqual(result.target, button)
        XCTAssertTrue(result.didSnap)
        XCTAssertLessThan(distance(result.point, button.center), distance(raw, button.center))
        XCTAssertEqual(result.point.y, 150 + (110 - 150) * 0.15, accuracy: 1e-9, "0.6 × (1 − 30/40)")
    }

    func testPullFallsOffWithDistance() {
        var near = engine([button])
        var far = engine([button])
        let nearRaw = CGPoint(x: 120, y: 130)  // 10 pt away
        let farRaw = CGPoint(x: 120, y: 150)   // 30 pt away
        let nearPull = (nearRaw.y - near.process(raw: nearRaw, headSpeed: 0).point.y) / (nearRaw.y - 110)
        let farPull = (farRaw.y - far.process(raw: farRaw, headSpeed: 0).point.y) / (farRaw.y - 110)
        XCTAssertGreaterThan(nearPull, farPull)
    }

    func testStickinessInsideTarget() {
        var magnet = engine([button])
        let result = magnet.process(raw: CGPoint(x: 130, y: 112), headSpeed: 0)
        XCTAssertEqual(result.point, CGPoint(x: 125, y: 111), "half of the offset from the center")
    }

    func testNoSnapBeyondRadius() {
        var magnet = engine([button])
        XCTAssertNil(magnet.process(raw: CGPoint(x: 120, y: 200), headSpeed: 0).target)
    }

    func testHysteresisRelease() {
        var magnet = engine([button])
        _ = magnet.process(raw: CGPoint(x: 120, y: 150), headSpeed: 0)  // snap at 30 pt
        XCTAssertNotNil(magnet.process(raw: CGPoint(x: 120, y: 170), headSpeed: 0).target,
                        "50 pt: beyond the snap radius but inside 40 × 1.4")
        XCTAssertNil(magnet.process(raw: CGPoint(x: 120, y: 180), headSpeed: 0).target, "60 pt: released")
    }

    func testNoSnapDuringFastMotionAndReleaseOnSpeed() {
        var magnet = engine([button])
        XCTAssertNil(magnet.process(raw: CGPoint(x: 120, y: 130), headSpeed: 30).target, "too fast to engage")
        _ = magnet.process(raw: CGPoint(x: 120, y: 130), headSpeed: 5)
        XCTAssertNotNil(magnet.snapped)
        XCTAssertNil(magnet.process(raw: CGPoint(x: 120, y: 130), headSpeed: 45).target, "fast motion releases")
    }

    func testNeverSnapsWhenSuspendedOrDisabled() {
        var magnet = engine([button])
        XCTAssertNil(magnet.process(raw: CGPoint(x: 120, y: 110), headSpeed: 0, suspended: true).target)
        var disabled = engine([button], config: MagnetConfig(enabled: false))
        XCTAssertEqual(disabled.process(raw: CGPoint(x: 125, y: 115), headSpeed: 0).point, CGPoint(x: 125, y: 115))
    }

    func testIgnoresContainers() {
        let window = ClickTarget(frame: CGRect(x: 0, y: 0, width: 1200, height: 800), role: "AXGroup")
        var magnet = engine([window])
        XCTAssertNil(magnet.process(raw: CGPoint(x: 600, y: 400), headSpeed: 0).target)
    }

    func testCompetingTargetsPreferCentralThenLarger() {
        let small = ClickTarget(frame: CGRect(x: 205, y: 195, width: 10, height: 10), role: "AXButton")
        let wide = ClickTarget(frame: CGRect(x: 150, y: 190, width: 45, height: 30), role: "AXButton")
        var magnet = engine([wide, small])
        XCTAssertEqual(magnet.process(raw: CGPoint(x: 200, y: 200), headSpeed: 0).target, small,
                       "same edge distance: the more central one wins")

        let little = ClickTarget(frame: CGRect(x: 310, y: 290, width: 20, height: 20), role: "AXLink")
        let big = ClickTarget(frame: CGRect(x: 260, y: 280, width: 30, height: 40), role: "AXButton")
        var other = engine([little, big])
        XCTAssertEqual(other.process(raw: CGPoint(x: 300, y: 300), headSpeed: 0).target, big,
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
