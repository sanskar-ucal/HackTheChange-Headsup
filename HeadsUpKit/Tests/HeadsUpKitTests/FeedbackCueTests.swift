import XCTest
@testable import HeadsUpKit

/// Every user-facing action must play its confirmation cue.
@MainActor
final class FeedbackCueTests: XCTestCase {
    typealias S = TraceSynth
    typealias B = EARTrace.Blink

    private static var blinkSettings: HeadsUpSettings {
        var settings = CoordinatorHarness.testSettings
        settings.blinkEnabled = true
        settings.clickInput = .both
        return settings
    }

    private func cues(_ h: CoordinatorHarness, during action: () -> Void) -> [FeedbackCue] {
        let before = h.feedback.cues.count
        action()
        return Array(h.feedback.cues.dropFirst(before))
    }

    private func blink(_ h: CoordinatorHarness, _ blinks: [B]) {
        for frame in EARTrace.frames(duration: 3.5, start: h.clock, blinks: blinks) {
            h.coordinator.headRateDegPerSec = 0
            h.coordinator.handle(faceFrame: frame)
        }
    }

    func testNodClickPlaysSelect() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.feed(1.5, pitch: [S.nod(at: 0.3)]) }, [.select])
    }

    func testShakePlaysCancel() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.feed(2, yaw: [S.shake(at: 0.5)]) }, [.cancel])
    }

    func testDoubleBlinkPlaysSelect() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings)
        XCTAssertEqual(cues(h) { blink(h, [B(at: 1.0), B(at: 1.4)]) }, [.select])
    }

    func testTripleBlinkPlaysCancel() {
        let h = CoordinatorHarness.tracking(settings: Self.blinkSettings)
        XCTAssertEqual(cues(h) { blink(h, [B(at: 1.0), B(at: 1.4), B(at: 1.8)]) }, [.cancel])
    }

    func testPauseAndResumePlayCues() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.coordinator.togglePause() }, [.paused])
        XCTAssertEqual(cues(h) { h.coordinator.togglePause() }, [.resumed])
    }

    func testRecenterPlaysCue() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.coordinator.recenter() }, [.recentered])
    }

    func testListeningPlaysStartCue() {
        let h = CoordinatorHarness.tracking()
        h.focus.focused = FocusedElementInfo(role: "AXTextField", subrole: "AXSearchField")
        let played = cues(h) { h.feed(2, pitch: [S.nod(at: 0.3)]) }
        XCTAssertEqual(h.coordinator.state, .listening)
        XCTAssertEqual(played.first, .select)
        XCTAssertTrue(played.contains(.listeningStart))
    }

    func testTestSoundPlaysSelect() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.coordinator.playTestSound() }, [.select])
    }

    func testStoredZeroVolumeIsReset() {
        var settings = HeadsUpSettings.defaults
        settings.feedbackVolume = 0
        XCTAssertEqual(SettingsPersistence.sanitized(settings).feedbackVolume, HeadsUpSettings.defaults.feedbackVolume)
        settings.feedbackVolume = .nan
        XCTAssertEqual(SettingsPersistence.sanitized(settings).feedbackVolume, HeadsUpSettings.defaults.feedbackVolume)
        settings.feedbackVolume = 0.3
        XCTAssertEqual(SettingsPersistence.sanitized(settings).feedbackVolume, 0.3)
        XCTAssertGreaterThan(HeadsUpSettings.defaults.feedbackVolume, 0)
        XCTAssertFalse(HeadsUpSettings.defaults.feedbackMuted)
    }
}
