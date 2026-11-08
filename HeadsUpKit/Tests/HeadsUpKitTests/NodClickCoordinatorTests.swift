import CoreGraphics
import XCTest
@testable import HeadsUpKit

@MainActor
final class NodClickCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

    func testNodClicksAtOnsetPointAndHoldsStill() throws {
        let h = CoordinatorHarness.tracking()
        let nod = try S.fixture("nod")  // nod from 0.6 s to 1.2 s
        let start = h.clock
        var onsetPoint: CGPoint?
        var movesAtOnset: Int?
        var clickTime: Double?
        var movesDuringHold: [Int] = []
        h.feed(poses: nod) { pose in
            let t = pose.timestamp - start
            if movesAtOnset == nil, abs(AngleMath.degrees(pose.rotationRate.pitch)) >= 60 {
                movesAtOnset = h.cursor.moves.count
                onsetPoint = h.cursor.currentPosition
            }
            if clickTime == nil, !h.cursor.clicks.isEmpty { clickTime = t }
            if let clickTime, t < clickTime + 0.4 - 1e-9 { movesDuringHold.append(h.cursor.moves.count) }
        }
        XCTAssertEqual(h.cursor.clicks.count, 1)
        guard let movesAtOnset, let onsetPoint, let clickTime else { return XCTFail("no click") }
        XCTAssertEqual(h.cursor.clicks.first, onsetPoint, "clicked exactly where the cursor froze")
        XCTAssertLessThanOrEqual(clickTime, 1.2 + 0.1)
        XCTAssertFalse(movesDuringHold.isEmpty)
        XCTAssertTrue(movesDuringHold.allSatisfy { $0 == movesAtOnset },
                      "zero cursor movement from onset until 400 ms after the click")
        XCTAssertTrue(h.coordinator.telemetry.gestureLog.last?.contains("nod confirmed") ?? false)
    }

    func testNodMovementNeverMovesTheCursor() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        h.feed(1.5, pitch: [S.nod(at: 0.3)])  // nod done by 0.9 s, hold ends ~1.1 s
        XCTAssertEqual(h.cursor.clicks.count, 1)
        XCTAssertEqual(h.cursor.moves, [], "the nod's own up/down movement is never followed")
    }

    func testAfterTheHoldTheCursorGlidesToTheHead() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        var clickTime: Double?
        var movesBeforeRelease = 0
        // Nod, then turn the head right during the hold after the click.
        h.feed(poses: S.trace(duration: 2.5, yaw: [S.plateau(10, from: 0.8, to: 2.5)], pitch: [S.nod(at: 0.3)])) { pose in
            if clickTime == nil, !h.cursor.clicks.isEmpty { clickTime = pose.timestamp }
            if let clickTime, pose.timestamp < clickTime + 0.4 - 1e-9 { movesBeforeRelease = h.cursor.moves.count }
        }
        XCTAssertNotNil(clickTime)
        XCTAssertEqual(movesBeforeRelease, 0, "held still for 400 ms even though the head turned")
        XCTAssertGreaterThan(h.cursor.moves.count, 1, "then glided")
        XCTAssertEqual(h.cursor.moves.last?.x ?? 0, 750, accuracy: 4, "to the head-pointed position")
    }

    func testRejectedNodUnfreezesWithoutAJump() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        h.feed(2, pitch: [S.nod(at: 0.5, amplitude: 5, period: 0.2)])  // fast but tiny: rejected
        XCTAssertEqual(h.cursor.clicks, [])
        let line = h.coordinator.telemetry.gestureLog.last ?? ""
        XCTAssertTrue(line.contains("nod rejected") && line.contains("excursion"), line)
        let moves = [CGPoint(x: 500, y: 400)] + h.cursor.moves
        for (a, b) in zip(moves, moves.dropFirst()) {
            XCTAssertLessThan(hypot(b.x - a.x, b.y - a.y), 20, "no jump")
        }
    }

    func testSmallTargetChangesDontMoveTheCursor() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        h.holdStill(1, yaw: 0.1)  // 2.5 pt: inside the 3 pt dead zone
        XCTAssertEqual(h.cursor.moves, [])
        h.holdStill(1, yaw: 0.4)  // 10 pt: moves
        XCTAssertFalse(h.cursor.moves.isEmpty)
    }
}
