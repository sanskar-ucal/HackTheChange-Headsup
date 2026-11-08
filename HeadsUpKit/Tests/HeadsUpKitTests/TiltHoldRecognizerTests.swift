import XCTest
@testable import HeadsUpKit

final class TiltHoldRecognizerTests: XCTestCase {
    typealias S = TraceSynth

    private func makeRecognizer() -> TiltHoldRecognizer {
        TiltHoldRecognizer(config: TiltHoldConfig(settings: .defaults))
    }

    func testHoldLeftFiresAfterDuration() {
        var recognizer = makeRecognizer()
        let events = recognizer.run(S.trace(duration: 3, roll: [S.plateau(-25, from: 0.2, to: 2.5)]))
        XCTAssertEqual(events.confirmedGestures, [.tiltHoldLeft])
        let progress = events.compactMap { event -> Double? in
            if case let .holdProgress(.tiltHoldLeft, fraction) = event { return fraction }
            return nil
        }
        XCTAssertEqual(progress.first, 0)
        XCTAssertEqual(progress, progress.sorted(), "progress only increases")
    }

    func testHoldRightFires() {
        var recognizer = makeRecognizer()
        let events = recognizer.run(S.trace(duration: 3, roll: [S.plateau(25, from: 0.2, to: 2.5)]))
        XCTAssertEqual(events.confirmedGestures, [.tiltHoldRight])
    }

    func testReleasingEarlyCancels() {
        var recognizer = makeRecognizer()
        let events = recognizer.run(S.trace(duration: 2, roll: [S.plateau(-25, from: 0.2, to: 0.9)]))
        XCTAssertEqual(events.confirmedGestures, [])
        XCTAssertTrue(events.contains(.holdCancelled(.tiltHoldLeft)))
    }

    func testBelowThresholdNeverStarts() {
        var recognizer = makeRecognizer()
        XCTAssertEqual(recognizer.run(S.trace(duration: 3, roll: [S.plateau(15, from: 0.2, to: 2.5)])), [])
    }

    func testFiresOncePerHoldAndRearmsAfterRelease() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 6, roll: [S.plateau(-25, from: 0.2, to: 2.6), S.plateau(-25, from: 3.4, to: 5.6)])
        XCTAssertEqual(recognizer.run(trace).confirmedGestures, [.tiltHoldLeft, .tiltHoldLeft])
    }

    func testMeasuresRelativeToRollReference() {
        var recognizer = makeRecognizer()
        recognizer.rollReference = AngleMath.radians(-10)
        // Absolute -25° is only -15° from a neutral of -10°: not a tilt.
        XCTAssertEqual(recognizer.run(S.trace(duration: 3, roll: [S.plateau(-25, from: 0.2, to: 2.5)])), [])
    }
}
