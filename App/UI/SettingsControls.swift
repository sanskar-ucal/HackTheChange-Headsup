import SwiftUI

/// Slider with −/+ buttons, value readout and help text; every target is at least 44 pt.
struct SliderRow: View {
    let title: String
    let help: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    var scale: Double = 1
    var minLabel: String?
    var maxLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value * scale))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                StepButton(symbol: "minus", label: "Decrease \(title)") { nudge(-step) }
                VStack(spacing: 0) {
                    Slider(value: $value, in: range, step: step)
                        .accessibilityLabel(title)
                    if minLabel != nil || maxLabel != nil {
                        HStack {
                            Text(minLabel ?? "")
                            Spacer()
                            Text(maxLabel ?? "")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
                StepButton(symbol: "plus", label: "Increase \(title)") { nudge(step) }
            }
            HelpText(help)
        }
        .padding(.vertical, 2)
    }

    private func nudge(_ delta: Double) {
        value = min(max(value + delta, range.lowerBound), range.upperBound)
    }
}

/// A 44 pt −/+ button for nudging a slider.
struct StepButton: View {
    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(label)
    }
}

/// A full-width checkbox row: the whole 44 pt row is the hit target.
struct BigToggle: View {
    let title: String
    let help: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    HelpText(help)
                }
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// A large segmented picker with help text.
struct ChoiceRow<Value: Hashable, Label: View>: View {
    let title: String
    let help: String
    @Binding var selection: Value
    let options: [Value]
    @ViewBuilder let label: (Value) -> Label

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { label($0).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .frame(minHeight: 44)
            HelpText(help)
        }
    }
}

/// One line of secondary help text under a control.
struct HelpText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
