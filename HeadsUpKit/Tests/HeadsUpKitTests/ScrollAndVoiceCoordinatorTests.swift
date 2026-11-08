import CoreGraphics
import XCTest
@testable import HeadsUpKit

@MainActor
final class ScrollingCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

    func testEdgePushScrollsUpWhenLookingPastTheTop() {
        let h = CoordinatorHarness.tracking()
        h.holdStill(1.5, pitch: 25)  // top edge at 15°; 10° overshoot
        XCTAssertGreaterThan(h.scroll.totalDy, 100, "scrolls up (reveals content above)")
        XCTAssertEqual(h.cursor.moves.last?.y ?? -1, 0, accuracy: 1, "pointer pinned at the top")
        XCTAssertEqual(h.coordinator.pointerContext, .scrolling(.up))
    }

    func testEdgePushScrollsDownWhenLookingPastTheBottom() {
        let h = CoordinatorHarness.tracking()
        h.holdStill(1.5, pitch: -25)  // bottom edge at 15°; 10° overshoot
        XCTAssertLessThan(h.scroll.totalDy, -100, "head down scrolls down")
        XCTAssertEqual(h.cursor.moves.last?.y ?? -1, 800, accuracy: 1, "pointer pinned at the bottom")
        XCTAssertEqual(h.coordinator.pointerContext, .scrolling(.down))
    }

    func testEdgePushEngagesAtDefaultSensitivityJustPastTheEngageZone() {
        var settings = CoordinatorHarness.testSettings
        settings.sensitivity = HeadsUpSettings.defaults.sensitivity
        let h = CoordinatorHarness.tracking(settings: settings)
        h.holdStill(1.5, pitch: -29)  // bottom edge at 25° (15° / 0.6); 4° overshoot
        XCTAssertLessThan(h.scroll.totalDy, -50, "a small tilt past the edge already scrolls noticeably")
    }

    func testEdgeScrollIsOnByDefault() {
        XCTAssertTrue(HeadsUpSettings.defaults.edgeScrollEnabled)
    }

    func testNoEdgeScrollJustInsideTheEngageZone() {
        let h = CoordinatorHarness.tracking()
        h.holdStill(1.5, pitch: 17)  // 2° past the edge: below the 3° engage overshoot
        XCTAssertEqual(h.scroll.calls, 0)
    }

    func testInvertedDirectionSetting() {
        var settings = CoordinatorHarness.testSettings
        settings.naturalScrolling = false
        let h = CoordinatorHarness.tracking(settings: settings)
        h.holdStill(1.5, pitch: 25)
        XCTAssertLessThan(h.scroll.totalDy, -100)
    }

    func testDoubleNodTogglesScrollModeAndShakeExits() {
        var settings = CoordinatorHarness.testSettings
        settings.doubleNodEnabled = true
        let h = CoordinatorHarness.tracking(settings: settings)
        h.feed(2.4, pitch: [S.nod(at: 0.3), S.nod(at: 0.9)])
        XCTAssertEqual(h.coordinator.state, .scrollMode)
        XCTAssertTrue(h.feedback.cues.contains(.scrollOn))
        XCTAssertEqual(h.cursor.clicks, [], "a double nod does not click")

        let movesBefore = h.cursor.moves.count
        h.holdStill(1.5, pitch: 12)  // look up relative to the settled pose
        XCTAssertGreaterThan(h.scroll.totalDy, 100)
        XCTAssertEqual(h.cursor.moves.count, movesBefore, "pointer is frozen in scroll mode")

        h.feed(2, yaw: [S.shake(at: 0.3)], pitch: [S.constant(12)])
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertTrue(h.feedback.cues.contains(.scrollOff))
        XCTAssertEqual(h.cursor.keys, [], "the exit shake does not press Escape")
    }

    func testNoScrollingWhileListening() {
        let h = CoordinatorHarness.tracking()
        h.focus.focused = FocusedElementInfo(role: "AXTextField", subrole: "AXSearchField")
        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.coordinator.state, .listening)
        h.holdStill(1.5, pitch: 25)
        XCTAssertEqual(h.scroll.calls, 0)
    }
}

@MainActor
final class VoiceInputCoordinatorTests: XCTestCase {
    typealias S = TraceSynth

    private func listeningHarness(_ info: FocusedElementInfo = FocusedElementInfo(role: "AXTextField",
                                                                                  subrole: "AXSearchField")) -> CoordinatorHarness {
        let h = CoordinatorHarness.tracking()
        h.focus.focused = info
        h.feed(2, pitch: [S.nod(at: 0.3)])  // nod-click into the field
        return h
    }

    func testClickIntoSearchFieldStartsListening() {
        let h = listeningHarness()
        XCTAssertEqual(h.cursor.clicks.count, 1)
        XCTAssertEqual(h.coordinator.state, .listening)
        XCTAssertEqual(h.speech.startCount, 1)
        XCTAssertTrue(h.feedback.cues.contains(.listeningStart))
        XCTAssertEqual(h.coordinator.pointerContext, .listening)
    }

    func testPasswordFieldNeverListens() {
        let h = listeningHarness(FocusedElementInfo(role: "AXTextField", subrole: "AXSecureTextField"))
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.speech.startCount, 0)
    }

    func testPlainTextFieldOnlyWithAllFieldsSetting() {
        let h = listeningHarness(FocusedElementInfo(role: "AXTextField", placeholder: "Name"))
        XCTAssertEqual(h.coordinator.state, .tracking, "search fields only by default")
    }

    func testTranscriptThenNodPressesReturn() {
        let h = listeningHarness()
        h.speech.emit(.partial("weather"))
        XCTAssertEqual(h.coordinator.transcript, "weather")
        h.speech.emit(.final("weather tomorrow"))
        XCTAssertEqual(h.inserter.inserted, ["weather tomorrow"])
        XCTAssertEqual(h.coordinator.state, .voiceReview)

        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.inserter.returns, 1)
        XCTAssertEqual(h.inserter.undone, 0)
        XCTAssertEqual(h.coordinator.state, .tracking)
    }

    func testShakeAfterInsertionUndoes() {
        let h = listeningHarness()
        h.speech.emit(.final("oops"))
        h.feed(2, yaw: [S.shake(at: 0.3)])
        XCTAssertEqual(h.inserter.undone, 1)
        XCTAssertEqual(h.inserter.returns, 0)
        XCTAssertEqual(h.cursor.keys, [], "no Escape while reviewing")
        XCTAssertEqual(h.coordinator.state, .tracking)
    }

    func testWaitingKeepsTheText() {
        let h = listeningHarness()
        h.speech.emit(.final("keep me"))
        h.holdStill(4.5)
        XCTAssertEqual(h.coordinator.state, .tracking)
        XCTAssertEqual(h.inserter.undone, 0)
        XCTAssertEqual(h.inserter.returns, 0)
    }

    func testNodWhileListeningFinishesAndShakeCancels() {
        let h = listeningHarness()
        h.speech.emit(.partial("pizza"))
        h.feed(2, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.speech.finishCount, 1)
        XCTAssertEqual(h.inserter.inserted, ["pizza"])

        let other = listeningHarness()
        other.feed(2, yaw: [S.shake(at: 0.3)])
        XCTAssertEqual(other.speech.cancelCount, 1)
        XCTAssertEqual(other.inserter.inserted, [])
        XCTAssertEqual(other.coordinator.state, .tracking)
    }

    func testPointerFrozenWhileListeningButTiltPauseWorks() {
        let h = listeningHarness()
        let moves = h.cursor.moves.count
        h.holdStill(1, yaw: 10)
        XCTAssertEqual(h.cursor.moves.count, moves)
        h.feed(2.4, roll: [S.plateau(-25, from: 0.1, to: 2.0)])
        XCTAssertEqual(h.coordinator.state, .paused)
        XCTAssertGreaterThanOrEqual(h.speech.cancelCount, 1)
    }
}

final class TextFieldDetectorTests: XCTestCase {
    func testClassification() {
        let search = FocusedElementInfo(role: "AXTextField", subrole: "AXSearchField")
        let hinted = FocusedElementInfo(role: "AXTextField", placeholder: "Search the web")
        let plain = FocusedElementInfo(role: "AXTextField", placeholder: "First name")
        let area = FocusedElementInfo(role: "AXTextArea")
        let combo = FocusedElementInfo(role: "AXComboBox", descriptionText: "Search")
        let button = FocusedElementInfo(role: "AXButton", title: "Search")
        let readOnly = FocusedElementInfo(role: "AXTextField", subrole: "AXSearchField", isValueSettable: false)

        XCTAssertTrue(TextFieldDetector.shouldListen(search, trigger: .searchFieldsOnly))
        XCTAssertTrue(TextFieldDetector.shouldListen(hinted, trigger: .searchFieldsOnly))
        XCTAssertTrue(TextFieldDetector.shouldListen(combo, trigger: .searchFieldsOnly))
        XCTAssertFalse(TextFieldDetector.shouldListen(plain, trigger: .searchFieldsOnly))
        XCTAssertTrue(TextFieldDetector.shouldListen(plain, trigger: .allTextFields))
        XCTAssertTrue(TextFieldDetector.shouldListen(area, trigger: .allTextFields))
        XCTAssertFalse(TextFieldDetector.shouldListen(button, trigger: .allTextFields))
        XCTAssertFalse(TextFieldDetector.shouldListen(readOnly, trigger: .allTextFields))
        XCTAssertFalse(TextFieldDetector.shouldListen(search, trigger: .off))
    }

    func testSecureFieldsAreNeverTargets() {
        for info in [FocusedElementInfo(role: "AXTextField", subrole: "AXSecureTextField", placeholder: "Search"),
                     FocusedElementInfo(role: "AXSecureTextField")] {
            XCTAssertTrue(TextFieldDetector.isSecure(info))
            XCTAssertFalse(TextFieldDetector.shouldListen(info, trigger: .allTextFields))
        }
    }

    func testJoinAddsSeparatingSpace() {
        XCTAssertEqual(AXTextInserter.join("", "cats"), "cats")
        XCTAssertEqual(AXTextInserter.join("funny", "cats"), "funny cats")
        XCTAssertEqual(AXTextInserter.join("funny ", "cats"), "funny cats")
    }
}
