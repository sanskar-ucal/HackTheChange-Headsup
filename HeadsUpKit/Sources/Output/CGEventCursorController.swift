import ApplicationServices
import CoreGraphics
import Foundation

/// `CursorController` backed by `CGEvent`. Requires the Accessibility permission and an
/// unsandboxed app. Moves are posted as real `mouseMoved` events so hover states update
/// in other apps.
@MainActor
public final class CGEventCursorController: CursorController {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let escapeKeyCode: CGKeyCode = 53  // kVK_Escape

    public init() {}

    public var currentPosition: CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }

    public func move(to point: CGPoint) {
        guard AXIsProcessTrusted() else { return }
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    public func click(at point: CGPoint) {
        guard AXIsProcessTrusted() else { return }
        move(to: point)
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
            event?.setIntegerValueField(.mouseEventClickState, value: 1)
            event?.post(tap: .cghidEventTap)
        }
    }

    public func pressKey(_ key: KeyCommand) {
        guard AXIsProcessTrusted() else { return }
        let code: CGKeyCode
        switch key {
        case .escape: code = escapeKeyCode
        }
        for isDown in [true, false] {
            CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: isDown)?.post(tap: .cghidEventTap)
        }
    }
}
