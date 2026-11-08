import HeadsUpKit
import SwiftUI

/// Blink gestures from the Mac's camera: an alternative to nod (click) and shake (Escape).
struct BlinkSettingsSection: View {
    @Binding var settings: HeadsUpSettings
    @ObservedObject var coordinator: AppCoordinator
    let telemetry: LiveTelemetry
    let permissions: PermissionsProviding

    var body: some View {
        BigToggle(title: "Blink gestures (camera)",
                  help: "Double blink clicks, triple blink presses Escape. Nod and shake keep working.",
                  isOn: $settings.blinkGesturesEnabled)
        HelpText("Video is analyzed on this Mac only to measure how open your eyes are. It is never saved or "
                 + "sent, and faces are never identified. The camera runs only while this is on and HeadsUp "
                 + "is tracking; pausing turns it off.")

        if settings.blinkGesturesEnabled {
            CameraStatusRow(status: coordinator.cameraStatus,
                            openSettings: { permissions.openCameraSettings() },
                            retry: { coordinator.retryBlinkCamera() })
            BlinkIndicatorView(telemetry: telemetry, isTracking: coordinator.state == .tracking)
            SliderRow(title: "Time between blinks",
                      help: "Blinks must follow each other this quickly. A double blink clicks after waiting this "
                          + "long for a third.",
                      value: $settings.blinkSequenceWindow, range: 0.3...1.0, step: 0.05, format: "%.2f s",
                      minLabel: "Quicker click", maxLabel: "More time")
            SliderRow(title: "Shortest blink",
                      help: "Shorter eye closures are ignored. Raise it if ordinary blinks are being counted.",
                      value: $settings.blinkMinClosure, range: 0.05...0.3, step: 0.01, format: "%.2f s")
            SliderRow(title: "Longest blink",
                      help: "Keeping your eyes closed longer than this is resting, not blinking.",
                      value: $settings.blinkMaxClosure, range: 0.3...1.0, step: 0.05, format: "%.2f s")
            SliderRow(title: "Blink cooldown", help: "Pause after a blink action before another can trigger.",
                      value: $settings.blinkCooldown, range: 0.3...2, step: 0.05, format: "%.2f s")
            SliderRow(title: "Eye-closed threshold",
                      help: "How closed your eyes must look compared with open. Raise it if blinks are missed "
                          + "(for example with glasses); lower it if squinting counts as a blink.",
                      value: $settings.blinkClosedRatio, range: 0.3...0.7, step: 0.05, format: "%.0f%%",
                      scale: 100)
        }
    }
}

private struct CameraStatusRow: View {
    let status: CameraStatus
    let openSettings: () -> Void
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(color)
            Text(status.displayName)
            Spacer()
            switch status {
            case .denied, .restricted:
                Button("Open Camera Settings", action: openSettings).frame(minHeight: 44)
                Button("Try again", action: retry).frame(minHeight: 44)
            case .noCamera, .failed:
                Button("Try again", action: retry).frame(minHeight: 44)
            case .off, .standby, .requestingAccess, .starting, .running:
                EmptyView()
            }
        }
        .accessibilityElement(children: .combine)
        if status == .denied {
            HelpText("Allow HeadsUp under Privacy & Security › Camera, then choose Try again.")
        }
    }

    private var symbol: String {
        switch status {
        case .running: return "video.fill"
        case .denied, .restricted, .noCamera, .failed: return "video.slash.fill"
        case .off, .standby, .requestingAccess, .starting: return "video"
        }
    }

    private var color: Color {
        if status == .running { return .green }
        return status.isProblem ? .orange : .secondary
    }
}

/// Live check that the camera sees the eyes and counts blinks.
struct BlinkIndicatorView: View {
    @ObservedObject var telemetry: LiveTelemetry
    let isTracking: Bool

    private var blink: BlinkReadout { telemetry.blink }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: blink.eyesClosed ? "eye.slash.fill" : "eye.fill")
                .font(.system(size: 30))
                .foregroundStyle(blink.face == .tracked ? (blink.eyesClosed ? Color.orange : Color.green)
                                 : Color.secondary)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(faceText)
                if isTracking {
                    HStack(spacing: 6) {
                        Text("Blinks in a row:")
                        ForEach(0..<3, id: \.self) { index in
                            Image(systemName: index < blink.pendingBlinks ? "circle.fill" : "circle")
                                .foregroundStyle(index < blink.pendingBlinks ? Color.accentColor : Color.secondary)
                        }
                    }
                    Text("Blinks counted: \(blink.blinksSeen)\(lastCommandText)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                } else {
                    HelpText("Blink actions work while HeadsUp is tracking.")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var faceText: String {
        switch blink.face {
        case .waitingForCamera: return "Waiting for the camera…"
        case .learning: return "Learning your open eyes. Look at the screen normally."
        case .tracked: return blink.eyesClosed ? "Eyes closed" : "Eyes open"
        case .noFace: return "No face in view"
        case .multipleFaces: return "More than one face in view: blinks are ignored"
        case .eyesNotFound: return "Eyes not visible (turned away, glare on glasses?)"
        }
    }

    private var lastCommandText: String {
        switch blink.lastCommand {
        case .select: return " · last: double blink → click"
        case .cancel: return " · last: triple blink → Escape"
        case nil: return ""
        }
    }
}
