import AppKit
import Combine
import HeadsUpKit
import SwiftUI

/// A click-through window that follows the pointer and draws the chosen pointer style, the tilt-hold ring.
@MainActor
final class PointerOverlayController {
    /// Where the click point sits inside the overlay window (top-left coordinates).
    static let anchor = CGPoint(x: 110, y: 100)
    static let windowSize = CGSize(width: 380, height: 260)

    private let coordinator: AppCoordinator
    private let store: SettingsStore
    private let window: NSWindow
    private var followTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var cursorHidden = false

    init(coordinator: AppCoordinator, store: SettingsStore) {
        self.coordinator = coordinator
        self.store = store
        window = NSWindow(contentRect: CGRect(origin: .zero, size: Self.windowSize),
                          styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: PointerOverlayView(coordinator: coordinator, store: store))

        coordinator.$state
            .map(Self.showsPointer)
            .removeDuplicates()
            .sink { [weak self] visible in
                if visible { self?.show() } else { self?.hide() }
            }
            .store(in: &cancellables)
        coordinator.$state.combineLatest(store.$settings.map(\.hideSystemCursor))
            .sink { [weak self] state, hide in self?.updateSystemCursor(hide: hide && state.allowsPointerMotion) }
            .store(in: &cancellables)
    }

    nonisolated private static func showsPointer(_ state: AppState) -> Bool {
        switch state {
        case .tracking, .paused, .awaitingRecenter, .practicing, .scrollMode, .listening, .voiceReview: return true
        case .needsPermissions, .waitingForHeadphones, .calibrating: return false
        }
    }

    func restoreSystemCursor() {
        updateSystemCursor(hide: false)
    }

    private func updateSystemCursor(hide: Bool) {
        guard hide != cursorHidden else { return }
        cursorHidden = hide
        if hide { CGDisplayHideCursor(CGMainDisplayID()) } else { CGDisplayShowCursor(CGMainDisplayID()) }
    }

    private func show() {
        follow()
        window.orderFrontRegardless()
        guard followTimer == nil else { return }
        followTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.follow() }
        }
    }

    private func hide() {
        followTimer?.invalidate()
        followTimer = nil
        window.orderOut(nil)
    }

    /// `NSEvent.mouseLocation` and window frames are both AppKit (bottom-left) coordinates.
    private func follow() {
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(x: mouse.x - Self.anchor.x,
                                      y: mouse.y - (Self.windowSize.height - Self.anchor.y)))
    }
}

/// The pointer glyph plus hold ring and transcript, drawn around the overlay anchor.
struct PointerOverlayView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var store: SettingsStore

    var body: some View {
        let settings = store.settings
        let size = CGFloat(settings.pointerSize.points)
        let shape = settings.pointerStyle.style.shape(for: coordinator.pointerContext)
        let anchor = PointerOverlayController.anchor

        ZStack(alignment: .topLeading) {
            if let hold = coordinator.holdProgress {
                Circle()
                    .trim(from: 0, to: hold.fraction)
                    .stroke(hold.gesture == .tiltHoldLeft ? Color.yellow : Color.blue,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 1.5, height: size * 1.5)
                    .offset(x: anchor.x - size * 0.75, y: anchor.y - size * 0.75)
            }
            PointerGlyphView(shape: shape, color: settings.resolvedPointerColor.color, size: size,
                             highContrast: settings.pointerHighContrast)
                .id(shapeKey(shape))
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
                .offset(x: anchor.x - CGFloat(shape.hotspot.x) * size, y: anchor.y - CGFloat(shape.hotspot.y) * size)
            if !coordinator.transcript.isEmpty {
                TranscriptBubble(text: coordinator.transcript, reviewing: coordinator.state == .voiceReview)
                    .offset(x: anchor.x + size * 0.5, y: anchor.y + size * 0.6)
            }
        }
        .opacity(settings.pointerOpacity)
        .animation(.easeOut(duration: 0.12), value: shapeKey(shape))
        .frame(width: PointerOverlayController.windowSize.width,
               height: PointerOverlayController.windowSize.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func shapeKey(_ shape: PointerShape) -> String {
        "\(shape.glyph)-\(shape.badge ?? "")-\(shape.dimmed)-\(shape.emphasized)"
    }
}

/// Live transcript next to the pointer while listening; hint while reviewing.
struct TranscriptBubble: View {
    let text: String
    let reviewing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(3)
            if reviewing {
                Text("Nod: search · Shake: undo")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(10)
        .frame(maxWidth: 240, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.8)))
    }
}
