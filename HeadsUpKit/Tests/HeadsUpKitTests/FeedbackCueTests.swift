import XCTest
@testable import HeadsUpKit

/// Every user-facing action must play its confirmation cue.
@MainActor
final class FeedbackCueTests: XCTestCase {
    typealias S = TraceSynth

    private func cues(_ h: CoordinatorHarness, during action: () -> Void) -> [FeedbackCue] {
        let before = h.feedback.cues.count
        action()
        return Array(h.feedback.cues.dropFirst(before))
    }

    func testNodClickPlaysSelect() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.feed(1.5, pitch: [S.nod(at: 0.3)]) }, [.select])
    }

    func testShakeEscapePlaysCancel() {
        let h = CoordinatorHarness.tracking()
        XCTAssertEqual(cues(h) { h.feed(2, yaw: [S.shake(at: 0.5)]) }, [.cancel])
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

    func testScrollModeOnAndOffPlayCues() {
        var settings = CoordinatorHarness.testSettings
        settings.doubleNodEnabled = true
        let h = CoordinatorHarness.tracking(settings: settings)
        let entered = cues(h) { h.feed(2.4, pitch: [S.nod(at: 0.3), S.nod(at: 0.9)]) }
        XCTAssertTrue(entered.contains(.scrollOn))
        XCTAssertEqual(h.coordinator.state, .scrollMode)
        XCTAssertEqual(cues(h) { h.coordinator.exitScrollMode() }, [.scrollOff])
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

    func testDefaultsAndStoredInvalidVolumeAreReset() {
        XCTAssertGreaterThan(HeadsUpSettings.defaults.feedbackVolume, 0)
        XCTAssertFalse(HeadsUpSettings.defaults.feedbackMuted)
        var settings = HeadsUpSettings.defaults
        for bad in [0, -1, 3, .nan] as [Double] {
            settings.feedbackVolume = bad
            XCTAssertEqual(SettingsPersistence.sanitized(settings).feedbackVolume, HeadsUpSettings.defaults.feedbackVolume)
        }
        settings.feedbackVolume = 0.3
        XCTAssertEqual(SettingsPersistence.sanitized(settings).feedbackVolume, 0.3)
    }
}
