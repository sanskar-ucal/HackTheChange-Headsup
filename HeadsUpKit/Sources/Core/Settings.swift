import Foundation

/// Every tunable number in HeadsUp. Angles are in degrees and durations in seconds here
/// (human-friendly for the Settings UI); components convert to radians internally.
public struct Settings: Codable, Equatable, Sendable {
    // MARK: Pointing
    /// >1 means less head movement is needed to reach the screen edges.
    public var sensitivity: Double = 1.0
    public var deadZoneDegrees: Double = 0.3
    public var maxEventRateHz: Double = 60
    /// false = map to the main display only; true = map to the union of all displays.
    public var spanAllDisplays: Bool = false
    /// How long the cursor glides back to the head position after a freeze ends.
    public var resumeBlendDuration: Double = 0.15

    // MARK: Smoothing (One Euro filter)
    public var filterMinCutoff: Double = 1.0
    public var filterBeta: Double = 0.01
    public var filterDCutoff: Double = 1.0

    // MARK: Axis conventions (flip if the hardware reports the opposite sign)
    public var invertYaw: Bool = false
    public var invertPitch: Bool = false
    public var invertRoll: Bool = false

    // MARK: Nod / shake
    public var gestureOnsetRateDegPerSec: Double = 60
    public var gestureCrossAxisMaxDegPerSec: Double = 45
    public var nodWindow: Double = 0.7
    public var nodMinAmplitudeDegrees: Double = 8
    public var shakeWindow: Double = 0.9
    public var shakeMinAmplitudeDegrees: Double = 10
    public var shakeMinDirectionChanges: Int = 2
    public var gestureCooldown: Double = 0.6
    /// The rollback point is taken this long before the gesture onset.
    public var gestureOnsetLookback: Double = 0.1
    public var cursorHistoryDuration: Double = 0.6

    // MARK: Tilt-hold
    public var tiltThresholdDegrees: Double = 20
    public var tiltHoldDuration: Double = 1.5
    /// After a hold fires, roll must return below threshold × this fraction to re-arm.
    public var tiltReleaseFraction: Double = 0.5

    // MARK: Calibration & recentering
    public var calibrationDwellDuration: Double = 1.5
    public var calibrationDwellToleranceDegrees: Double = 2.0
    /// The head must move at least this far from the previous target before a dwell counts.
    public var calibrationMinMoveDegrees: Double = 4.0
    public var calibrationMinRangeDegrees: Double = 5.0
    /// Normalized inset of the corner targets from the screen edges.
    public var calibrationTargetInset: Double = 0.05
    public var autoRecenterStillDuration: Double = 2.0
    public var autoRecenterToleranceDegrees: Double = 1.5

    // MARK: Feedback
    public var feedbackVolume: Double = 0.6
    public var feedbackMuted: Bool = false
    public var speechEnabled: Bool = true

    // MARK: Diagnostics & housekeeping
    public var telemetryRateHz: Double = 10
    public var permissionPollInterval: Double = 1.0
    public var diagnosticsInterval: Double = 1.0

    public init() {}

    public static let defaults = Settings()
}

// MARK: - Persistence

/// Reads and writes `Settings` as JSON in `UserDefaults`.
///
/// Stored values are merged over the defaults, so adding a new setting in a later version
/// keeps the user's other values instead of resetting everything.
public struct SettingsPersistence {
    public static let defaultKey = "HeadsUp.settings.v1"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = SettingsPersistence.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Settings {
        guard let data = defaults.data(forKey: key) else { return .defaults }
        return Self.decodeMerged(data) ?? .defaults
    }

    public func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    static func decodeMerged(_ data: Data) -> Settings? {
        guard
            let defaultsData = try? JSONEncoder().encode(Settings.defaults),
            var base = try? JSONSerialization.jsonObject(with: defaultsData) as? [String: Any],
            let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        base.merge(stored) { _, storedValue in storedValue }
        guard let merged = try? JSONSerialization.data(withJSONObject: base) else { return nil }
        return try? JSONDecoder().decode(Settings.self, from: merged)
    }
}
