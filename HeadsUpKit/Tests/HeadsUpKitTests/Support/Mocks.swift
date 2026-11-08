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
    var currentPosition: CGPoint = CGPoint(x: 500, y: 400)

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

    var clicks: [CGPoint] {
        events.compactMap { if case let .click(p) = $0 { return p } else { return nil } }
    }

    var keys: [KeyCommand] {
        events.compactMap { if case let .key(k) = $0 { return k } else { return nil } }
    }

    func clear() { events.removeAll() }
}

@MainActor
final class MockFeedback: FeedbackService {
    private(set) var cues: [FeedbackCue] = []
    func play(_ cue: FeedbackCue) { cues.append(cue) }
    func configure(volume: Double, muted: Bool) {}
}

@MainActor
final class MockAnnouncer: Announcer {
    var isEnabled = true
    private(set) var phrases: [String] = []
    func announce(_ text: String) { phrases.append(text) }
}

@MainActor
final class MockPermissions: PermissionsProviding {
    var status = PermissionStatus(accessibilityTrusted: true, motion: .authorized, motionHardwareAvailable: true)
    func currentStatus() -> PermissionStatus { status }
    func promptForAccessibility() {}
    func openAccessibilitySettings() {}
    func openMotionSettings() {}
}

@MainActor
final class MockKeepAlive: BackgroundKeepAlive {
    private(set) var isRunning = false
    func start() { isRunning = true }
    func stop() { isRunning = false }
}
