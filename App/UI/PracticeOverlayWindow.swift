import AppKit
import Combine
import HeadsUpKit
import SwiftUI

/// Full-screen, click-through overlay for the first-run practice targets.
@MainActor
final class PracticeOverlayController {
    private let coordinator: AppCoordinator
    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        cancellable = coordinator.$state
            .map { $0 == .practicing }
            .removeDuplicates()
            .sink { [weak self] practicing in
                if practicing { self?.show() } else { self?.window?.orderOut(nil) }
            }
    }

    private func show() {
        let frame = coordinator.screenGeometry.appKitRect(fromGlobal: coordinator.pointingRect)
        let window = self.window ?? makeWindow()
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        self.window = window
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: PracticeOverlayView(coordinator: coordinator))
        return window
    }
}

/// Practice targets and the countdown shown after calibration.
struct PracticeOverlayView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.45)
                if let session = coordinator.practice {
                    let radius = CGFloat(session.radius) * proxy.size.height
                    ForEach(Array(session.targets.enumerated()), id: \.offset) { _, target in
                        Circle()
                            .fill(target.hit ? Color.green.opacity(0.7) : Color.white.opacity(0.18))
                            .overlay(Circle().stroke(Color.white, lineWidth: 4))
                            .overlay(Image(systemName: target.hit ? "checkmark" : "hand.tap.fill")
                                .font(.system(size: radius * 0.6, weight: .bold))
                                .foregroundStyle(.white))
                            .frame(width: radius * 2, height: radius * 2)
                            .position(x: CGFloat(target.center.x) * proxy.size.width,
                                      y: CGFloat(target.center.y) * proxy.size.height)
                    }
                    banner(for: session)
                        .position(x: proxy.size.width / 2, y: proxy.size.height * 0.12)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func banner(for session: PracticeSession) -> some View {
        VStack(spacing: 8) {
            switch session.phase {
            case .running:
                Text("Practice").font(.title3).foregroundStyle(.white.opacity(0.7))
                Text("Point at each circle and nod").font(.system(size: 30, weight: .semibold))
            case let .suggesting(value):
                Text(String(format: "Suggested sensitivity: %.2f (now %.2f)", value, session.currentSensitivity))
                    .font(.system(size: 30, weight: .semibold))
                Text("Nod to accept · Shake to keep the current setting").font(.title3)
            case .finished:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
    }
}
