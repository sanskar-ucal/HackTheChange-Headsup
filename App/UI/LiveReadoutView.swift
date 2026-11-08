import HeadsUpKit
import SwiftUI

/// Live pose and sample-rate readout for tuning, including the background-delivery check.
struct LiveReadoutView: View {
    @ObservedObject var telemetry: LiveTelemetry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let pose = telemetry.pose {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                    GridRow {
                        Text("")
                        Text("Angle").foregroundStyle(.secondary)
                        Text("Rate").foregroundStyle(.secondary)
                    }
                    row("Yaw", angle: pose.yaw, rate: pose.rotationRate.yaw)
                    row("Pitch", angle: pose.pitch, rate: pose.rotationRate.pitch)
                    row("Roll", angle: pose.roll, rate: pose.rotationRate.roll)
                }
                .monospacedDigit()
            } else {
                Text("No motion yet. Put on your AirPods.").foregroundStyle(.secondary)
            }

            Text(String(format: "Samples: %.0f/s %@", telemetry.samplesPerSecond,
                        telemetry.isAppActive ? "(HeadsUp frontmost)" : "(in background)"))
                .monospacedDigit()
            if let latency = telemetry.pointerLatencyMs {
                Text(String(format: "Sample → cursor: %.1f ms", latency))
                    .monospacedDigit()
                    .foregroundStyle(latency <= 30 ? Color.secondary : Color.orange)
            }
            Text(backgroundText)
                .font(.caption)
                .foregroundStyle(backgroundOK ? Color.secondary : Color.orange)
            if !telemetry.gestureLog.isEmpty {
                Text("Gesture log (newest last)").font(.caption.weight(.semibold))
                ForEach(Array(telemetry.gestureLog.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .foregroundStyle(line.contains("confirmed") ? Color.primary : Color.orange)
                }
            }
        }
    }

    private var backgroundOK: Bool {
        (telemetry.backgroundSamplesPerSecond ?? 0) >= 10
    }

    private var backgroundText: String {
        guard let rate = telemetry.backgroundSamplesPerSecond else {
            return "Background check: switch to another app for a few seconds, then come back."
        }
        let verdict = backgroundOK ? "motion keeps arriving in the background" : "motion is throttled in the background"
        return String(format: "Background check: %.0f samples/s, %@.", rate, verdict)
    }

    private func row(_ name: String, angle: Double, rate: Double) -> some View {
        GridRow {
            Text(name)
            Text(String(format: "%+7.1f°", AngleMath.degrees(angle)))
            Text(String(format: "%+7.0f°/s", AngleMath.degrees(rate)))
        }
    }
}
