import XCTest
@testable import HeadsUpKit

final class DoubleNodRecognizerTests: XCTestCase {
    typealias S = TraceSynth

    /// Runs the trace and returns (gesture, time of confirmation) pairs.
    private func confirmations(_ trace: [HeadPose], settings: HeadsUpSettings = .defaults) -> [(HeadGesture, Double)] {
        var recognizer = DoubleNodRecognizer(settings: settings)
        var result: [(HeadGesture, Double)] = []
        for pose in trace {
            for case let .confirmed(gesture, _) in recognizer.process(pose) { result.append((gesture, pose.timestamp)) }
        }
        return result
    }

    func testSingleNodIsASingleClick() {
        let found = confirmations(S.trace(duration: 3, yaw: [S.noise(1)], pitch: [S.nod(at: 0.5), S.noise(2)]))
        XCTAssertEqual(found.map(\.0), [.nod])
    }

    func testTwoNodsWithin900msAreADoubleNod() {
        let trace = S.trace(duration: 3, yaw: [S.noise(1)], pitch: [S.nod(at: 0.5), S.nod(at: 1.1), S.noise(2)])
        XCTAssertEqual(confirmations(trace).map(\.0), [.doubleNod])
    }

    func testTwoNodsFarApartAreTwoClicks() {
        let trace = S.trace(duration: 4, pitch: [S.nod(at: 0.5), S.nod(at: 2.2)])
        XCTAssertEqual(confirmations(trace).map(\.0), [.nod, .nod])
    }

    func testSingleNodWaitsOnlyBrieflyAfterTheNodSettles() {
        let trace = S.trace(duration: 3, pitch: [S.nod(at: 0.5)])
        var inner = NodShakeRecognizer(config: NodShakeConfig(settings: .defaults))
        let innerConfirm = trace.first { inner.process($0).confirmedGestures == [.nod] }?.timestamp ?? 0
        guard let single = confirmations(trace).first else { return XCTFail("no click") }
        // The nod's own tail (~150 ms) plus the 250 ms wait for a second nod, at 25 Hz.
        XCTAssertLessThanOrEqual(single.1 - innerConfirm, 0.48)
        XCTAssertGreaterThanOrEqual(single.1 - innerConfirm, 0.25)
    }

    func testDisabledDoubleNodClicksImmediately() {
        var settings = HeadsUpSettings.defaults
        settings.doubleNodEnabled = false
        let trace = S.trace(duration: 3, pitch: [S.nod(at: 0.5)])
        var inner = NodShakeRecognizer(config: NodShakeConfig(settings: .defaults))
        let innerConfirm = trace.first { inner.process($0).confirmedGestures == [.nod] }?.timestamp
        let found = confirmations(trace, settings: settings)
        XCTAssertEqual(found.map(\.0), [.nod])
        XCTAssertEqual(found.first?.1, innerConfirm)
    }

    func testShakeStillWorks() {
        let found = confirmations(S.trace(duration: 2, yaw: [S.shake(at: 0.5)]))
        XCTAssertEqual(found.map(\.0), [.shake])
    }
}

final class PracticeSessionTests: XCTestCase {
    private var settings: HeadsUpSettings {
        var s = HeadsUpSettings.defaults
        s.sensitivity = 0.6
        return s
    }

    func testNodOnTargetHitsAndAllHitsEndPractice() {
        var session = PracticeSession(settings: settings)
        var t = 0.0
        for target in session.targets {
            session.update(pointer: target.center, aspect: 1.6, time: t)
            XCTAssertTrue(session.registerNod(at: target.center, aspect: 1.6))
            t += 1
        }
        session.update(pointer: .center, aspect: 1.6, time: t)
        XCTAssertEqual(session.hits, 3)
        XCTAssertEqual(session.phase, .suggesting(0.6), "quick and clean: keep the sensitivity")
    }

    func testNodOffTargetMisses() {
        var session = PracticeSession(settings: settings)
        XCTAssertFalse(session.registerNod(at: NormalizedPoint(x: 0.05, y: 0.95), aspect: 1.6))
    }

    func testManyOvershootsSuggestCalmer() {
        var session = PracticeSession(settings: settings)
        let target = session.targets[0].center
        var t = 0.0
        for _ in 0..<6 {  // in and out of the first target without nodding
            session.update(pointer: target, aspect: 1.6, time: t)
            session.update(pointer: .center, aspect: 1.6, time: t + 0.1)
            t += 0.2
        }
        XCTAssertLessThan(session.suggestedSensitivity(), 0.6)
    }

    func testNeverReachingTargetsSuggestsFaster() {
        var session = PracticeSession(settings: settings)
        session.update(pointer: NormalizedPoint(x: 0.5, y: 0.05), aspect: 1.6, time: 0)
        session.update(pointer: NormalizedPoint(x: 0.5, y: 0.05), aspect: 1.6, time: 21)
        XCTAssertEqual(session.phase, .suggesting(0.7))
    }
}
