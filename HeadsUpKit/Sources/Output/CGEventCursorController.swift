import AppKit
import ApplicationServices
import Carbon.HIToolbox
import CoreGraphics
import Foundation

/// `CursorController` backed by `CGEvent`.
@MainActor
public final class CGEventCursorController: CursorController {
    private let source = CGEventSource(stateID: .hidSystemState)
    private let escapeKeyCode: CGKeyCode = 53

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
        var flags: CGEventFlags = []
        switch key {
        case .escape:
            code = escapeKeyCode
        case .scrollToTop:
            let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            switch ScrollToTopKey.key(forFrontmostBundleID: bundleID) {
            case .home:
                code = CGKeyCode(kVK_Home)
            case .commandUp:
                code = CGKeyCode(kVK_UpArrow)
                flags = .maskCommand
            }
        }
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: isDown)
            if !flags.isEmpty { event?.flags = flags }
            event?.post(tap: .cghidEventTap)
        }
    }
}
