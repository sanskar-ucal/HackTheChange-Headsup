import AppKit
import HeadsUpKit
import SwiftUI

@main
struct HeadsUpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                coordinator: appDelegate.environment.coordinator,
                openSettings: { appDelegate.showSettings() },
                openOnboarding: { appDelegate.showOnboarding() })
        } label: {
            MenuBarLabel(coordinator: appDelegate.environment.coordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Owns the long-lived objects and the AppKit windows that SwiftUI scenes don't cover.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) lazy var environment = AppEnvironment()
    private let windows = WindowPresenter()
    private var calibrationOverlay: CalibrationOverlayController?
    private var practiceOverlay: PracticeOverlayController?
    private var pointerOverlay: PointerOverlayController?
    private var hotKey: GlobalHotKey?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let coordinator = environment.coordinator
        calibrationOverlay = CalibrationOverlayController(coordinator: coordinator)
        practiceOverlay = PracticeOverlayController(coordinator: coordinator)
        pointerOverlay = PointerOverlayController(coordinator: coordinator, store: environment.settingsStore)
        // ⌃⌥⌘H toggles pause: a caregiver safety switch.
        hotKey = GlobalHotKey { [weak coordinator] in coordinator?.togglePause() }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak coordinator] _ in
            MainActor.assumeIsolated { coordinator?.refreshGeometry() }
        }

        coordinator.start()
        if coordinator.state == .needsPermissions { showOnboarding() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pointerOverlay?.restoreSystemCursor()
        environment.coordinator.stop()
    }

    func showSettings() {
        windows.show(id: "settings", title: "HeadsUp Settings", size: CGSize(width: 600, height: 800)) {
            SettingsView(
                store: environment.settingsStore,
                telemetry: environment.coordinator.telemetry,
                recorder: environment.coordinator.recorder,
                coordinator: environment.coordinator)
        }
    }

    func showOnboarding() {
        windows.show(id: "onboarding", title: "Set up HeadsUp", size: CGSize(width: 500, height: 640)) {
            OnboardingView(coordinator: environment.coordinator, permissions: environment.permissions)
        }
    }
}

/// Creates and re-focuses plain AppKit windows hosting SwiftUI views. A menu-bar
/// (LSUIElement) app has to activate itself for its windows to come to the front.
@MainActor
final class WindowPresenter {
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(id: String, title: String, size: CGSize, @ViewBuilder content: () -> Content) {
        let window = windows[id] ?? makeWindow(title: title, size: size, content: content())
        windows[id] = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow<Content: View>(title: String, size: CGSize, content: Content) -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.center()
        return window
    }
}
