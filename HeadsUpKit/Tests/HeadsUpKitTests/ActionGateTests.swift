import CoreGraphics
import XCTest
@testable import HeadsUpKit

/// The event gates are HeadsUp's safety switch: no synthetic input unless the user is
/// actively pointing (or in a mode they deliberately entered).
final class AppStateGateTests: XCTestCase {
    private let all: [AppState] = [
        .needsPermissions, .waitingForHeadphones, .calibrating(.center), .calibrating(.centerCheck),
        .practicing, .awaitingRecenter, .tracking, .scrollMode, .listening, .voiceReview, .paused,
    ]

    func testPointerMovesOnlyWhileTrackingOrPracticing() {
        let moving = all.filter(\.allowsPointerMotion)
        XCTAssertEqual(moving, [.practicing, .tracking])
    }

    func testActionsOnlyInTrackingAndUserEnteredModes() {
        let acting = all.filter(\.allowsActions)
        XCTAssertEqual(acting, [.tracking, .scrollMode, .listening, .voiceReview])
    }

    func testNothingIsPostedWhilePausedCalibratingOrUnready() {
        for state in [AppState.paused, .calibrating(.topLeft), .needsPermissions, .waitingForHeadphones,
                      .awaitingRecenter] {
            XCTAssertFalse(state.allowsEventPosting, "\(state)")
        }
        XCTAssertTrue(AppState.practicing.allowsEventPosting, "practice moves the pointer")
    }

    func testIsCalibrating() {
        XCTAssertTrue(AppState.calibrating(.bottomLeft).isCalibrating)
        XCTAssertFalse(AppState.tracking.isCalibrating)
    }
}

@MainActor
final class ActionDispatcherTests: XCTestCase {
    private let point = CGPoint(x: 120, y: 340)

    func testDefaultMapping() {
        let dispatcher = ActionDispatcher(cursor: MockCursor(), feedback: MockFeedback())
        XCTAssertEqual(dispatcher.action(for: .nod), .click)
        XCTAssertEqual(dispatcher.action(for: .shake), .escape)
        XCTAssertEqual(dispatcher.action(for: .doubleNod), .toggleScrollMode)
        XCTAssertEqual(dispatcher.action(for: .tiltHoldLeft), .togglePause)
        XCTAssertEqual(dispatcher.action(for: .tiltHoldRight), .recenter)
    }

    func testClickPostsAtThePointWithSelectCue() {
        let cursor = MockCursor()
        let feedback = MockFeedback()
        let dispatcher = ActionDispatcher(cursor: cursor, feedback: feedback)
        XCTAssertEqual(dispatcher.dispatch(.nod, at: point), .click)
        XCTAssertEqual(cursor.events, [.click(point)])
        XCTAssertEqual(feedback.cues, [.select])
    }

    func testEscapePressesKeyWithCancelCue() {
        let cursor = MockCursor()
        let feedback = MockFeedback()
        let dispatcher = ActionDispatcher(cursor: cursor, feedback: feedback)
        XCTAssertEqual(dispatcher.dispatch(.shake, at: point), .escape)
        XCTAssertEqual(cursor.events, [.key(.escape)])
        XCTAssertEqual(feedback.cues, [.cancel])
    }

    func testAppControlActionsPostNoInput() {
        let cursor = MockCursor()
        let feedback = MockFeedback()
        let dispatcher = ActionDispatcher(cursor: cursor, feedback: feedback)
        for gesture in [HeadGesture.doubleNod, .tiltHoldLeft, .tiltHoldRight] {
            XCTAssertNotEqual(dispatcher.dispatch(gesture, at: point), .none)
        }
        XCTAssertEqual(cursor.events, [], "the coordinator handles pause, recenter and scroll mode")
        XCTAssertEqual(feedback.cues, [])
    }

    func testCustomMappingAndUnmappedGestures() {
        let cursor = MockCursor()
        let dispatcher = ActionDispatcher(cursor: cursor, feedback: MockFeedback(), mapping: [.shake: .click])
        XCTAssertEqual(dispatcher.dispatch(.shake, at: point), .click)
        XCTAssertEqual(dispatcher.dispatch(.nod, at: point), .none, "unmapped gestures do nothing")
        XCTAssertEqual(cursor.events, [.click(point)])
    }
}
