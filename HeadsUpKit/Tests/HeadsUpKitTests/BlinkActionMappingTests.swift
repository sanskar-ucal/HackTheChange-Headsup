import CoreGraphics
import XCTest
@testable import HeadsUpKit

/// Blink gestures reuse the head gestures' actions and feedback cues.
@MainActor
final class BlinkActionMappingTests: XCTestCase {
    private let point = CGPoint(x: 640, y: 360)

    func testBlinksMapLikeNodAndShake() {
        let dispatcher = ActionDispatcher(cursor: MockCursor(), feedback: MockFeedback())
        XCTAssertEqual(dispatcher.action(for: .doubleBlink), dispatcher.action(for: .nod))
        XCTAssertEqual(dispatcher.action(for: .tripleBlink), dispatcher.action(for: .shake))
    }

    func testDoubleBlinkClicksWithSelectCue() {
        let cursor = MockCursor()
        let feedback = MockFeedback()
        let dispatcher = ActionDispatcher(cursor: cursor, feedback: feedback)
        XCTAssertEqual(dispatcher.dispatch(.doubleBlink, at: point), .click)
        XCTAssertEqual(cursor.events, [.click(point)])
        XCTAssertEqual(feedback.cues, [.select])
    }

    func testTripleBlinkPressesEscapeWithCancelCue() {
        let cursor = MockCursor()
        let feedback = MockFeedback()
        let dispatcher = ActionDispatcher(cursor: cursor, feedback: feedback)
        XCTAssertEqual(dispatcher.dispatch(.tripleBlink, at: point), .escape)
        XCTAssertEqual(cursor.events, [.key(.escape)])
        XCTAssertEqual(feedback.cues, [.cancel])
    }

    func testEveryGestureHasAnAction() {
        let dispatcher = ActionDispatcher(cursor: MockCursor(), feedback: MockFeedback())
        for gesture in HeadGesture.allCases {
            XCTAssertNotEqual(dispatcher.action(for: gesture), .none, "\(gesture) is unmapped")
        }
    }
}
