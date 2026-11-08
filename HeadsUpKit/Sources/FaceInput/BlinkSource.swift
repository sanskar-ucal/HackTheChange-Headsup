import Foundation

/// What the camera saw in one analyzed frame. Only eye openness leaves the camera adapter:
/// no images, face geometry or identity.
public enum EyeReading: Sendable, Equatable {
    /// One (dominant) face with both eyes found. `openness` is the larger of the two eyes'
    /// height-to-width ratios, so both eyes must close to register a blink.
    case eyes(openness: Double)
    case noFace
    /// Several similar-sized faces: ignored so a bystander can't trigger actions.
    case multipleFaces
    /// A face without usable eye landmarks (turned away, occluded, glare on glasses).
    case eyesNotFound
}

public struct EyeObservation: Sendable, Equatable {
    /// Monotonic seconds (host time), one timebase per source.
    public var timestamp: TimeInterval
    public var reading: EyeReading

    public init(timestamp: TimeInterval, reading: EyeReading) {
        self.timestamp = timestamp
        self.reading = reading
    }
}

/// State of the camera used for blink gestures.
public enum CameraStatus: Sendable, Equatable {
    /// Blink gestures are off; the camera is not used.
    case off
    /// Blink gestures are on; the camera starts once HeadsUp is tracking (not while paused).
    case standby
    case requestingAccess
    case denied
    case restricted
    case noCamera
    case starting
    case running
    /// The capture session stopped with an error.
    case failed

    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .standby: return "Starts when HeadsUp is tracking"
        case .requestingAccess: return "Waiting for camera permission"
        case .denied: return "Camera access denied"
        case .restricted: return "Camera access restricted"
        case .noCamera: return "No camera found"
        case .starting: return "Starting camera"
        case .running: return "Camera on"
        case .failed: return "Camera stopped with an error"
        }
    }

    public var isProblem: Bool {
        switch self {
        case .denied, .restricted, .noCamera, .failed: return true
        case .off, .standby, .requestingAccess, .starting, .running: return false
        }
    }
}

public enum BlinkSourceEvent: Sendable, Equatable {
    case status(CameraStatus)
    case observation(EyeObservation)
}

/// A camera-based eye tracker for blink gestures. All processing stays on the Mac.
@MainActor
public protocol BlinkSource: AnyObject {
    /// Camera permission, without prompting.
    var authorization: AuthorizationState { get }
    /// Shows the system camera prompt if access is undecided.
    func requestAccess(_ completion: @escaping @MainActor @Sendable (Bool) -> Void)
    /// Starts capture (prompting if undecided). Events arrive on the main actor, in order,
    /// until `stop()`.
    func start(onEvent: @escaping @MainActor @Sendable (BlinkSourceEvent) -> Void)
    func stop()
}

public enum DominantFace {
    /// The face that belongs to the person at the Mac: the only one, or one clearly larger
    /// (closer) than every other. nil if there is no face or no clear winner.
    public static func index(ofAreas areas: [Double], minimumRatio: Double = 2) -> Int? {
        guard let largest = areas.indices.max(by: { areas[$0] < areas[$1] }) else { return nil }
        let others = areas.indices.filter { $0 != largest }.map { areas[$0] }
        guard let runnerUp = others.max() else { return largest }
        return areas[largest] >= runnerUp * minimumRatio ? largest : nil
    }
}
