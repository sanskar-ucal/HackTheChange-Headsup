import CoreGraphics
import XCTest
@testable import HeadsUpKit

@MainActor
final class ScrollToTopTests: XCTestCase {
    typealias S = TraceSynth

    /// A button frame centered on wherever the pointer currently rests.
    private func buttonFrame(around h: CoordinatorHarness) -> CGRect {
        let point = h.coordinator.lastPostedPoint ?? h.cursor.currentPosition
        return CGRect(x: point.x - 28, y: point.y - 28, width: 56, height: 56)
    }

    func testNodOnTheButtonScrollsToTopInsteadOfClicking() {
        let h = CoordinatorHarness.tracking()
        h.coordinator.scrollToTopFrame = buttonFrame(around: h)
        h.cursor.clear()
        h.feed(1.5, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks, [], "no mouse click reaches the app under the button")
        XCTAssertEqual(h.cursor.keys, [.scrollToTop])
        XCTAssertTrue(h.feedback.cues.contains(.select))
        XCTAssertEqual(h.coordinator.scrollToTopFlash, 1)
    }

    func testNodOutsideTheButtonStillClicks() {
        let h = CoordinatorHarness.tracking()
        h.coordinator.scrollToTopFrame = CGRect(x: 900, y: 90, width: 56, height: 56)
        h.cursor.clear()
        h.feed(1.5, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks.count, 1)
        XCTAssertEqual(h.cursor.keys, [])
        XCTAssertEqual(h.coordinator.scrollToTopFlash, 0)
    }

    func testButtonIsIgnoredWhenTheSettingIsOff() {
        var settings = CoordinatorHarness.testSettings
        settings.showScrollToTopButton = false
        let h = CoordinatorHarness.tracking(settings: settings)
        h.coordinator.scrollToTopFrame = buttonFrame(around: h)
        h.cursor.clear()
        h.feed(1.5, pitch: [S.nod(at: 0.3)])
        XCTAssertEqual(h.cursor.clicks.count, 1)
        XCTAssertEqual(h.cursor.keys, [])
    }

    func testBrowsersGetHomeAndOtherAppsGetCommandUp() {
        XCTAssertTrue(HeadsUpSettings.defaults.showScrollToTopButton)
        for browser in ["com.google.Chrome", "com.apple.Safari", "company.thebrowser.Browser",
                        "com.microsoft.edgemac", "org.mozilla.firefox"] {
            XCTAssertEqual(ScrollToTopKey.key(forFrontmostBundleID: browser), .home, browser)
        }
        XCTAssertEqual(ScrollToTopKey.key(forFrontmostBundleID: "com.apple.TextEdit"), .commandUp)
        XCTAssertEqual(ScrollToTopKey.key(forFrontmostBundleID: nil), .commandUp)
    }
}
