import XCTest
@testable import HeadsUpKit

final class BlinkSequenceRecognizerTests: XCTestCase {
    private func tick(_ recognizer: inout BlinkSequenceRecognizer, _ closed: Bool?, _ time: Double) -> BlinkCommand? {
        recognizer.process(eyesClosed: closed, at: time)
    }

    private func openFrames(_ r: inout BlinkSequenceRecognizer,
                            from start: Double, through end: Double) -> [BlinkCommand] {
        var results: [BlinkCommand] = []
        var time = start
        while time <= end + 0.00001 {
            if let event = tick(&r, false, time) { results.append(event) }
            time += 0.05
        }
        return results
    }

    /// Feeds 30 Hz camera frames from `start` to `end`: closed inside `closed`, nil (face
    /// lost) inside `lost`, and no frames at all inside `gaps`. Returns commands with times.
    private func run(_ r: inout BlinkSequenceRecognizer, closed: [ClosedRange<Double>],
                     lost: [ClosedRange<Double>] = [], gaps: [ClosedRange<Double>] = [],
                     from start: Double = 0, until end: Double) -> [(BlinkCommand, Double)] {
        var results: [(BlinkCommand, Double)] = []
        for index in 0...Int(((end - start) * 30).rounded()) {
            let t = start + Double(index) / 30
            if gaps.contains(where: { $0.contains(t) }) { continue }
            let sample: Bool? = lost.contains { $0.contains(t) } ? nil : closed.contains { $0.contains(t) }
            if let command = r.process(eyesClosed: sample, at: t) { results.append((command, t)) }
        }
        return results
    }

    // MARK: Starter scenarios

    func testDoubleBlinkSelectWaitsForThirdBlink() {
        var r = BlinkSequenceRecognizer()
        _ = tick(&r, false, 0)
        _ = tick(&r, true, 0.05)
        XCTAssertNil(tick(&r, false, 0.20))
        _ = openFrames(&r, from: 0.25, through: 0.40)
        _ = tick(&r, true, 0.45)
        XCTAssertNil(tick(&r, false, 0.60))
        let results = openFrames(&r, from: 0.65, through: 1.20)
        XCTAssertEqual(results, [.select])
    }

    func testTripleBlinkCancelsWithoutSelecting() {
        var r = BlinkSequenceRecognizer()
        _ = tick(&r, false, 0)
        _ = tick(&r, true, 0.05)
        _ = tick(&r, false, 0.20)
        _ = openFrames(&r, from: 0.25, through: 0.35)
        _ = tick(&r, true, 0.40)
        XCTAssertNil(tick(&r, false, 0.55))
        _ = openFrames(&r, from: 0.60, through: 0.75)
        _ = tick(&r, true, 0.80)
        XCTAssertEqual(tick(&r, false, 0.95), .cancel)
        XCTAssertTrue(openFrames(&r, from: 1.0, through: 1.50).isEmpty)
    }

    func testSingleBlinkDoesNothing() {
        var r = BlinkSequenceRecognizer()
        _ = tick(&r, false, 0)
        _ = tick(&r, true, 0.05)
        _ = tick(&r, false, 0.2)
        XCTAssertTrue(openFrames(&r, from: 0.25, through: 1.0).isEmpty)
        XCTAssertEqual(r.blinkCount, 0)
    }

    func testTrackingLossCancelsPendingSequence() {
        var r = BlinkSequenceRecognizer()
        _ = tick(&r, false, 0)
        _ = tick(&r, true, 0.05)
        _ = tick(&r, false, 0.2)
        XCTAssertNil(tick(&r, nil, 0.25))
        _ = tick(&r, false, 0.3)
        _ = tick(&r, true, 0.4)
        _ = tick(&r, false, 0.55)
        XCTAssertTrue(openFrames(&r, from: 0.60, through: 1.2).isEmpty)
    }

    func testVeryShortEyeClosureIgnored() {
        var r = BlinkSequenceRecognizer()
        _ = tick(&r, false, 0)
        _ = tick(&r, true, 0.05)
        _ = tick(&r, false, 0.08)
        XCTAssertTrue(openFrames(&r, from: 0.1, through: 0.85).isEmpty)
    }

    // MARK: Timing

    func testDoubleBlinkSelectsOnceAfterTheFullWindow() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79], until: 2)
        XCTAssertEqual(results.map(\.0), [.select])
        // Second blink reopens at 0.8; the window (0.5 s) must pass with eyes open.
        XCTAssertEqual(results.first?.1 ?? 0, 1.3, accuracy: 0.04)
    }

    func testSlowThirdBlinkThatStartsInTimeStillCancels() {
        // The third closure starts 0.43 s after the second reopening (inside the window) but
        // reopens 0.73 s after it. It is part of the sequence: cancel, never select.
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79, 1.22...1.52], until: 3)
        XCTAssertEqual(results.map(\.0), [.cancel])
    }

    func testThirdBlinkAfterTheWindowSelectsAndIsSwallowedByCooldown() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79, 1.42...1.6], until: 3)
        XCTAssertEqual(results.map(\.0), [.select])
        XCTAssertEqual(r.blinkCount, 0, "the late blink fell in the cooldown")
    }

    func testCooldownBlocksImmediateRepeatThenAllowsTheNext() {
        var r = BlinkSequenceRecognizer()
        // Select at ≈1.3 s; cooldown until ≈2.15 s. The second double blink starts at 1.4 s.
        let first = run(&r, closed: [0.21...0.39, 0.61...0.79, 1.41...1.59, 1.81...1.99], until: 3)
        XCTAssertEqual(first.map(\.0), [.select])
        let second = run(&r, closed: [3.21...3.39, 3.61...3.79], from: 3 + 1.0 / 30, until: 5)
        XCTAssertEqual(second.map(\.0), [.select])
    }

    func testTripleBlinkCooldownSwallowsAFourthBlink() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79, 1.01...1.19, 1.41...1.59], until: 3)
        XCTAssertEqual(results.map(\.0), [.cancel])
    }

    // MARK: Interrupted and ambiguous sequences

    func testLongClosureAbandonsSequence() {
        var r = BlinkSequenceRecognizer()
        // Two blinks, then the eyes rest closed for a second.
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79, 1.01...2.0], until: 4)
        XCTAssertTrue(results.isEmpty)
    }

    func testQuickFlickerAfterTwoBlinksPreventsSelect() {
        // A too-short third closure is ambiguous (possibly a rushed triple blink): no action.
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79, 1.0...1.04], until: 3)
        XCTAssertTrue(results.isEmpty)
    }

    func testFrameGapResetsSequence() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.91...1.09], gaps: [0.45...0.85], until: 3)
        XCTAssertTrue(results.isEmpty, "camera frames stopped between the blinks")
    }

    func testBriefFaceLossBetweenBlinksResets() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79], lost: [0.5...0.52], until: 3)
        XCTAssertTrue(results.isEmpty)
    }

    func testFaceLossDuringTheWaitPreventsSelect() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 0.61...0.79], lost: [1.0...1.02], until: 3)
        XCTAssertTrue(results.isEmpty, "unknown whether a third blink happened")
    }

    func testBlinksTooFarApartAreSeparateSingles() {
        var r = BlinkSequenceRecognizer()
        let results = run(&r, closed: [0.21...0.39, 1.01...1.19], until: 3)
        XCTAssertTrue(results.isEmpty)
    }

    func testNormalBlinkingNeverActs() {
        // Spontaneous blinks every 2–4 s with typical 0.1–0.3 s closures, for a minute.
        var closures: [ClosedRange<Double>] = []
        var t = 1.0
        var i = 0
        while t < 60 {
            let duration = [0.12, 0.2, 0.3, 0.15][i % 4]
            closures.append(t...(t + duration))
            t += [2.0, 3.5, 2.6, 4.0][i % 4]
            i += 1
        }
        var r = BlinkSequenceRecognizer()
        XCTAssertTrue(run(&r, closed: closures, until: 62).isEmpty)
        XCTAssertGreaterThan(r.totalBlinks, 10, "the blinks were seen, just not acted on")
    }

    func testTimestampsGoingBackwardsReset() {
        var r = BlinkSequenceRecognizer()
        _ = run(&r, closed: [10.21...10.39], from: 10, until: 10.6)
        XCTAssertEqual(r.blinkCount, 1)
        _ = r.process(eyesClosed: false, at: 1)
        XCTAssertEqual(r.blinkCount, 0)
    }

    func testConfigurationFollowsSettings() {
        var settings = HeadsUpSettings.defaults
        settings.blinkSequenceWindow = 0.8
        settings.blinkMinClosure = 0.2
        settings.blinkMaxClosure = 0.1
        settings.blinkCooldown = 1.5
        let config = BlinkSequenceRecognizer.Configuration(settings: settings)
        XCTAssertEqual(config.sequenceWindow, 0.8)
        XCTAssertEqual(config.minClosure, 0.2)
        XCTAssertEqual(config.maxClosure, 0.2, "never below the minimum")
        XCTAssertEqual(config.actionCooldown, 1.5)
    }
}

final class EyeOpennessClassifierTests: XCTestCase {
    /// Feeds 30 Hz samples and returns the classification of each.
    private func feed(_ c: inout EyeOpennessClassifier, _ values: [Double], from start: Double = 0) -> [Bool?] {
        values.enumerated().map { index, value in c.classify(value, at: start + Double(index) / 30) }
    }

    func testLearnsBaselineThenDetectsClosure() {
        var c = EyeOpennessClassifier()
        let learning = feed(&c, Array(repeating: 0.32, count: 24))
        XCTAssertTrue(learning.dropLast().allSatisfy { $0 == nil }, "nothing reported while learning")
        XCTAssertEqual(learning.last, false)
        XCTAssertEqual(c.baseline ?? 0, 0.32, accuracy: 1e-9)
        XCTAssertEqual(feed(&c, [0.1, 0.1, 0.32], from: 1), [true, true, false])
    }

    func testBaselineIgnoresBlinksWhileLearning() {
        var c = EyeOpennessClassifier()
        var values = Array(repeating: 0.32, count: 24)
        values[5] = 0.08
        values[6] = 0.08
        _ = feed(&c, values)
        XCTAssertEqual(c.baseline ?? 0, 0.32, accuracy: 1e-9)
    }

    func testHysteresisPreventsFlicker() {
        var c = EyeOpennessClassifier()
        _ = feed(&c, Array(repeating: 0.4, count: 24))
        // 0.6 of baseline after closing stays closed; it only reopens above 0.75.
        XCTAssertEqual(feed(&c, [0.1, 0.24, 0.26, 0.24, 0.32], from: 1), [true, true, true, true, false])
        // 0.6 while open stays open.
        XCTAssertEqual(feed(&c, [0.24, 0.24], from: 2), [false, false])
    }

    func testWorksForNarrowEyesAndGlasses() {
        // A lower raw ratio (narrow eyes, glasses frames) behaves the same relative to baseline.
        var c = EyeOpennessClassifier()
        _ = feed(&c, Array(repeating: 0.18, count: 24))
        XCTAssertEqual(feed(&c, [0.06, 0.06, 0.18], from: 1), [true, true, false])
    }

    func testSlowPostureDriftIsNotABlink() {
        var c = EyeOpennessClassifier()
        _ = feed(&c, Array(repeating: 0.32, count: 24))
        // Over 20 s the eyes look half as open (looking down, lighting): never "closed".
        let drift = (0..<600).map { 0.32 - 0.16 * Double($0) / 600 }
        XCTAssertTrue(feed(&c, drift, from: 1).allSatisfy { $0 == false })
        XCTAssertEqual(feed(&c, [0.05, 0.16], from: 21), [true, false], "a real blink is still seen")
    }

    func testRelearnsAfterEyesWereLost() {
        var c = EyeOpennessClassifier()
        _ = feed(&c, Array(repeating: 0.32, count: 24))
        XCTAssertFalse(c.isLearning)
        XCTAssertNil(c.classify(0.2, at: 10), "a long gap starts learning again")
        XCTAssertTrue(c.isLearning)
    }

    func testInvalidReadingsAreUnknown() {
        var c = EyeOpennessClassifier()
        _ = feed(&c, Array(repeating: 0.32, count: 24))
        XCTAssertNil(c.classify(.nan, at: 1))
        XCTAssertNil(c.classify(0, at: 1.1))
    }

    func testSettingsKeepReopenAboveClosed() {
        var settings = HeadsUpSettings.defaults
        settings.blinkClosedRatio = 0.7
        settings.blinkReopenRatio = 0.65
        let config = EyeOpennessClassifier.Configuration(settings: settings)
        XCTAssertEqual(config.closedRatio, 0.7)
        XCTAssertEqual(config.reopenRatio, 0.8, accuracy: 1e-9)
    }
}

final class DominantFaceTests: XCTestCase {
    func testPicksTheUserNotABystander() {
        XCTAssertNil(DominantFace.index(ofAreas: []))
        XCTAssertEqual(DominantFace.index(ofAreas: [0.1]), 0)
        XCTAssertEqual(DominantFace.index(ofAreas: [0.02, 0.2]), 1, "a small face in the background is ignored")
        XCTAssertNil(DominantFace.index(ofAreas: [0.15, 0.2]), "two similar faces: ambiguous")
    }
}
