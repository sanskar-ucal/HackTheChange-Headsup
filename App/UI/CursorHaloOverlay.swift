import AppKit
import Combine
import HeadsUpKit
import SwiftUI

/// A small click-through ring that follows the pointer. Its color shows tracking / paused /
/// waiting-to-recenter, and it fills while a tilt-hold (or auto-recenter) is in progress.
@MainActor
final class CursorHaloController {
    private static let size: CGFloat = 76

    private let coordinator: AppCoordinator
    private let window: NSWindow
    private var followTimer: Timer?
    private var cancellable: AnyCancellable?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: Self.size, height: Self.size),
            styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: CursorHaloView(coordinator: coordinator))

        cancellable = coordinator.$state
            .map(Self.showsHalo)
            .removeDuplicates()
            .sink { [weak self] visible in
                if visible { self?.show() } else { self?.hide() }
            }
    }

    nonisolated private static func showsHalo(_ state: AppState) -> Bool {
        switch state {
        case .tracking, .paused, .awaitingRecenter: return true
        case .needsPermissions, .waitingForHeadphones, .calibrating: return false
        }
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

    /// `NSEvent.mouseLocation` and window frames are both AppKit (bottom-left) coordinates,
    /// so no conversion is needed here.
    private func follow() {
        let mouse = NSEvent.mouseLocation
        window.setFrameOrigin(CGPoint(x: mouse.x - Self.size / 2, y: mouse.y - Self.size / 2))
    }
}

struct CursorHaloView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.85), lineWidth: 3)
                .padding(10)
            if let hold = coordinator.holdProgress {
                Circle()
                    .trim(from: 0, to: hold.fraction)
                    .stroke(holdColor(hold.gesture), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(6)
            }
            if coordinator.state == .paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(ringColor)
                    .offset(x: 22, y: -22)
            }
        }
        .frame(width: 76, height: 76)
        .allowsHitTesting(false)
    }

    private var ringColor: Color {
        switch coordinator.state {
        case .tracking: return .green
        case .awaitingRecenter: return .orange
        default: return .gray
        }
    }

    private func holdColor(_ gesture: HeadGesture) -> Color {
        gesture == .tiltHoldLeft ? .yellow : .blue
    }
}
