import AppKit
import Combine
import HeadsUpKit
import SwiftUI

/// Floating "↑ Top" button near the top-right corner of the main screen. Nodding on it scrolls the
/// frontmost app to the top, so the user never has to push the pointer into the top edge, where
/// browsers and full-screen apps reveal their toolbars instead of scrolling.
@MainActor
final class ScrollToTopPanelController {
    static let buttonSize: CGFloat = 56
    static let topInset: CGFloat = 90
    static let rightInset: CGFloat = 24
    /// Extra room around the button so the flash animation isn't clipped.
    static let padding: CGFloat = 8

    private let coordinator: AppCoordinator
    private let store: SettingsStore
    private let panel: NSPanel
    private var proximityTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var screenObserver: NSObjectProtocol?

    init(coordinator: AppCoordinator, store: SettingsStore) {
        self.coordinator = coordinator
        self.store = store
        let side = Self.buttonSize + Self.padding * 2
        panel = NSPanel(contentRect: CGRect(x: 0, y: 0, width: side, height: side),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.alphaValue = 0.45
        panel.contentView = NSHostingView(rootView: ScrollToTopButtonView(
            coordinator: coordinator, store: store, action: { [weak coordinator] in coordinator?.scrollToTop() }))

        coordinator.$state.combineLatest(store.$settings.map(\.showScrollToTopButton))
            .map { state, enabled in enabled && Self.isVisible(in: state) }
            .removeDuplicates()
            .sink { [weak self] visible in
                if visible { self?.show() } else { self?.hide() }
            }
            .store(in: &cancellables)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
    }

    /// Only shown where a nod would act; hidden while paused, calibrating or not yet set up.
    nonisolated private static func isVisible(in state: AppState) -> Bool {
        switch state {
        case .tracking, .scrollMode, .listening, .voiceReview: return true
        case .needsPermissions, .waitingForHeadphones, .calibrating, .practicing, .awaitingRecenter, .paused:
            return false
        }
    }

    private func show() {
        reposition()
        panel.orderFrontRegardless()
        guard proximityTimer == nil else { return }
        proximityTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateProximity() }
        }
    }

    private func hide() {
        proximityTimer?.invalidate()
        proximityTimer = nil
        panel.orderOut(nil)
        coordinator.scrollToTopFrame = nil
    }

    /// Places the panel on the main (menu bar) screen and publishes the button's frame in the
    /// global top-left coordinates the coordinator uses for clicks.
    private func reposition() {
        guard let screen = NSScreen.screens.first else { return }
        let side = Self.buttonSize + Self.padding * 2
        let origin = CGPoint(x: screen.frame.maxX - Self.rightInset - Self.buttonSize - Self.padding,
                             y: screen.frame.maxY - Self.topInset - Self.buttonSize - Self.padding)
        panel.setFrame(CGRect(origin: origin, size: CGSize(width: side, height: side)), display: true)
        // AppKit is bottom-left; flip against the main screen's height for the global top-left space.
        let button = panel.frame.insetBy(dx: Self.padding, dy: Self.padding)
        coordinator.scrollToTopFrame = CGRect(x: button.minX, y: screen.frame.maxY - button.maxY,
                                              width: button.width, height: button.height)
    }

    /// Semi-transparent until the pointer comes near, so it doesn't distract while reading.
    private func updateProximity() {
        let mouse = NSEvent.mouseLocation
        let center = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        let near = hypot(mouse.x - center.x, mouse.y - center.y) < 140
        let target: CGFloat = near ? 1 : 0.45
        if abs(panel.alphaValue - target) > 0.01 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                panel.animator().alphaValue = target
            }
        }
    }
}

/// 56 pt rounded button in the pointer's colors, with a short flash when used.
struct ScrollToTopButtonView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: SettingsStore
    let action: () -> Void
    @State private var flashing = false

    var body: some View {
        let fill = store.settings.resolvedPointerColor
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: "arrow.up").font(.system(size: 18, weight: .bold))
                Text("Top").font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(Self.isLight(fill) ? Color.black : Color.white)
            .frame(width: ScrollToTopPanelController.buttonSize, height: ScrollToTopPanelController.buttonSize)
            .background(RoundedRectangle(cornerRadius: 14).fill(fill.color.opacity(flashing ? 1 : 0.85)))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.black.opacity(0.35), lineWidth: 1.5))
            .scaleEffect(flashing ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scroll to top")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.15), value: flashing)
        .onChange(of: coordinator.scrollToTopFlash) {
            flashing = true
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                flashing = false
            }
        }
    }

    private static func isLight(_ color: RGBAColor) -> Bool {
        0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue > 0.55
    }
}
