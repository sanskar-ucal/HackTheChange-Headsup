import XCTest
@testable import HeadsUpKit

final class BlinkSettingsTests: XCTestCase {
    func testBlinkDefaultsAreOffAndConsistent() {
        let settings = HeadsUpSettings.defaults
        XCTAssertFalse(settings.blinkGesturesEnabled, "the camera is opt-in")
        XCTAssertLessThan(settings.blinkMinClosure, settings.blinkMaxClosure)
        XCTAssertLessThan(settings.blinkClosedRatio, settings.blinkReopenRatio, "hysteresis needs a gap")
        XCTAssertGreaterThan(settings.blinkSequenceWindow, 0)
        XCTAssertGreaterThan(settings.blinkCooldown, 0)
    }

    func testSettingsDefaultsMatchTheRecognizerDefaults() {
        // The pure types have their own defaults for tests; they must not drift from the app's.
        XCTAssertEqual(BlinkSequenceRecognizer.Configuration(settings: .defaults),
                       BlinkSequenceRecognizer.Configuration())
        XCTAssertEqual(EyeOpennessClassifier.Configuration(settings: .defaults),
                       EyeOpennessClassifier.Configuration())
    }

    func testBlinkSettingsPersist() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HeadsUpTests.\(UUID().uuidString)"))
        let persistence = SettingsPersistence(defaults: defaults)
        var settings = HeadsUpSettings.defaults
        settings.blinkGesturesEnabled = true
        settings.blinkSequenceWindow = 0.7
        settings.blinkMinClosure = 0.15
        settings.blinkMaxClosure = 0.6
        settings.blinkCooldown = 1.2
        settings.blinkClosedRatio = 0.45
        persistence.save(settings)
        XCTAssertEqual(persistence.load(), settings)
    }
}
