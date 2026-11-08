import CoreGraphics
import Foundation
@testable import HeadsUpKit

final class MockMotionSource: MotionSource, @unchecked Sendable {
    let poses: AsyncStream<HeadPose>
    let connectionChanges: AsyncStream<HeadphoneConnection>
    var isMotionAvailable = true
    private(set) var startCount = 0

    init() {
        poses = AsyncStream { _ in }
        connectionChanges = AsyncStream { _ in }
    }

    func start() { startCount += 1 }
    func stop() {}
}

@MainActor
final class MockCursor: CursorController {
    enum Event: Equatable {
        case move(CGPoint)
        case click(CGPoint)
        case key(KeyCommand)
    }

    private(set) var events: [Event] = []
    var currentPosition = CGPoint(x: 100, y: 100)

    func move(to point: CGPoint) {
        events.append(.move(point))
        currentPosition = point
    }

    func click(at point: CGPoint) {
        events.append(.click(point))
        currentPosition = point
    }

    func pressKey(_ key: KeyCommand) {
        events.append(.key(key))
    }

    var moves: [CGPoint] {
        events.compactMap { if case let .move(p) = $0 { return p } else { return nil } }
    }

    var clicks: [CGPoint] {
        events.compactMap { if case let .click(p) = $0 { return p } else { return nil } }
    }

    var keys: [KeyCommand] {
        events.compactMap { if case let .key(k) = $0 { return k } else { return nil } }
    }

    func clear() { events.removeAll() }
}

@MainActor
final class MockScroll: ScrollController {
    private(set) var totalDx = 0.0
    private(set) var totalDy = 0.0
    private(set) var calls = 0

    func scroll(dx: Double, dy: Double, at point: CGPoint) {
        totalDx += dx
        totalDy += dy
        calls += 1
    }
}

@MainActor
final class MockFeedback: FeedbackService {
    private(set) var cues: [FeedbackCue] = []
    func play(_ cue: FeedbackCue) { cues.append(cue) }
    func configure(volume: Double, muted: Bool, tickVolume: Double) {}
}

@MainActor
final class MockAnnouncer: Announcer {
    var isEnabled = true
    private(set) var phrases: [String] = []
    func announce(_ text: String) { phrases.append(text) }
}

@MainActor
final class MockPermissions: PermissionsProviding {
    var status = PermissionStatus(accessibilityTrusted: true, motion: .authorized, motionHardwareAvailable: true,
                                  microphone: .authorized, speechRecognition: .authorized)
    func currentStatus() -> PermissionStatus { status }
    func promptForAccessibility() {}
    func openAccessibilitySettings() {}
    func openMotionSettings() {}
    func requestMicrophone() {}
    func requestSpeechRecognition() {}
    func openMicrophoneSettings() {}
    func openSpeechRecognitionSettings() {}
}

@MainActor
final class MockKeepAlive: BackgroundKeepAlive {
    private(set) var isRunning = false
    func start() { isRunning = true }
    func stop() { isRunning = false }
}

/// Frames are driven explicitly by the test harness.
@MainActor
final class MockFrameClock: FrameClock {
    func start(_ onFrame: @escaping @MainActor (TimeInterval) -> Void) {}
    func stop() {}
}

@MainActor
final class MockTargets: TargetProvider {
    var targets: [ClickTarget] = []
    func requestTargets(near point: CGPoint, completion: @escaping @MainActor @Sendable ([ClickTarget]) -> Void) {
        completion(targets)
    }
    func invalidate() {}
}

@MainActor
final class MockFocusReader: FocusedElementReader {
    var onFocusChange: (@MainActor () -> Void)?
    var focused: FocusedElementInfo?
    func focusedElement() -> FocusedElement? { focused.map { FocusedElement(info: $0) } }
}

@MainActor
final class MockSpeech: SpeechToTextService {
    var authorization = AuthorizationState.authorized
    private(set) var startCount = 0
    private(set) var finishCount = 0
    private(set) var cancelCount = 0
    private var handler: (@MainActor (SpeechEvent) -> Void)?
    var heard = ""

    func requestAuthorization() {}

    func start(useBuiltInMicrophone: Bool, silenceTimeout: TimeInterval,
               onEvent: @escaping @MainActor (SpeechEvent) -> Void) -> Bool {
        startCount += 1
        handler = onEvent
        return true
    }

    func finish() {
        finishCount += 1
        emit(.final(heard))
    }

    func cancel() {
        cancelCount += 1
        handler = nil
    }

    func emit(_ event: SpeechEvent) {
        let current = handler
        if case .partial(let text) = event { heard = text } else { handler = nil }
        current?(event)
    }
}

@MainActor
final class MockInserter: TextInserter {
    private(set) var inserted: [String] = []
    private(set) var undone = 0
    private(set) var returns = 0

    func insert(_ text: String, into element: FocusedElement) -> InsertionRecord? {
        inserted.append(text)
        return InsertionRecord(method: .typed(characters: text.count), text: text)
    }

    func undo(_ record: InsertionRecord) { undone += 1 }
    func pressReturn() { returns += 1 }
}
