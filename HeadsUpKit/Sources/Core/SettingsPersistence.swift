import Foundation

/// Reads and writes `Settings` as JSON in `UserDefaults`.
///
/// Stored values are merged over the defaults, so adding a new setting in a later version
/// keeps the user's other values instead of resetting everything. v2 uses a new key so
/// v1 users get the calmer v2 pointing defaults.
public struct SettingsPersistence {
    public static let defaultKey = "HeadsUp.settings.v2"

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
