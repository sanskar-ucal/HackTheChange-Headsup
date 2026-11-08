import CoreGraphics
import XCTest
@testable import HeadsUpKit

/// Synthetic 30 fps Eye Aspect Ratio traces.
enum EARTrace {
    struct Blink {
        var at: Double
        var length: Double = 0.15
        var leftOnly = false
    }

    static func frames(duration: Double, start: Double = 0, open: Double = 0.30, closed: Double = 0.05,
                       blinks: [Blink] = [], confidence: (Double) -> Double = { _ in 1 }) -> [FaceFrame] {
        stride(from: 0.0, to: duration, by: 1.0 / 30).map { t in
            let jitter = 0.006 * sin(t * 37)
            var left = open + jitter
            var right = open - jitter
            for blink in blinks where t >= blink.at && t < blink.at + blink.length {
                left = closed
                if !blink.leftOnly { right = closed }
            }
            let eyes = EyeSample(leftEAR: left, rightEAR: right, confidence: confidence(t))
            return FaceFrame(timestamp: start + t, brightness: 0.5, eyes: eyes)
        }
    }
}

/// Detector + sequence + quality, wired the way the coordinator wires them.
struct BlinkPipeline {
    var detector = BlinkDetector()
    var sequence = BlinkSequenceRecognizer()
    var quality = BlinkQualityMonitor()

    mutating func run(_ frames: [FaceFrame]) -> [BlinkPattern] {
        var patterns: [BlinkPattern] = []
        for frame in frames {
            var events: [BlinkSequenceEvent] = []
            if quality.assess(frame) != .ok {
                detector.reset()
                events += sequence.reset()
            } else if let eyes = frame.eyes {
                for event in detector.process(eyes, at: frame.timestamp) { events += sequence.handle(event) }
                events += sequence.update(now: frame.timestamp)
            }
            for case let .recognized(pattern, _) in events { patterns.append(pattern) }
        }
        return patterns
    }
}

final class BlinkDetectorTests: XCTestCase {
    typealias B = EARTrace.Blink

    private func patterns(_ blinks: [B], duration: Double = 4) -> [BlinkPattern] {
        var pipeline = BlinkPipeline()
        return pipeline.run(EARTrace.frames(duration: duration, blinks: blinks))
    }

    func testSingleBlinkDoesNothing() {
        XCTAssertEqual(patterns([B(at: 1.0)]), [])
    }

    func testDoubleBlinkClicks() {
        XCTAssertEqual(patterns([B(at: 1.0), B(at: 1.4)]), [.double])
    }

    func testTripleBlinkEscapes() {
        XCTAssertEqual(patterns([B(at: 1.0), B(at: 1.4), B(at: 1.8)]), [.triple])
    }

    func testFourBlinksDoNothing() {
        XCTAssertEqual(patterns([B(at: 1.0), B(at: 1.4), B(at: 1.8), B(at: 2.2)]), [])
    }

    func testLongClosureDoesNothing() {
        XCTAssertEqual(patterns([B(at: 1.0, length: 0.8)]), [])
        XCTAssertEqual(patterns([B(at: 1.0), B(at: 1.4, length: 0.8)]), [], "a long second closure cancels")
    }

    func testWinkDoesNothing() {
        XCTAssertEqual(patterns([B(at: 1.0, leftOnly: true), B(at: 1.4, leftOnly: true)]), [])
    }

    func testBlinksFarApartAreTwoSingles() {
        XCTAssertEqual(patterns([B(at: 1.0), B(at: 2.2)]), [])
    }

    func testLowConfidenceResetsTheSequence() {
        var pipeline = BlinkPipeline()
        let frames = EARTrace.frames(duration: 4, blinks: [B(at: 1.0), B(at: 1.5)],
                                     confidence: { t in t > 1.25 && t < 1.35 ? 0.2 : 1 })
        XCTAssertEqual(pipeline.run(frames), [], "the first blink is forgotten, the second is a single")
        XCTAssertEqual(BlinkQualityMonitor().assess(frames[40]), .noFace)
    }

    func testCooldownIgnoresAnImmediateSecondSequence() {
        let blinks = [B(at: 1.0), B(at: 1.4), B(at: 2.05), B(at: 2.4)]
        XCTAssertEqual(patterns(blinks), [.double], "the second pair starts inside the 700 ms cooldown")
    }

    func testBaselineAdaptsToADifferentUser() {
        var pipeline = BlinkPipeline()
        _ = pipeline.run(EARTrace.frames(duration: 6, open: 0.30))
        XCTAssertEqual(pipeline.detector.leftBaseline ?? 0, 0.30, accuracy: 0.01)

        _ = pipeline.run(EARTrace.frames(duration: 8, start: 6, open: 0.15, closed: 0.03))
        XCTAssertEqual(pipeline.detector.leftBaseline ?? 0, 0.15, accuracy: 0.01)
        let result = pipeline.run(EARTrace.frames(duration: 3, start: 14, open: 0.15, closed: 0.03,
                                                  blinks: [B(at: 0.5), B(at: 0.9)]))
        XCTAssertEqual(result, [.double])
    }

    func testEyeAspectRatioIgnoresRoll() {
        let eye = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 2), CGPoint(x: 20, y: 0), CGPoint(x: 10, y: -2)]
        let rotated = eye.map { CGPoint(x: $0.x * 0.8 - $0.y * 0.6, y: $0.x * 0.6 + $0.y * 0.8) }
        XCTAssertEqual(EyeAspectRatio.compute(eye), 0.2, accuracy: 1e-6)
        XCTAssertEqual(EyeAspectRatio.compute(rotated), 0.2, accuracy: 1e-6)
    }

    func testQualityStatuses() {
        let monitor = BlinkQualityMonitor()
        let good = EyeSample(leftEAR: 0.3, rightEAR: 0.3)
        XCTAssertEqual(monitor.assess(FaceFrame(timestamp: 0, brightness: 0.5, eyes: good)), .ok)
        XCTAssertEqual(monitor.assess(FaceFrame(timestamp: 0, brightness: 0.5, eyes: nil)), .noFace)
        XCTAssertEqual(monitor.assess(FaceFrame(timestamp: 0, brightness: 0.05, eyes: good)), .lowLight)
        var turned = good
        turned.faceYawDegrees = 40
        XCTAssertEqual(monitor.assess(FaceFrame(timestamp: 0, brightness: 0.5, eyes: turned)), .faceTurned)
        var far = good
        far.faceSize = 0.05
        XCTAssertEqual(monitor.assess(FaceFrame(timestamp: 0, brightness: 0.5, eyes: far)), .tooFar)
    }
}

@MainActor
final class BlinkCoordinatorTests: XCTestCase {
    typealias B = EARTrace.Blink

    private static func blinkSettings(_ input: ClickInput = .both) -> HeadsUpSettings {
        var settings = CoordinatorHarness.testSettings
        settings.blinkEnabled = true
        settings.clickInput = input
        return settings
    }

    private func feedFaces(_ h: CoordinatorHarness, blinks: [B], headRate: Double = 0) {
        for frame in EARTrace.frames(duration: 3.5, start: h.clock, blinks: blinks) {
            h.coordinator.headRateDegPerSec = headRate
            h.coordinator.handle(faceFrame: frame)
        }
    }

    func testDoubleBlinkClicksWhereThePointerWas() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings())
        h.cursor.clear()
        let anchor = h.coordinator.lastPostedPoint ?? h.cursor.currentPosition
        feedFaces(h, blinks: [B(at: 1.0), B(at: 1.4)])
        XCTAssertEqual(h.cursor.clicks.count, 1)
        XCTAssertEqual(h.cursor.clicks.first, anchor)
        XCTAssertEqual(h.coordinator.blinkTelemetry.lastAction, "Double blink → Click")
    }

    func testTripleBlinkPressesEscape() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings())
        h.cursor.clear()
        feedFaces(h, blinks: [B(at: 1.0), B(at: 1.4), B(at: 1.8)])
        XCTAssertEqual(h.cursor.keys, [.escape])
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testBlinksDuringFastHeadMotionDoNothing() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings())
        h.cursor.clear()
        feedFaces(h, blinks: [B(at: 1.0), B(at: 1.4)], headRate: 90)
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testBlinksDoNothingWhilePaused() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings())
        h.coordinator.togglePause()
        h.cursor.clear()
        feedFaces(h, blinks: [B(at: 1.0), B(at: 1.4)])
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testBlinksDoNothingWhenTheFeatureIsOff() {
        let h = CoordinatorHarness.tracking()
        h.cursor.clear()
        feedFaces(h, blinks: [B(at: 1.0), B(at: 1.4)])
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testBlinksOnlyModeTurnsNodClicksOff() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings(.blinks))
        h.cursor.clear()
        h.feed(1.5, pitch: [TraceSynth.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks, [])
    }

    func testNodStillClicksWithBothInputs() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings(.both))
        h.cursor.clear()
        h.feed(1.5, pitch: [TraceSynth.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks.count, 1)
    }
}
