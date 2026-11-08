import CoreGraphics
import Foundation

/// Per-frame eye measurements from face landmarks.
public struct EyeSample: Sendable, Equatable {
    public var leftEAR: Double
    public var rightEAR: Double
    public var confidence: Double
    public var faceYawDegrees: Double
    /// Face width as a fraction of the frame width.
    public var faceSize: Double

    public init(leftEAR: Double, rightEAR: Double, confidence: Double = 1, faceYawDegrees: Double = 0,
                faceSize: Double = 0.3) {
        self.leftEAR = leftEAR
        self.rightEAR = rightEAR
        self.confidence = confidence
        self.faceYawDegrees = faceYawDegrees
        self.faceSize = faceSize
    }
}

/// One processed camera frame; the pixels themselves are never kept.
public struct FaceFrame: Sendable, Equatable {
    /// Seconds on the `CACurrentMediaTime` timebase.
    public var timestamp: TimeInterval
    /// Mean luma, 0…1.
    public var brightness: Double
    /// nil when no face was found.
    public var eyes: EyeSample?

    public init(timestamp: TimeInterval, brightness: Double, eyes: EyeSample?) {
        self.timestamp = timestamp
        self.brightness = brightness
        self.eyes = eyes
    }
}

/// Eye Aspect Ratio: eye opening height over eye width, from any eye contour.
public enum EyeAspectRatio {
    /// The two farthest-apart points are the eye corners; height is the contour's spread perpendicular to that line.
    public static func compute(_ points: [CGPoint]) -> Double {
        guard points.count >= 4 else { return 0 }
        var a = points[0]
        var b = points[1]
        var best: CGFloat = -1
        for i in points.indices {
            for j in points.indices where j > i {
                let dx = points[j].x - points[i].x
                let dy = points[j].y - points[i].y
                let d = dx * dx + dy * dy
                if d > best {
                    best = d
                    a = points[i]
                    b = points[j]
                }
            }
        }
        let width = best.squareRoot()
        guard width > 0 else { return 0 }
        let ux = (b.x - a.x) / width
        let uy = (b.y - a.y) / width
        var low: CGFloat = 0
        var high: CGFloat = 0
        for p in points {
            let side = (p.x - a.x) * -uy + (p.y - a.y) * ux
            low = min(low, side)
            high = max(high, side)
        }
        return Double((high - low) / width)
    }
}

/// Lifecycle of the camera as shown in Settings.
public enum CameraState: Sendable, Equatable {
    case off
    case starting
    case running
    case failed(String)

    public var displayName: String {
        switch self {
        case .off: return "Camera off"
        case .starting: return "Starting camera…"
        case .running: return "Camera on"
        case .failed(let message): return message
        }
    }
}

/// Delivers face frames on the main actor while running.
@MainActor
public protocol FaceSampleSource: AnyObject {
    var onFrame: (@MainActor (FaceFrame) -> Void)? { get set }
    var onFailure: (@MainActor (String) -> Void)? { get set }
    var onRunning: (@MainActor () -> Void)? { get set }
    var isRunning: Bool { get }
    func start()
    func stop()
}

/// A source that never produces frames (tests, or builds without a camera).
@MainActor
public final class DisabledFaceSource: FaceSampleSource {
    public var onFrame: (@MainActor (FaceFrame) -> Void)?
    public var onFailure: (@MainActor (String) -> Void)?
    public var onRunning: (@MainActor () -> Void)?
    public private(set) var isRunning = false

    public init() {}

    public func start() { isRunning = true }
    public func stop() { isRunning = false }
}
