import HeadsUpKit
import SwiftUI

/// Menu-bar icon reflecting the current state.
struct MenuBarLabel: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        Image(systemName: symbol)
            .accessibilityLabel("HeadsUp: \(coordinator.state.displayName)")
    }

    private var symbol: String {
        switch coordinator.state {
        case .tracking: return "airpodspro"
        case .scrollMode: return "arrow.up.arrow.down.circle"
        case .listening, .voiceReview: return "mic.circle"
        case .paused: return "pause.circle"
        case .calibrating, .awaitingRecenter, .practicing: return "scope"
        case .needsPermissions: return "exclamationmark.triangle"
        case .waitingForHeadphones: return "airpodspro.chargingcase.wireless"
        }
    }
}

/// Menu-bar panel for caregivers: status and manual controls.
struct MenuBarView: View {
    @ObservedObject var coordinator: AppCoordinator
    let openSettings: () -> Void
    let openOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            statusRows
            Divider()
            controls
            Divider()
            HStack {
                Button("Settings…", action: openSettings)
                Spacer()
                Button("Quit HeadsUp") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("HeadsUp").font(.headline)
            Spacer()
            Text(coordinator.state.displayName)
                .font(.subheadline)
                .foregroundStyle(stateColor)
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            StatusRow(title: "Accessibility", ok: coordinator.permissionStatus.accessibilityTrusted)
            StatusRow(title: "Motion access", ok: coordinator.permissionStatus.motion != .denied
                      && coordinator.permissionStatus.motion != .restricted)
            StatusRow(title: "AirPods connected", ok: coordinator.isHeadphonesConnected)
            if let gesture = coordinator.lastGesture {
                Text("Last gesture: \(gesture.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(coordinator.state == .paused ? "Resume" : "Pause") { coordinator.togglePause() }
                .disabled(coordinator.state == .needsPermissions || coordinator.state == .waitingForHeadphones)
            Button("Recenter") { coordinator.recenter() }
                .disabled(coordinator.state != .tracking && coordinator.state != .awaitingRecenter)
            if coordinator.state == .scrollMode {
                Button("Exit scroll mode") { coordinator.exitScrollMode() }
            }
            Button("Recalibrate") { coordinator.recalibrate() }
                .disabled(!coordinator.permissionStatus.isReady)
            Button("Setup & permissions…", action: openOnboarding)
            Text("⌃⌥⌘H toggles pause from anywhere.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.link)
    }

    private var stateColor: Color {
        switch coordinator.state {
        case .tracking, .scrollMode, .listening, .voiceReview: return .green
        case .paused: return .secondary
        case .needsPermissions: return .red
        case .calibrating, .awaitingRecenter, .waitingForHeadphones, .practicing: return .orange
        }
    }
}

struct StatusRow: View {
    let title: String
    let ok: Bool

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? Color.green : Color.red)
        }
        .accessibilityValue(ok ? "OK" : "Missing")
    }
}

extension HeadGesture {
    var displayName: String {
        switch self {
        case .nod: return "Nod (click)"
        case .doubleNod: return "Double nod (scroll mode)"
        case .shake: return "Shake (Escape)"
        case .tiltHoldLeft: return "Tilt left (pause)"
        case .tiltHoldRight: return "Tilt right (recenter)"
        }
    }
}
