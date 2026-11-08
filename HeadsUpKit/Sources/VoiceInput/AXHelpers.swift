import AppKit
import ApplicationServices
import Foundation

/// Thin wrappers over the Accessibility C API, used by voice input.
enum AX {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)  // swiftlint:disable:this force_cast — type checked above
    }

    static func children(_ element: AXUIElement) -> [AXUIElement] {
        guard let value = attribute(element, kAXChildrenAttribute) as? [AnyObject] else { return [] }
        return value.compactMap { item in
            CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil  // swiftlint:disable:this force_cast
        }
    }

    static func actionNames(_ element: AXUIElement) -> [String] {
        var names: CFArray?
        guard AXUIElementCopyActionNames(element, &names) == .success else { return [] }
        return (names as? [String]) ?? []
    }

    static func isSettable(_ element: AXUIElement, _ name: String) -> Bool {
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(element, name as CFString, &settable) == .success else { return false }
        return settable.boolValue
    }

    /// Element frame in global top-left coordinates (AXPosition is already top-left).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let positionValue = attribute(element, kAXPositionAttribute),
              let sizeValue = attribute(element, kAXSizeAttribute),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        // swiftlint:disable force_cast
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { return nil }
        // swiftlint:enable force_cast
        return CGRect(origin: position, size: size)
    }
}

/// Chromium and Electron apps only build their accessibility tree for web content when
/// asked. This turns it on for the frontmost app so search fields and links are visible.
public enum AccessibilityEnabler {
    static let chromeFamily: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.brave.Browser", "com.microsoft.edgemac", "com.vivaldi.Vivaldi", "org.chromium.Chromium",
    ]

    public static func prepare(_ app: NSRunningApplication) {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        if let bundleID = app.bundleIdentifier, chromeFamily.contains(bundleID) {
            AXUIElementSetAttributeValue(element, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
        }
    }
}

/// Wraps an `AXObserver` for one app and a set of notifications, delivered on the main
/// run loop.
@MainActor
final class AXNotificationObserver {
    let pid: pid_t
    private var observer: AXObserver?
    private let handler: @MainActor (String) -> Void

    init?(pid: pid_t, notifications: [String], handler: @escaping @MainActor (String) -> Void) {
        self.pid = pid
        self.handler = handler
        var created: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let me = Unmanaged<AXNotificationObserver>.fromOpaque(refcon).takeUnretainedValue()
            let name = notification as String
            MainActor.assumeIsolated { me.handler(name) }
        }
        guard AXObserverCreate(pid, callback, &created) == .success, let created else { return nil }
        observer = created
        let app = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in notifications {
            AXObserverAddNotification(created, app, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
    }

    func invalidate() {
        guard let observer else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = nil
    }
}
