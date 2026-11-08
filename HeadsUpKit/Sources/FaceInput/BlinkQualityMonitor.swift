import Combine
import Foundation

/// Whether the camera view is good enough to trust blinks.
public enum BlinkQuality: String, Sendable, Equatable {
    case ok
    case noFace
    case lowLight
    case faceTurned
    case tooFar

    public var displayName: String {
        switch self {
        case .ok: return "OK"
        case .noFace: return "No face"
        case .lowLight: return "Low light"
        case .faceTurned: return "Face turned"
        case .tooFar: return "Too far"
        }
    }
}

/// Decides whether a frame is good enough to judge blinks; anything but `.ok` suspends them.
public struct BlinkQualityMonitor: Sendable, Equatable {
    public var minConfidence = 0.5
    public var minBrightness = 0.12
    public var maxYawDegrees = 30.0
    public var minFaceSize = 0.12

    public init() {}

    public init(settings: HeadsUpSettings) {
        minConfidence = settings.blinkMinConfidence
        minBrightness = settings.blinkMinBrightness
        maxYawDegrees = settings.blinkMaxFaceYawDegrees
        minFaceSize = settings.blinkMinFaceSize
    }

    public func assess(_ frame: FaceFrame) -> BlinkQuality {
        if frame.brightness < minBrightness { return .lowLight }
        guard let eyes = frame.eyes, eyes.confidence >= minConfidence else { return .noFace }
        if abs(eyes.faceYawDegrees) > maxYawDegrees { return .faceTurned }
        if eyes.faceSize < minFaceSize { return .tooFar }
        return .ok
    }
}

/// Live blink values for Settings, throttled so the UI doesn't redraw at camera rate.
@MainActor
public final class BlinkTelemetry: ObservableObject {
    @Published public internal(set) var camera: CameraState = .off
    @Published public internal(set) var quality: BlinkQuality = .noFace
    @Published public internal(set) var leftEAR = 0.0
    @Published public internal(set) var rightEAR = 0.0
    @Published public internal(set) var leftThreshold: Double?
    @Published public internal(set) var rightThreshold: Double?
    @Published public internal(set) var sequenceCount = 0
    @Published public internal(set) var lastAction: String?
    /// Camera frames analyzed per second.
    @Published public internal(set) var fps: Double = 0

    var lastPublish: TimeInterval = -.infinity

    public init() {}
}
