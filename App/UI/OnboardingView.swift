import HeadsUpKit
import SwiftUI

/// One-time setup checklist, meant to be completed by a caregiver with mouse and keyboard.
/// Everything after setup is hands-free.
struct OnboardingView: View {
    @ObservedObject var coordinator: AppCoordinator
    let permissions: PermissionsProviding

    /// Accessibility doesn't notify on change, so poll while this view is visible.
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Set up HeadsUp").font(.title2.bold())
            Text("HeadsUp moves the pointer with head movement from AirPods. "
                 + "Complete these steps once; after that it is fully hands-free.")
                .foregroundStyle(.secondary)

            step(
                number: 1, title: "Allow Accessibility",
                detail: "Lets HeadsUp move the pointer, click and press Escape in other apps.",
                done: coordinator.permissionStatus.accessibilityTrusted
            ) {
                Button("Request Access") { permissions.promptForAccessibility() }
                Button("Open System Settings") { permissions.openAccessibilitySettings() }
            }

            step(
                number: 2, title: "Allow Motion",
                detail: motionDetail,
                done: coordinator.permissionStatus.motion == .authorized
            ) {
                Button("Open System Settings") { permissions.openMotionSettings() }
            }

            step(
                number: 3, title: "Connect AirPods",
                detail: "Wear AirPods Pro, AirPods (3rd gen or later), AirPods Max or Beats with head "
                    + "tracking, connected to this Mac and selected as the sound output.",
                done: coordinator.isHeadphonesConnected
            ) { EmptyView() }

            Divider()
            Text(nextStepText)
                .font(.callout)
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 440, minHeight: 480)
        .onReceive(poll) { _ in coordinator.refreshPermissions() }
    }

    private var motionDetail: String {
        switch coordinator.permissionStatus.motion {
        case .authorized: return "Motion access granted."
        case .notDetermined: return "macOS asks the first time the AirPods send motion. Click Allow."
        case .denied, .restricted: return "Motion access was denied. Enable HeadsUp in Privacy & Security."
        }
    }

    private var nextStepText: String {
        switch coordinator.state {
        case .needsPermissions: return "Waiting for permissions…"
        case .waitingForHeadphones: return "Waiting for AirPods to send motion…"
        case .calibrating: return "Calibration has started. The user follows the spoken prompts."
        case .awaitingRecenter: return "Ready. The user holds still facing the screen to recenter."
        case .tracking, .paused: return "All set. You can close this window."
        }
    }

    @ViewBuilder
    private func step<Actions: View>(
        number: Int, title: String, detail: String, done: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title2)
                .foregroundStyle(done ? Color.green : Color.accentColor)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
                if !done {
                    HStack { actions() }
                }
            }
        }
    }
}
