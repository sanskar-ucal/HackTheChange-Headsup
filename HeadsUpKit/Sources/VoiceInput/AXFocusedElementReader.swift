import AppKit
import ApplicationServices
import Foundation

/// `FocusedElementReader` over the Accessibility API.
@MainActor
public final class AXFocusedElementReader: FocusedElementReader {
    public var onFocusChange: (@MainActor () -> Void)?

    private let systemWide = AXUIElementCreateSystemWide()
    private var observer: AXNotificationObserver?
    private var activationObserver: NSObjectProtocol?

    public init(messagingTimeout: Float = 0.05) {
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.observe(app) }
        }
        observe(NSWorkspace.shared.frontmostApplication)
    }

    public func focusedElement() -> FocusedElement? {
        guard let element = AX.element(systemWide, kAXFocusedUIElementAttribute) else { return nil }
        let info = FocusedElementInfo(
            role: AX.string(element, kAXRoleAttribute),
            subrole: AX.string(element, kAXSubroleAttribute),
            isValueSettable: AX.isSettable(element, kAXValueAttribute),
            placeholder: AX.string(element, "AXPlaceholderValue"),
            descriptionText: AX.string(element, kAXDescriptionAttribute),
            title: AX.string(element, kAXTitleAttribute),
            identifier: AX.string(element, "AXIdentifier"))
        return FocusedElement(info: info, handle: element)
    }

    private func observe(_ app: NSRunningApplication?) {
        observer?.invalidate()
        observer = nil
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        AccessibilityEnabler.prepare(app)
        observer = AXNotificationObserver(
            pid: app.processIdentifier, notifications: [kAXFocusedUIElementChangedNotification]
        ) { [weak self] _ in
            self?.onFocusChange?()
        }
    }
}
