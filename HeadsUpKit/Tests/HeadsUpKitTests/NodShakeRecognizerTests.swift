import XCTest
@testable import HeadsUpKit

final class NodShakeRecognizerTests: XCTestCase {
    typealias S = TraceSynth

    private func makeRecognizer() -> NodShakeRecognizer {
        NodShakeRecognizer(config: NodShakeConfig(settings: .defaults))
    }

    func testCleanNod() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 2, yaw: [S.noise(1)], pitch: [S.nod(at: 0.6), S.noise(2)], roll: [S.noise(3)])
        let events = recognizer.run(trace)
        XCTAssertEqual(events.confirmedGestures, [.nod])
        // Onset is detected early in the nod, before the head reaches the bottom.
        guard case let .confirmed(_, onset)? = events.first(where: { if case .confirmed = $0 { return true }; return false })
        else { return XCTFail("no confirm") }
        XCTAssertEqual(onset, 0.72, accuracy: 0.05)
    }

    func testCleanShake() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 2, yaw: [S.shake(at: 0.6), S.noise(4)], pitch: [S.noise(5)], roll: [S.noise(6)])
        XCTAssertEqual(recognizer.run(trace).confirmedGestures, [.shake])
    }

    func testSmallJitterNeverTriggers() {
        var recognizer = makeRecognizer()
        let trace = S.trace(
            duration: 10,
            yaw: [S.jitter(angle: 0.6, rate: 25, seed: 10)],
            pitch: [S.jitter(angle: 0.6, rate: 25, seed: 11)],
            roll: [S.jitter(angle: 0.6, rate: 25, seed: 12)])
        XCTAssertEqual(recognizer.run(trace), [])
    }

    func testSlowPanNeverTriggers() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 3, yaw: [S.pan(25), S.noise(7)], pitch: [S.pan(-8), S.noise(8)], roll: [S.noise(9)])
        XCTAssertEqual(recognizer.run(trace), [])
    }

    func testNodDuringSlowPanTriggers() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 2.4, yaw: [S.pan(15), S.noise(13)], pitch: [S.nod(at: 0.8), S.noise(14)])
        XCTAssertEqual(recognizer.run(trace).confirmedGestures, [.nod])
    }

    func testDoubleNodWithinCooldownTriggersOnce() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 3, yaw: [S.noise(1)], pitch: [S.nod(at: 0.5), S.nod(at: 1.15), S.noise(2)])
        XCTAssertEqual(recognizer.run(trace).confirmedGestures, [.nod])
    }

    func testTwoNodsAfterCooldownTriggerTwice() {
        var recognizer = makeRecognizer()
        let trace = S.trace(duration: 4, pitch: [S.nod(at: 0.5), S.nod(at: 2.0)])
        XCTAssertEqual(recognizer.run(trace).confirmedGestures, [.nod, .nod])
    }

    func testSmallNodBelowAmplitudeDoesNotTrigger() {
        var recognizer = makeRecognizer()
        // Fast but tiny (5°): rates exceed onset, excursion doesn't reach 8°.
        let trace = S.trace(duration: 2, pitch: [S.nod(at: 0.5, amplitude: 5, period: 0.2)])
        XCTAssertEqual(recognizer.run(trace).confirmedGestures, [])
    }

    func testFastOneWayPanCancelsWithoutTriggering() {
        var recognizer = makeRecognizer()
        let pan = TraceSynth.Component(
            value: { t in 90 * min(max(t - 0.5, 0), 1) },
            rate: { t in (0.5...1.5).contains(t) ? 90 : 0 })
        let events = recognizer.run(S.trace(duration: 2.5, yaw: [pan]))
        XCTAssertEqual(events.confirmedGestures, [])
        XCTAssertEqual(events.filter { $0 == .candidateBegan(.shake, onset: 0.52) || $0 == .candidateCancelled(.shake) }.count, 2,
                       "one candidate that is cancelled, not a stream of re-triggers")
    }

    func testFixtureTraces() throws {
        let expectations: [(String, [HeadGesture])] = [
            ("nod", [.nod]), ("shake", [.shake]), ("slow_pan", []), ("jitter", []), ("nod_while_panning", [.nod]),
        ]
        for (name, expected) in expectations {
            var recognizer = makeRecognizer()
            XCTAssertEqual(recognizer.run(try S.fixture(name)).confirmedGestures, expected, name)
        }
    }
}
