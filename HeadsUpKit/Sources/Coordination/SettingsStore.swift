import Combine
import Foundation

/// Observable, persisted settings for the UI.
@MainActor
public final class SettingsStore: ObservableObject {
    @Published public var settings: HeadsUpSettings {
        didSet { if settings != oldValue { persistence.save(settings) } }
    }

    private let persistence: SettingsPersistence

    public init(persistence: SettingsPersistence = SettingsPersistence()) {
        self.persistence = persistence
        settings = persistence.load()
    }

    public func resetToDefaults() {
        settings = .defaults
    }
}
