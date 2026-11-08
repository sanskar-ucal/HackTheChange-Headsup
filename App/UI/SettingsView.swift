import HeadsUpKit
import SwiftUI

/// Tuning UI. Every value here comes from `Settings` and is saved immediately.
struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    let telemetry: LiveTelemetry
    let recorder: MotionRecorder
    let coordinator: AppCoordinator

    var body: some View {
        Form {
            Section("Pointing") {
                SliderRow("Sensitivity", value: $store.settings.sensitivity, in: 0.5...3, step: 0.05, format: "%.2f×")
                SliderRow("Dead zone", value: $store.settings.deadZoneDegrees, in: 0...2, step: 0.05, format: "%.2f°")
                SliderRow("Max event rate", value: $store.settings.maxEventRateHz, in: 15...120, step: 5, format: "%.0f Hz")
                Toggle("Span all displays", isOn: $store.settings.spanAllDisplays)
            }
            Section("Smoothing (One Euro filter)") {
                SliderRow("Min cutoff", value: $store.settings.filterMinCutoff, in: 0.1...5, step: 0.1, format: "%.1f Hz")
                SliderRow("Beta (speed response)", value: $store.settings.filterBeta, in: 0...0.1, step: 0.001, format: "%.3f")
                SliderRow("Derivative cutoff", value: $store.settings.filterDCutoff, in: 0.1...5, step: 0.1, format: "%.1f Hz")
            }
            Section("Nod & shake") {
                SliderRow("Onset speed", value: $store.settings.gestureOnsetRateDegPerSec, in: 20...150, step: 5, format: "%.0f°/s")
                SliderRow("Cross-axis limit", value: $store.settings.gestureCrossAxisMaxDegPerSec, in: 10...120, step: 5, format: "%.0f°/s")
                SliderRow("Nod minimum size", value: $store.settings.nodMinAmplitudeDegrees, in: 2...25, step: 0.5, format: "%.1f°")
                SliderRow("Nod time window", value: $store.settings.nodWindow, in: 0.3...1.5, step: 0.05, format: "%.2f s")
                SliderRow("Shake minimum swing", value: $store.settings.shakeMinAmplitudeDegrees, in: 2...30, step: 0.5, format: "%.1f°")
                SliderRow("Shake time window", value: $store.settings.shakeWindow, in: 0.4...2, step: 0.05, format: "%.2f s")
                SliderRow("Cooldown", value: $store.settings.gestureCooldown, in: 0...2, step: 0.05, format: "%.2f s")
            }
            Section("Tilt-hold (pause left, recenter right)") {
                SliderRow("Tilt angle", value: $store.settings.tiltThresholdDegrees, in: 8...40, step: 1, format: "%.0f°")
                SliderRow("Hold time", value: $store.settings.tiltHoldDuration, in: 0.5...4, step: 0.1, format: "%.1f s")
            }
            Section("Calibration") {
                SliderRow("Dwell time", value: $store.settings.calibrationDwellDuration, in: 0.5...4, step: 0.1, format: "%.1f s")
                SliderRow("Dwell tolerance", value: $store.settings.calibrationDwellToleranceDegrees, in: 0.5...5, step: 0.1, format: "%.1f°")
                SliderRow("Auto-recenter stillness", value: $store.settings.autoRecenterStillDuration, in: 1...6, step: 0.5, format: "%.1f s")
                Button("Recalibrate now") { coordinator.recalibrate() }
            }
            Section("Feedback") {
                SliderRow("Cue volume", value: $store.settings.feedbackVolume, in: 0...1, step: 0.05, format: "%.0f%%", scale: 100)
                Toggle("Mute cues", isOn: $store.settings.feedbackMuted)
                Toggle("Spoken prompts", isOn: $store.settings.speechEnabled)
            }
            Section("Axis directions (fix if movement is mirrored)") {
                Toggle("Invert yaw (left/right)", isOn: $store.settings.invertYaw)
                Toggle("Invert pitch (up/down)", isOn: $store.settings.invertPitch)
                Toggle("Invert roll (tilt)", isOn: $store.settings.invertRoll)
            }
            Section("Live readout") {
                LiveReadoutView(telemetry: telemetry)
            }
            Section("Debug") {
                RecorderControls(recorder: recorder)
                Button("Reset all settings to defaults", role: .destructive) { store.resetToDefaults() }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 600)
    }
}

/// A labelled slider with its current value.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let scale: Double

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
         format: String, scale: Double = 1) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.format = format
        self.scale = scale
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value * scale))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
                .accessibilityLabel(title)
        }
    }
}

struct RecorderControls: View {
    @ObservedObject var recorder: MotionRecorder

    var body: some View {
        HStack {
            Button(recorder.isRecording ? "Stop recording" : "Record motion to CSV") {
                if recorder.isRecording { recorder.stop() } else { recorder.start() }
            }
            if recorder.isRecording {
                Text("\(recorder.sampleCount) samples").monospacedDigit().foregroundStyle(.secondary)
            }
            Spacer()
            if let url = recorder.lastSavedURL {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        }
    }
}
