import HeadsUpKit
import SwiftUI

/// Settings for webcam blink controls, with live camera feedback.
struct BlinkSettingsSection: View {
    @Binding var settings: HeadsUpSettings
    @ObservedObject var telemetry: BlinkTelemetry
    let retry: () -> Void
    let openCameraSettings: () -> Void

    var body: some View {
        BigToggle(title: "Use blink controls",
                  help: "Double blink clicks, triple blink presses Escape. Uses the camera while tracking only.",
                  isOn: $settings.blinkEnabled)
        ChoiceRow(title: "Input for clicking", help: "Which gestures click and press Escape.",
                  selection: $settings.clickInput, options: ClickInput.allCases) { Text($0.displayName) }
        if settings.blinkEnabled {
            BlinkLiveView(telemetry: telemetry, retry: retry, openCameraSettings: openCameraSettings)
            SliderRow(title: "Sensitivity", help: "Higher counts lighter eye closures as blinks.",
                      value: $settings.blinkSensitivity, range: 0...1, step: 0.05, format: "%.0f%%", scale: 100,
                      minLabel: "Firm blinks", maxLabel: "Light blinks")
            SliderRow(title: "Max gap between blinks", help: "Blinks closer together than this form one sequence.",
                      value: $settings.blinkMaxGap, range: 0.25...0.9, step: 0.05, format: "%.2f s")
            SliderRow(title: "Shortest blink", help: "Shorter eye closures are ignored as noise.",
                      value: $settings.blinkMinDuration, range: 0.03...0.15, step: 0.01, format: "%.2f s")
            SliderRow(title: "Longest blink", help: "Longer closures (resting your eyes) never act.",
                      value: $settings.blinkMaxDuration, range: 0.2...0.8, step: 0.05, format: "%.2f s")
            SliderRow(title: "Cooldown", help: "Pause after a blink action before the next can start.",
                      value: $settings.blinkCooldown, range: 0.2...2, step: 0.05, format: "%.2f s")
            BigToggle(title: "Require both eyes", help: "Winks never count. Turn off only if one eye closes less.",
                      isOn: $settings.blinkRequireBothEyes)
        }
        HelpText("Camera frames are analyzed on this Mac and immediately discarded. No face recognition.")
    }
}

/// Status chip, per-eye EAR meters with the close threshold, sequence dots and last action.
struct BlinkLiveView: View {
    @ObservedObject var telemetry: BlinkTelemetry
    let retry: () -> Void
    let openCameraSettings: () -> Void

    private var statusText: String {
        if case .running = telemetry.camera { return telemetry.quality.displayName }
        return telemetry.camera.displayName
    }

    private var statusOK: Bool {
        if case .running = telemetry.camera { return telemetry.quality == .ok }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(statusText)
                    .font(.callout.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Capsule().fill(statusOK ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)))
                Spacer()
                if case .running = telemetry.camera {
                    Text(String(format: "%.0f fps", telemetry.fps))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
                SequenceDots(count: telemetry.sequenceCount)
            }
            switch telemetry.camera {
            case .failed:
                Button("Retry camera", action: retry).frame(minHeight: 44)
            case .denied:
                HelpText("HeadsUp needs camera access for blink controls.")
                Button("Open Camera Settings", action: openCameraSettings).frame(minHeight: 44)
            case .off, .starting, .running:
                EmptyView()
            }
            EARMeter(label: "Left eye", value: telemetry.leftEAR, threshold: telemetry.leftThreshold)
            EARMeter(label: "Right eye", value: telemetry.rightEAR, threshold: telemetry.rightThreshold)
            Text(telemetry.lastAction.map { "Last: \($0)" } ?? "No blink action yet")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }
}

/// Eye openness bar; the tick marks where the eye counts as closed.
struct EARMeter: View {
    let label: String
    let value: Double
    let threshold: Double?
    private let scale = 0.45

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).frame(width: 64, alignment: .leading)
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(Color.accentColor)
                        .frame(width: width * min(value / scale, 1))
                    if let threshold {
                        Rectangle().fill(Color.primary)
                            .frame(width: 2, height: 14)
                            .offset(x: width * min(threshold / scale, 1) - 1)
                    }
                }
            }
            .frame(height: 10)
            Text(String(format: "%.2f", value)).font(.caption.monospacedDigit()).frame(width: 36)
        }
    }
}

/// Up to three dots showing how many blinks the current sequence has counted.
struct SequenceDots: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index < count ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("\(count) blinks counted")
    }
}
