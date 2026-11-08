import Foundation

/// Which focused text fields automatically start voice input after a HeadsUp click.
public enum VoiceInputTrigger: String, Codable, Sendable, CaseIterable {
    case searchFieldsOnly
    case allTextFields
    case off

    public var displayName: String {
        switch self {
        case .searchFieldsOnly: return "Search fields only"
        case .allTextFields: return "All text fields"
        case .off: return "Off"
        }
    }
}

/// The pointer overlay's visual style.
public enum PointerStyleKind: String, Codable, Sendable, CaseIterable {
    case hand
    case greenCircle
    case ring
    case dot
    case crosshair

    public var displayName: String {
        switch self {
        case .hand: return "Hand"
        case .greenCircle: return "Green circle"
        case .ring: return "Ring"
        case .dot: return "Dot"
        case .crosshair: return "Crosshair"
        }
    }

    /// Default color when the user hasn't picked one.
    public var defaultColor: RGBAColor {
        switch self {
        case .hand: return .white
        case .greenCircle: return .green
        case .ring, .dot, .crosshair: return .yellow
        }
    }
}

public enum PointerSize: String, Codable, Sendable, CaseIterable {
    case small, medium, large, extraLarge

    public var label: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .extraLarge: return "XL"
        }
    }

    /// Edge length of the pointer glyph in points.
    public var points: Double {
        switch self {
        case .small: return 32
        case .medium: return 44
        case .large: return 56
        case .extraLarge: return 72
        }
    }
}

/// A color that can live in `Settings` (Codable, no AppKit dependency). Components 0…1.
public struct RGBAColor: Codable, Sendable, Equatable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let white = RGBAColor(red: 1, green: 1, blue: 1)
    public static let black = RGBAColor(red: 0, green: 0, blue: 0)
    public static let green = RGBAColor(red: 0.2, green: 0.85, blue: 0.35)
    public static let yellow = RGBAColor(red: 1, green: 0.84, blue: 0.1)
    public static let blue = RGBAColor(red: 0.2, green: 0.55, blue: 1)
    public static let red = RGBAColor(red: 1, green: 0.3, blue: 0.3)
    public static let purple = RGBAColor(red: 0.7, green: 0.4, blue: 1)

    /// Swatches offered in Settings.
    public static let presets: [RGBAColor] = [.white, .black, .green, .yellow, .blue, .red, .purple]
}
