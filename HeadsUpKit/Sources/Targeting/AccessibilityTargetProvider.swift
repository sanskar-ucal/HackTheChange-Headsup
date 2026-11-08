import AppKit
import ApplicationServices
import Foundation
import QuartzCore

/// Discovers buttons, links and fields near the pointer through the Accessibility API.
///
/// Scans run on a background serial queue with a short messaging timeout, an element cap
/// and subtree pruning (subtrees whose frames miss the search box are skipped). Results are
/// cached and invalidated by AX notifications and app switches.
@MainActor
public final class AccessibilityTargetProvider: TargetProvider {
    public var searchRadius: CGFloat
    public var maxElements: Int
    public var messagingTimeout: Float

    private let queue = DispatchQueue(label: "HeadsUp.targets", qos: .userInitiated)
    private var cache = TargetCache()
    private var scanInFlight = false
    private var observer: AXNotificationObserver?
    private var activationObserver: NSObjectProtocol?

    private static let invalidatingNotifications = [
        kAXWindowMovedNotification, kAXWindowResizedNotification, kAXUIElementDestroyedNotification,
        kAXValueChangedNotification, kAXFocusedWindowChangedNotification, kAXLayoutChangedNotification,
        kAXCreatedNotification,
    ]

    public init(searchRadius: CGFloat = 200, maxElements: Int = 400, messagingTimeout: Float = 0.05) {
        self.searchRadius = searchRadius
        self.maxElements = maxElements
        self.messagingTimeout = messagingTimeout
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            MainActor.assumeIsolated { self?.appActivated(app) }
        }
        if let app = NSWorkspace.shared.frontmostApplication { appActivated(app) }
    }

    public func invalidate() {
        cache.invalidate()
    }

    public func requestTargets(near point: CGPoint, completion: @escaping @MainActor ([ClickTarget]) -> Void) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            completion([])
            return
        }
        let pid = app.processIdentifier
        let now = CACurrentMediaTime()
        if let cached = cache.lookup(point: point, pid: pid, time: now, margin: searchRadius / 2) {
            completion(cached)
            return
        }
        guard !scanInFlight else { return }
        scanInFlight = true
        let box = CGRect(x: point.x - searchRadius, y: point.y - searchRadius,
                         width: searchRadius * 2, height: searchRadius * 2)
        let limit = maxElements, timeout = messagingTimeout
        queue.async { [weak self] in
            let targets = AccessibilityScanner.scan(pid: pid, box: box, limit: limit, timeout: timeout)
            Task { @MainActor in
                guard let self else { return }
                self.scanInFlight = false
                self.cache.store(targets, box: box, pid: pid, time: CACurrentMediaTime())
                completion(targets)
            }
        }
    }

    private func appActivated(_ app: NSRunningApplication?) {
        cache.invalidate()
        guard let app, app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        AccessibilityEnabler.prepare(app)
        observer?.invalidate()
        observer = AXNotificationObserver(
            pid: app.processIdentifier, notifications: Self.invalidatingNotifications
        ) { [weak self] _ in
            self?.cache.invalidate()
        }
    }
}

/// The background scan. Pure AX reads; no main-actor state.
enum AccessibilityScanner {
    static let actionableRoles: Set<String> = [
        "AXButton", "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton",
        "AXMenuItem", "AXTab", "AXTextField", "AXSearchField", "AXSlider", "AXDisclosureTriangle",
        "AXComboBox", "AXTextArea",
    ]

    static func scan(pid: pid_t, box: CGRect, limit: Int, timeout: Float) -> [ClickTarget] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        guard let window = AX.element(app, kAXFocusedWindowAttribute) else { return [] }

        var pending = [window]
        var index = 0
        var results: [ClickTarget] = []
        while index < pending.count && index < limit {
            let element = pending[index]
            index += 1
            let frame = AX.frame(element)
            if let frame, frame.width > 0, frame.height > 0, !frame.intersects(box) {
                continue  // prune: nothing inside can be near the pointer
            }
            if let frame, frame.width > 0, frame.height > 0, let role = actionableRole(element) {
                results.append(ClickTarget(frame: frame, role: role))
            }
            pending.append(contentsOf: AX.children(element))
        }
        return results
    }

    private static func actionableRole(_ element: AXUIElement) -> String? {
        let role = AX.string(element, kAXRoleAttribute) ?? ""
        if actionableRoles.contains(role) { return role }
        if AX.string(element, kAXSubroleAttribute) == "AXSearchField" { return "AXSearchField" }
        if AX.actionNames(element).contains(kAXPressAction) { return role.isEmpty ? "AXPress" : role }
        return nil
    }
}
