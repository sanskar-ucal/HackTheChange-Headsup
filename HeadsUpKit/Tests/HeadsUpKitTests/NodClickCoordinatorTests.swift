import CoreGraphics
import XCTest
@testable import HeadsUpKit

@MainActor
final class NodClickCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

    func testCleanNodClicksQuicklyWithoutMovingThePointer() throws {
        let h = CoordinatorHarness.tracking()
        let nod = try S.fixture("nod")  // nod from 0.6 s to 1.2 s
        let start = h.clock
        var movesAtOnset: Int?
        var movesAtClick: Int?
        var clickTime: Double?
        h.feed(poses: nod) { pose in
            if movesAtOnset == nil, abs(AngleMath.degrees(pose.rotationRate.pitch)) >= 60 {
                movesAtOnset = h.cursor.moves.count
            }
            if clickTime == nil, !h.cursor.clicks.isEmpty {
                clickTime = pose.timestamp - start
                movesAtClick = h.cursor.moves.count
            }
        }
        XCTAssertEqual(h.cursor.clicks.count, 1)
        guard let clickTime, let movesAtOnset, let movesAtClick else { return XCTFail("no click") }
        XCTAssertLessThanOrEqual(clickTime, 1.2 + 0.1, "click within 100 ms of nod completion")
        XCTAssertEqual(movesAtClick, movesAtOnset, "zero pointer movement between onset and click")
        XCTAssertEqual(h.cursor.clicks.first?.y ?? 0, 400, accuracy: 2, "clicked where the pointer was before the nod")
        XCTAssertTrue(h.coordinator.telemetry.gestureLog.last?.contains("nod confirmed") ?? false)
    }

    func testRejectedNodIsLoggedWithReason() {
        let h = CoordinatorHarness.tracking()
        h.feed(2, pitch: [S.nod(at: 0.5, amplitude: 5, period: 0.2)])  // fast but tiny
        XCTAssertEqual(h.cursor.clicks, [])
        let line = h.coordinator.telemetry.gestureLog.last ?? ""
        XCTAssertTrue(line.contains("nod rejected"), line)
        XCTAssertTrue(line.contains("excursion"), line)
    }

    func testNodWhileSnappedClicksTheTargetCenter() {
        let h = CoordinatorHarness.tracking()
        let button = ClickTarget(frame: CGRect(x: 480, y: 390, width: 60, height: 24), role: "AXButton")
        h.targets.targets = [button]
        h.holdStill(0.6)
        XCTAssertEqual(h.coordinator.pointerContext, .hoveringClickable, "snapped while still")
        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks, [button.center])
    }

    func testNodClicksEvenWithoutATarget() {
        let h = CoordinatorHarness.tracking()
        h.targets.targets = []
        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks.count, 1)
    }

    func testNoSnapWhileTheHeadIsMoving() {
        let h = CoordinatorHarness.tracking()
        h.targets.targets = [ClickTarget(frame: CGRect(x: 400, y: 380, width: 400, height: 40), role: "AXButton")]
        h.feed(1.5, yaw: [S.pan(12)])  // sweeping across the button at 12 °/s
        XCTAssertFalse(h.feedback.cues.contains(.snapTick))
        XCTAssertNotEqual(h.coordinator.pointerContext, .hoveringClickable)
    }
}
