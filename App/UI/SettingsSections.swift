import HeadsUpKit
import SwiftUI

struct PointerSettingsSection: View {
    @Binding var settings: HeadsUpSettings

    private var color: Binding<Color> {
        Binding(get: { settings.resolvedPointerColor.color },
                set: { settings.pointerColor = RGBAColor($0) })
    }

    var body: some View {
        HStack(spacing: 16) {
            ForEach(PointerStyleKind.allCases, id: \.self) { kind in
                Button { settings.pointerStyle = kind } label: {
                    VStack(spacing: 6) {
                        PointerGlyphView(shape: kind.style.shape(for: .idle),
                                         color: (settings.pointerStyle == kind ? settings.resolvedPointerColor
                                                 : kind.defaultColor).color,
                                         size: 40, highContrast: settings.pointerHighContrast)
                        Text(kind.displayName).font(.caption)
                    }
                    .frame(minWidth: 64, minHeight: 72)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8)
                        .stroke(settings.pointerStyle == kind ? Color.accentColor : Color.clear, lineWidth: 3))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pointer style \(kind.displayName)")
                .accessibilityAddTraits(settings.pointerStyle == kind ? .isSelected : [])
            }
        }
        HelpText("Green circle is the default. Hand changes shape with context: open, tapping, scrolling, listening.")

        HStack(spacing: 10) {
            ForEach(RGBAColor.presets, id: \.self) { preset in
                Button { settings.pointerColor = preset } label: {
                    Circle().fill(preset.color)
                        .overlay(Circle().stroke(Color.primary.opacity(0.5), lineWidth: 1))
                        .frame(width: 36, height: 36)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pointer color \(preset.presetName ?? "custom")")
                .accessibilityAddTraits(settings.pointerColor == preset ? .isSelected : [])
            }
            ColorPicker("Custom", selection: color, supportsOpacity: false)
            Button("Default") { settings.pointerColor = nil }
                .frame(minHeight: 44)
                .accessibilityLabel("Default pointer color")
                .accessibilityAddTraits(settings.pointerColor == nil ? .isSelected : [])
        }
        HelpText("Pointer color. Default: green circle, white hand.")

        ChoiceRow(title: "Size", help: "Pointer size on screen.", selection: $settings.pointerSize,
                  options: PointerSize.allCases) { Text($0.label) }
        SliderRow(title: "Opacity", help: "Lower lets you see what's under the pointer.",
                  value: $settings.pointerOpacity, range: 0.3...1, step: 0.05, format: "%.0f%%", scale: 100)
        BigToggle(title: "High-contrast outline", help: "Dark outline so the pointer shows on light backgrounds.",
                  isOn: $settings.pointerHighContrast)
        BigToggle(title: "Hide system pointer (experimental)",
                  help: "macOS may only hide it while HeadsUp is frontmost. Off keeps the arrow under the fingertip.",
                  isOn: $settings.hideSystemCursor)
    }
}

struct VoiceSettingsSection: View {
    @Binding var settings: HeadsUpSettings

    var body: some View {
        ChoiceRow(title: "Start voice input in", help: "After a nod-click lands in such a field, HeadsUp listens.",
                  selection: $settings.voiceInputTrigger, options: VoiceInputTrigger.allCases) { Text($0.displayName) }
        BigToggle(title: "Use Mac's built-in microphone",
                  help: "Keeps AirPods in high-quality audio; their mic switches Bluetooth to call quality.",
                  isOn: $settings.useBuiltInMicrophone)
        SliderRow(title: "Stop after silence", help: "Listening ends after this long without speech (or nod).",
                  value: $settings.voiceSilenceTimeout, range: 0.8...4, step: 0.1, format: "%.1f s")
        SliderRow(title: "Review time", help: "After inserting: nod submits, shake undoes, waiting keeps the text.",
                  value: $settings.voiceReviewTimeout, range: 2...10, step: 0.5, format: "%.1f s")
        HelpText("Password fields never start listening.")
    }
}

struct SoundSettingsSection: View {
    @Binding var settings: HeadsUpSettings

    var body: some View {
        SliderRow(title: "Cue volume", help: "Volume of the confirmation sounds in your AirPods.",
                  value: $settings.feedbackVolume, range: 0...1, step: 0.05, format: "%.0f%%", scale: 100)
        BigToggle(title: "Mute cues", help: "Turn off all confirmation sounds.", isOn: $settings.feedbackMuted)
        BigToggle(title: "Spoken prompts", help: "Speak calibration steps and state changes.",
                  isOn: $settings.speechEnabled)
    }
}

struct AdvancedSettingsSection: View {
    @Binding var settings: HeadsUpSettings
    let telemetry: LiveTelemetry
    let recorder: MotionRecorder

    var body: some View {
        SliderRow(title: "Filter beta", help: "How much fast movement reduces smoothing lag.",
                  value: $settings.filterBeta, range: 0...0.05, step: 0.001, format: "%.3f")
        SliderRow(title: "Pointer spring", help: "Higher follows the head faster between sensor updates.",
                  value: $settings.pointerSpringStiffness, range: 1000...30000, step: 500, format: "%.0f")
        BigToggle(title: "Invert yaw (left/right)", help: "Use if the pointer moves the wrong way sideways.",
                  isOn: $settings.invertYaw)
        BigToggle(title: "Invert pitch (up/down)", help: "Use if the pointer moves the wrong way vertically.",
                  isOn: $settings.invertPitch)
        BigToggle(title: "Invert roll (tilt)", help: "Use if tilt left and tilt right are swapped.",
                  isOn: $settings.invertRoll)
        LiveReadoutView(telemetry: telemetry)
        RecorderControls(recorder: recorder)
    }
}

struct RecorderControls: View {
    @ObservedObject var recorder: MotionRecorder

    var body: some View {
        HStack {
            Button(recorder.isRecording ? "Stop recording" : "Record motion to CSV") {
                if recorder.isRecording { recorder.stop() } else { recorder.start() }
            }
            .frame(minHeight: 44)
            if recorder.isRecording {
                Text("\(recorder.sampleCount) samples").monospacedDigit().foregroundStyle(.secondary)
            }
            Spacer()
            if let url = recorder.lastSavedURL {
                Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            }
        }
        HelpText("Records head motion for tuning; replay with HEADSUP_REPLAY.")
    }
}
