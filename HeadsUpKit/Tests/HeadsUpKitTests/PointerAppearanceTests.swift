import XCTest
@testable import HeadsUpKit

final class PointerAppearanceTests: XCTestCase {
    private let hand = HandPointerStyle()

    private func symbol(_ shape: PointerShape) -> String? {
        if case let .symbol(name) = shape.glyph { return name }
        return nil
    }

    func testHandShapesByContext() {
        XCTAssertEqual(symbol(hand.shape(for: .idle)), "hand.raised.fill")
        XCTAssertEqual(symbol(hand.shape(for: .hoveringClickable)), "hand.point.up.left.fill")
        XCTAssertEqual(symbol(hand.shape(for: .pressing)), "hand.tap.fill")
        let scrolling = hand.shape(for: .scrolling(.up))
        XCTAssertEqual(symbol(scrolling), "hand.point.up.fill")
        XCTAssertEqual(scrolling.badge, "chevron.up")
        XCTAssertEqual(hand.shape(for: .scrolling(.down)).badge, "chevron.down")
        XCTAssertEqual(hand.shape(for: .listening).badge, "mic.fill")
        let paused = hand.shape(for: .paused)
        XCTAssertTrue(paused.dimmed)
        XCTAssertEqual(paused.badge, "pause.fill")
    }

    func testHandHotspotIsAtTheFingertipNotTheCenter() {
        let pointing = hand.shape(for: .hoveringClickable)
        XCTAssertLessThan(pointing.hotspot.x, 0.3)
        XCTAssertLessThan(pointing.hotspot.y, 0.2)
    }

    func testEveryStyleShowsModeBadgesAndPause() {
        for kind in PointerStyleKind.allCases {
            let style = kind.style
            XCTAssertEqual(style.kind, kind)
            XCTAssertEqual(style.shape(for: .listening).badge, "mic.fill", "\(kind)")
            XCTAssertNotNil(style.shape(for: .scrolling(.none)).badge, "\(kind)")
            XCTAssertTrue(style.shape(for: .paused).dimmed, "\(kind)")
            XCTAssertTrue(style.shape(for: .hoveringClickable).emphasized, "\(kind)")
        }
        XCTAssertEqual(PointerStyleKind.greenCircle.style.shape(for: .idle).glyph, .circle)
    }

    func testContextResolution() {
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .tracking)), .idle)
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .tracking, isPressing: true)), .pressing)
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .tracking, scrollDirection: .down)),
                       .scrolling(.down))
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .scrollMode)), .scrolling(.none))
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .listening, isPressing: true)), .listening)
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .paused, holdFraction: 0.5)), .paused)
        XCTAssertEqual(PointerContextResolver.context(for: .init(state: .tracking, holdFraction: 0.5)), .tiltProgress(0.5))
        XCTAssertEqual(PointerContextResolver.direction(of: ScrollVelocity(vertical: 10)), .up)
        XCTAssertNil(PointerContextResolver.direction(of: .zero))
    }

    func testDefaultsAreGreenCircleAndCalm() {
        let settings = HeadsUpSettings.defaults
        XCTAssertEqual(settings.pointerStyle, .greenCircle, "the v1 halo is the default")
        XCTAssertEqual(settings.resolvedPointerColor, .green)
        XCTAssertEqual(settings.pointerSize, .large)
        XCTAssertTrue(settings.pointerHighContrast)
        XCTAssertEqual(settings.sensitivity, 0.6)
        XCTAssertEqual(settings.filterMinCutoff, 1.0, "v1 One Euro defaults")
        XCTAssertEqual(settings.filterBeta, 0.007)
        XCTAssertEqual(settings.pointerDeadZonePoints, 3)
        XCTAssertEqual(settings.holdAfterClick, 0.4)
        XCTAssertFalse(settings.doubleNodEnabled)
        XCTAssertFalse(settings.practiceEnabled)
        var hand = settings
        hand.pointerStyle = .hand
        XCTAssertEqual(hand.resolvedPointerColor, .white)
    }

    func testSettingsPersistenceRoundTrip() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "HeadsUpTests.\(UUID().uuidString)"))
        let persistence = SettingsPersistence(defaults: defaults)
        var settings = HeadsUpSettings.defaults
        settings.pointerStyle = .ring
        settings.pointerColor = .blue
        settings.pointerSize = .small
        settings.pointerOpacity = 0.7
        settings.pointerHighContrast = false
        settings.voiceInputTrigger = .allTextFields
        settings.sensitivity = 0.45
        persistence.save(settings)
        XCTAssertEqual(persistence.load(), settings)

        settings.pointerColor = nil
        persistence.save(settings)
        XCTAssertNil(persistence.load().pointerColor, "back to the style default")
    }

    func testOldStoredSettingsMergeOverNewDefaults() throws {
        let partial = try JSONSerialization.data(withJSONObject: ["sensitivity": 0.9, "pointerStyle": "dot"])
        let merged = try XCTUnwrap(SettingsPersistence.decodeMerged(partial))
        XCTAssertEqual(merged.sensitivity, 0.9)
        XCTAssertEqual(merged.pointerStyle, .dot)
        XCTAssertEqual(merged.snapRadius, HeadsUpSettings.defaults.snapRadius)
    }
}
