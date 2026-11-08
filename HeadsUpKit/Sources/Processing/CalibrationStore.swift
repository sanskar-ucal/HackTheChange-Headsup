import Foundation

/// Persists the per-user calibration.
@MainActor
public protocol CalibrationStoring: AnyObject {
    func load() -> Calibration?
    func save(_ calibration: Calibration)
    func clear()
}

@MainActor
public final class UserDefaultsCalibrationStore: CalibrationStoring {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "HeadsUp.calibration.v1") {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> Calibration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Calibration.self, from: data)
    }

    public func save(_ calibration: Calibration) {
        guard let data = try? JSONEncoder().encode(calibration) else { return }
        defaults.set(data, forKey: key)
    }

    public func clear() {
        defaults.removeObject(forKey: key)
    }
}

/// Non-persistent store for tests and previews.
@MainActor
public final class InMemoryCalibrationStore: CalibrationStoring {
    public var calibration: Calibration?

    public init(calibration: Calibration? = nil) {
        self.calibration = calibration
    }

    public func load() -> Calibration? { calibration }
    public func save(_ calibration: Calibration) { self.calibration = calibration }
    public func clear() { calibration = nil }
}
