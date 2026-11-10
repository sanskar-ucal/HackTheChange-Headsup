import HeadsUpKit
import SwiftUI

/// Settings, organized for quick tuning and fully operable with head pointer + nod.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let telemetry: LiveTelemetry
    let recorder: MotionRecorder
    let coordinator: AppCoordinator
    let permissions: PermissionsProviding

    var body: some View {
        Form {
            Section("Pointer") { PointerSettingsSection(settings: $store.settings) }
            Section("Movement") { MovementSettingsSection(settings: $store.settings) }
            Section("Gestures") { GestureSettingsSection(settings: $store.settings, coordinator: coordinator) }
            Section("Blink gestures") {
                BlinkSettingsSection(settings: $store.settings, coordinator: coordinator,
                                     telemetry: telemetry, permissions: permissions)
            }
            Section("Scrolling") { ScrollSettingsSection(settings: $store.settings) }
            Section("Voice input") { VoiceSettingsSection(settings: $store.settings) }
            Section("Sound") {
                SoundSettingsSection(settings: $store.settings, testSound: { coordinator.playTestSound() })
            }
            Section("Advanced") {
                AdvancedSettingsSection(settings: $store.settings, telemetry: telemetry, recorder: recorder)
            }
            Section {
                Button(role: .destructive) { store.resetToDefaults() } label: {
                    Text("Reset to defaults").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                HelpText("Restores every setting above. Your calibration is kept.")
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 640)
    }
}

/// Sensitivity, smoothing, dead zone and display span.
struct MovementSettingsSection: View {
    @Binding var settings: HeadsUpSettings

    private var smoothing: Binding<Double> {
        Binding(
            get: { min(max(log10(2 / max(settings.filterMinCutoff, 0.01)), 0), 1) },
            set: { settings.filterMinCutoff = 2 * pow(10, -$0) })
    }

    var body: some View {
        SliderRow(title: "Sensitivity", help: "How far the pointer travels per head turn. Applies instantly.",
                  value: $settings.sensitivity, range: 0.25...1.5, step: 0.05, format: "%.2f",
                  minLabel: "Calmer", maxLabel: "Faster")
        SliderRow(title: "Smoothing", help: "Higher is steadier but slightly slower to follow.",
                  value: smoothing, range: 0...1, step: 0.05, format: "%.0f%%", scale: 100,
                  minLabel: "Snappy", maxLabel: "Smooth")
        SliderRow(title: "Dead zone", help: "The pointer doesn't move for changes smaller than this.",
                  value: $settings.pointerDeadZonePoints, range: 0...10, step: 0.5, format: "%.1f pt")
        BigToggle(title: "Span all displays", help: "Map head movement across every screen instead of the main one.",
                  isOn: $settings.spanAllDisplays)
    }
}

/// Nod, shake and tilt thresholds, plus recalibration.
struct GestureSettingsSection: View {
    @Binding var settings: HeadsUpSettings
    let coordinator: AppCoordinator

    var body: some View {
        SliderRow(title: "Nod/shake speed", help: "How fast a head movement must start to count as a gesture.",
                  value: $settings.gestureOnsetRateDegPerSec, range: 20...150, step: 5, format: "%.0f°/s")
        SliderRow(title: "Nod size", help: "Smallest up-down movement that counts as a nod.",
                  value: $settings.nodMinAmplitudeDegrees, range: 2...25, step: 0.5, format: "%.1f°")
        SliderRow(title: "Shake size", help: "Smallest side-to-side swing that counts as a shake.",
                  value: $settings.shakeMinAmplitudeDegrees, range: 2...30, step: 0.5, format: "%.1f°")
        SliderRow(title: "Cooldown", help: "Pause after a gesture before another can trigger.",
                  value: $settings.gestureCooldown, range: 0...2, step: 0.05, format: "%.2f s")
        SliderRow(title: "Hold after click", help: "The pointer stays still this long after a nod click, like a mouse.",
                  value: $settings.holdAfterClick, range: 0...1.5, step: 0.05, format: "%.2f s")
        BigToggle(title: "Double nod for scroll mode",
                  help: "Off makes single-nod clicks instant (no wait for a second nod).",
                  isOn: $settings.doubleNodEnabled)
        SliderRow(title: "Tilt angle", help: "Head tilt needed for pause (left) and recenter (right).",
                  value: $settings.tiltThresholdDegrees, range: 8...40, step: 1, format: "%.0f°")
        SliderRow(title: "Tilt hold time", help: "How long to hold the tilt.",
                  value: $settings.tiltHoldDuration, range: 0.5...4, step: 0.1, format: "%.1f s")
        BigToggle(title: "Practice after calibration", help: "Three nod targets that suggest a sensitivity.",
                  isOn: $settings.practiceEnabled)
        Button { coordinator.recalibrate() } label: {
            Text("Recalibrate now").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }
}

/// Edge-push scrolling speed, direction and distance.
struct ScrollSettingsSection: View {
    @Binding var settings: HeadsUpSettings

    var body: some View {
        SliderRow(title: "Scroll speed", help: "Speed of edge-push and scroll-mode scrolling.",
                  value: $settings.scrollSpeed, range: 0.2...3, step: 0.1, format: "%.1f×",
                  minLabel: "Slower", maxLabel: "Faster")
        BigToggle(title: "Edge-push scrolling", help: "Keep looking past the top or bottom edge to scroll.",
                  isOn: $settings.edgeScrollEnabled)
        BigToggle(title: "Horizontal edge scrolling", help: "Also scroll sideways past the left and right edges.",
                  isOn: $settings.horizontalEdgeScroll)
        BigToggle(title: "Natural scrolling direction", help: "Looking up shows what's above. Turn off to invert.",
                  isOn: $settings.naturalScrolling)
        SliderRow(title: "Edge push distance", help: "How far past the edge to look before scrolling starts.",
                  value: $settings.scrollEngageOvershootDegrees, range: 1...10, step: 0.5, format: "%.1f°")
    }
}
