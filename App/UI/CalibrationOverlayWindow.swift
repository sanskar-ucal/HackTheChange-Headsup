import AppKit
import Combine
import HeadsUpKit
import SwiftUI

/// Shows a full-screen, click-through overlay with the calibration targets while the
/// coordinator is calibrating.
@MainActor
final class CalibrationOverlayController {
    private let coordinator: AppCoordinator
    private var window: NSWindow?
    private var cancellable: AnyCancellable?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        cancellable = coordinator.$state
            .map(\.isCalibrating)
            .removeDuplicates()
            .sink { [weak self] calibrating in
                if calibrating { self?.show() } else { self?.hide() }
            }
    }

    private func show() {
        let geometry = coordinator.screenGeometry
        let frame = geometry.appKitRect(fromGlobal: coordinator.pointingRect)
        let window = self.window ?? makeWindow()
        window.setFrame(frame, display: true)
        window.orderFrontRegardless()
        self.window = window
    }

    private func hide() {
        window?.orderOut(nil)
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
        window.contentView = NSHostingView(rootView: CalibrationOverlayView(coordinator: coordinator))
        return window
    }
}

struct CalibrationOverlayView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.6)
                if case let .calibrating(step) = coordinator.state {
                    let target = step.target(inset: coordinator.settings.calibrationTargetInset)
                    DwellTarget(progress: coordinator.calibrationProgress)
                        .position(x: target.x * proxy.size.width, y: target.y * proxy.size.height)
                    instructions(for: step)
                        .position(x: proxy.size.width / 2, y: proxy.size.height * (step == .center || step == .centerCheck ? 0.68 : 0.5))
                }
            }
        }
        .ignoresSafeArea()
    }

    private func instructions(for step: CalibrationStep) -> some View {
        VStack(spacing: 12) {
            Text("Calibration · \(step.number) of \(CalibrationStep.allCases.count)")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.7))
            Text(step.prompt)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
            Text("Point your head at the dot and hold still until the ring fills.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
            if let message = coordinator.calibrationMessage {
                Text(message)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: 760)
    }
}

/// A large target with a ring that fills while the user dwells on it.
struct DwellTarget: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 120, height: 120)
            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 10)
                .frame(width: 120, height: 120)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 120, height: 120)
                .animation(.linear(duration: 0.1), value: progress)
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
        }
    }
}
