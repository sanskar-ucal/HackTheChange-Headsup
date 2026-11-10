import CoreGraphics
import XCTest
@testable import HeadsUpKit

final class ScreenGeometryTests: XCTestCase {
    private let geometry = ScreenGeometry(
        displays: [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 0, width: 1920, height: 1080)],
        mainDisplay: CGRect(x: 0, y: 0, width: 1440, height: 900))

    func testUnionBounds() {
        XCTAssertEqual(geometry.unionBounds, CGRect(x: 0, y: 0, width: 3360, height: 1080))
    }

    func testPointingRectFollowsSetting() {
        XCTAssertEqual(geometry.pointingRect(spanAllDisplays: false), geometry.mainDisplay)
        XCTAssertEqual(geometry.pointingRect(spanAllDisplays: true), geometry.unionBounds)
    }

    func testNormalizedToGlobalPoint() {
        let rect = geometry.mainDisplay
        XCTAssertEqual(geometry.point(for: .center, in: rect), CGPoint(x: 720, y: 450))
        XCTAssertEqual(geometry.point(for: NormalizedPoint(x: 0, y: 0), in: rect), .zero)
    }

    func testClampKeepsPointsOnDisplays() {
        XCTAssertEqual(geometry.clamp(CGPoint(x: -50, y: -50)), .zero)
        XCTAssertEqual(geometry.clamp(CGPoint(x: 1440, y: 900)), CGPoint(x: 1440, y: 900), "on the second display")
        XCTAssertEqual(geometry.clamp(CGPoint(x: 1000, y: 1000)), CGPoint(x: 1000, y: 899))
        XCTAssertEqual(geometry.clamp(CGPoint(x: 9999, y: 9999)), CGPoint(x: 3359, y: 1079))
    }

    func testAppKitConversionFlipsAroundMainDisplay() {
        let global = CGRect(x: 100, y: 0, width: 200, height: 100)
        let appKit = geometry.appKitRect(fromGlobal: global)
        XCTAssertEqual(appKit, CGRect(x: 100, y: 800, width: 200, height: 100))
        XCTAssertEqual(geometry.globalRect(fromAppKit: appKit), global)

        let point = CGPoint(x: 10, y: 20)
        XCTAssertEqual(geometry.appKitPoint(fromGlobal: point), CGPoint(x: 10, y: 880))
        XCTAssertEqual(geometry.globalPoint(fromAppKit: geometry.appKitPoint(fromGlobal: point)), point)
    }

    func testEmptyDisplayListFallsBack() {
        let fallback = ScreenGeometry(displays: [])
        XCTAssertFalse(fallback.displays.isEmpty)
        XCTAssertEqual(fallback.mainDisplay, fallback.displays[0])
    }
}

final class CursorHistoryTests: XCTestCase {
    func testLooksUpPositionAtOrBeforeTime() {
        var history = CursorHistory(duration: 0.6)
        for i in 0..<10 { history.append(CGPoint(x: Double(i), y: 0), at: Double(i) * 0.1) }
        XCTAssertEqual(history.point(at: 0.55)?.x, 5)
        XCTAssertEqual(history.point(at: 0.9)?.x, 9)
    }

    func testDropsEntriesOlderThanDuration() {
        var history = CursorHistory(duration: 0.6)
        for i in 0..<20 { history.append(CGPoint(x: Double(i), y: 0), at: Double(i) * 0.1) }
        XCTAssertLessThanOrEqual(history.entries.count, 7)
        XCTAssertEqual(history.point(at: 0)?.x, history.entries.first?.point.x)
    }

    func testEmptyHistoryReturnsNil() {
        XCTAssertNil(CursorHistory(duration: 0.6).point(at: 1))
    }
}

final class PoseCSVTests: XCTestCase {
    func testRoundTrip() throws {
        let poses = [
            HeadPose(timestamp: 0, yaw: 0.1, pitch: -0.2, roll: 0.3,
                     rotationRate: RotationRate(pitch: 1, yaw: -2, roll: 0.5)),
            HeadPose(timestamp: 0.04, yaw: 0.11, pitch: -0.19, roll: 0.29),
        ]
        let decoded = try PoseCSV.decode(PoseCSV.encode(poses))
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].rotationRate.yaw, -2, accuracy: 1e-6)
        XCTAssertEqual(decoded[1].pitch, -0.19, accuracy: 1e-6)
    }

    func testRejectsMalformedRow() {
        XCTAssertThrowsError(try PoseCSV.decode("timestamp,yaw\n0,1,2\n"))
    }

    func testFixturesLoad() throws {
        for name in ["nod", "shake", "slow_pan", "jitter", "nod_while_panning"] {
            let poses = try TraceSynth.fixture(name)
            XCTAssertGreaterThan(poses.count, 40, name)
        }
    }

    func testReplaySourceEmitsAllPoses() async {
        let trace = TraceSynth.trace(duration: 1, pitch: [TraceSynth.nod(at: 0.2)])
        let source = ReplayMotionSource(poses: trace, realtime: false)
        source.start()
        var received = 0
        for await _ in source.poses {
            received += 1
            if received == trace.count { break }
        }
        XCTAssertEqual(received, trace.count)
        source.stop()
    }
}
