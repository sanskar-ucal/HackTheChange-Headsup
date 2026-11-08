import Combine
import XCTest
@testable import HeadsUpKit

/// The Settings blink indicator observes `LiveTelemetry`; it must re-render on blink
/// transitions, not on every ~30 Hz camera frame.
@MainActor
final class BlinkReadoutPublishingTests: XCTestCase {
    private var subscription: AnyCancellable?

    private func trackingWithBlinks() -> CoordinatorHarness {
        var settings = CoordinatorHarness.testSettings
        settings.blinkGesturesEnabled = true
        let h = CoordinatorHarness(savedCalibration: CoordinatorHarness.calibration, settings: settings)
        h.coordinator.start()
        h.coordinator.handleConnection(.connected)
        h.holdStill(2.6)
        h.feedEyes(1)  // learn the open-eye baseline
        return h
    }

    private func countPublishes(_ h: CoordinatorHarness, during body: () -> Void) -> Int {
        var count = 0
        subscription = h.coordinator.telemetry.objectWillChange.sink { count += 1 }
        body()
        subscription = nil
        return count
    }

    func testSteadyOpenEyesPublishNothing() {
        let h = trackingWithBlinks()
        XCTAssertEqual(countPublishes(h) { h.feedEyes(2) }, 0, "60 identical frames, no re-render")
    }

    func testABlinkPublishesOnlyItsTransitions() {
        let h = trackingWithBlinks()
        let count = countPublishes(h) { h.feedEyes(2, closed: [0.21...0.39]) }
        // Closed, reopened (+1 blink), sequence cleared.
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThanOrEqual(count, 4)
        XCTAssertEqual(h.coordinator.telemetry.blink.blinksSeen, 1)
    }
}
