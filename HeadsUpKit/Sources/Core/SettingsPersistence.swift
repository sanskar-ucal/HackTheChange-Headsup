import Foundation

/// Reads and writes `HeadsUpSettings` as JSON in `UserDefaults`.
public struct SettingsPersistence {
    public static let defaultKey = "HeadsUp.settings.v2"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = SettingsPersistence.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> HeadsUpSettings {
        guard let data = defaults.data(forKey: key) else { return .defaults }
        return Self.sanitized(Self.decodeMerged(data) ?? .defaults)
    }

    /// Resets stored values that would silently disable audio cues.
    static func sanitized(_ settings: HeadsUpSettings) -> HeadsUpSettings {
        var settings = settings
        let volume = settings.feedbackVolume
        if !volume.isFinite || volume <= 0 || volume > 1 {
            settings.feedbackVolume = HeadsUpSettings.defaults.feedbackVolume
        }
        return settings
    }

    public func save(_ settings: HeadsUpSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }

    static func decodeMerged(_ data: Data) -> HeadsUpSettings? {
        guard
            let defaultsData = try? JSONEncoder().encode(HeadsUpSettings.defaults),
            var base = try? JSONSerialization.jsonObject(with: defaultsData) as? [String: Any],
            let stored = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        base.merge(stored) { _, storedValue in storedValue }
        guard let merged = try? JSONSerialization.data(withJSONObject: base) else { return nil }
        return try? JSONDecoder().decode(HeadsUpSettings.self, from: merged)
    }
}
