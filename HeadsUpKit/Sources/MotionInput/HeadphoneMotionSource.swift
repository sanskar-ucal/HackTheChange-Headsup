import CoreMotion
import Foundation
import OSLog

/// Live head poses from AirPods (or Beats) with dynamic head tracking via `CMHeadphoneMotionManager`.
public final class HeadphoneMotionSource: NSObject, MotionSource, CMHeadphoneMotionManagerDelegate, @unchecked Sendable {
    public let poses: AsyncStream<HeadPose>
    public let connectionChanges: AsyncStream<HeadphoneConnection>

    private let poseContinuation: AsyncStream<HeadPose>.Continuation
    private let connectionContinuation: AsyncStream<HeadphoneConnection>.Continuation
    private let manager = CMHeadphoneMotionManager()
    private let queue: OperationQueue
    private var isRunning = false
    private static let log = Logger(subsystem: "com.hackthechange.HeadsUp", category: "motion")

    public override init() {
        let poseStream = AsyncStream.makeStream(of: HeadPose.self, bufferingPolicy: .bufferingNewest(8))
        poses = poseStream.stream
        poseContinuation = poseStream.continuation
        let connectionStream = AsyncStream.makeStream(of: HeadphoneConnection.self, bufferingPolicy: .bufferingNewest(4))
        connectionChanges = connectionStream.stream
        connectionContinuation = connectionStream.continuation
        let motionQueue = OperationQueue()
        motionQueue.name = "HeadsUp.motion"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive
        queue = motionQueue
        super.init()
        manager.delegate = self
    }

    public var isMotionAvailable: Bool { manager.isDeviceMotionAvailable }

    public func start() {
        guard !isRunning else { return }
        guard manager.isDeviceMotionAvailable else {
            Self.log.error("Headphone device motion is not available on this Mac")
            return
        }
        isRunning = true
        let continuation = poseContinuation
        manager.startDeviceMotionUpdates(to: queue) { motion, error in
            if let error {
                Self.log.error("Motion update error: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard let motion else { return }
            continuation.yield(HeadPose(motion: motion))
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
    }

    // MARK: CMHeadphoneMotionManagerDelegate

    public func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
        Self.log.info("Headphones connected")
        connectionContinuation.yield(.connected)
    }

    public func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
        Self.log.info("Headphones disconnected")
        connectionContinuation.yield(.disconnected)
    }
}

extension HeadPose {
    init(motion: CMDeviceMotion) {
        let attitude = motion.attitude
        let rate = motion.rotationRate
        let q = attitude.quaternion
        self.init(
            timestamp: motion.timestamp,
            yaw: AngleMath.wrap(-attitude.yaw),
            pitch: attitude.pitch,
            roll: attitude.roll,
            rotationRate: RotationRate(pitch: rate.x, yaw: -rate.z, roll: rate.y),
            quaternion: Quaternion(x: q.x, y: q.y, z: q.z, w: q.w)
        )
    }
}
