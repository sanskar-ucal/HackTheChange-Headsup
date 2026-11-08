import Foundation

/// Replays recorded or synthetic poses. Used by tests and for debugging without AirPods
/// (launch the app with `HEADSUP_REPLAY=/path/to/trace.csv`).
public final class ReplayMotionSource: MotionSource, @unchecked Sendable {
    // @unchecked: `task` is only touched from start()/stop() on the main actor.
    public let poses: AsyncStream<HeadPose>
    public let connectionChanges: AsyncStream<HeadphoneConnection>
    public let isMotionAvailable = true

    private let poseContinuation: AsyncStream<HeadPose>.Continuation
    private let connectionContinuation: AsyncStream<HeadphoneConnection>.Continuation
    private let trace: [HeadPose]
    private let realtime: Bool
    private let loops: Bool
    private var task: Task<Void, Never>?

    /// - Parameters:
    ///   - realtime: sleep between samples using their timestamps; otherwise emit at once.
    ///   - loops: restart from the beginning when the trace ends (timestamps keep increasing).
    public init(poses trace: [HeadPose], realtime: Bool = true, loops: Bool = false) {
        self.trace = trace
        self.realtime = realtime
        self.loops = loops
        let poseStream = AsyncStream.makeStream(of: HeadPose.self)
        poses = poseStream.stream
        poseContinuation = poseStream.continuation
        let connectionStream = AsyncStream.makeStream(of: HeadphoneConnection.self)
        connectionChanges = connectionStream.stream
        connectionContinuation = connectionStream.continuation
    }

    public convenience init(csvURL: URL, realtime: Bool = true, loops: Bool = false) throws {
        let text = try String(contentsOf: csvURL, encoding: .utf8)
        try self.init(poses: PoseCSV.decode(text), realtime: realtime, loops: loops)
    }

    public func start() {
        guard task == nil else { return }
        let trace = trace, realtime = realtime, loops = loops
        let poses = poseContinuation, connection = connectionContinuation
        task = Task.detached(priority: .userInitiated) {
            connection.yield(.connected)
            guard let first = trace.first, let last = trace.last else { return }
            let span = max(last.timestamp - first.timestamp, 0.04) + 0.04
            var offset: TimeInterval = 0
            repeat {
                var previous: TimeInterval?
                for var pose in trace {
                    if Task.isCancelled { return }
                    if realtime, let previous {
                        let delay = max(0, pose.timestamp - previous)
                        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    previous = pose.timestamp
                    pose.timestamp += offset
                    poses.yield(pose)
                }
                offset += span
            } while loops && !Task.isCancelled
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        connectionContinuation.yield(.disconnected)
    }
}

/// CSV codec for pose traces. Columns are radians and radians per second:
/// `timestamp,yaw,pitch,roll,pitchRate,yawRate,rollRate`.
public enum PoseCSV {
    public static let header = "timestamp,yaw,pitch,roll,pitchRate,yawRate,rollRate"

    public enum DecodeError: Error, Equatable {
        case malformedRow(line: Int)
    }

    public static func encode(_ poses: [HeadPose]) -> String {
        var lines = [header]
        lines.reserveCapacity(poses.count + 1)
        for p in poses {
            let values = [p.timestamp, p.yaw, p.pitch, p.roll,
                          p.rotationRate.pitch, p.rotationRate.yaw, p.rotationRate.roll]
            lines.append(values.map { String(format: "%.6f", $0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    public static func decode(_ text: String) throws -> [HeadPose] {
        var poses: [HeadPose] = []
        for (index, rawLine) in text.split(whereSeparator: \.isNewline).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix("timestamp") { continue }
            let values = line.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard values.count == 7 else { throw DecodeError.malformedRow(line: index + 1) }
            poses.append(HeadPose(
                timestamp: values[0], yaw: values[1], pitch: values[2], roll: values[3],
                rotationRate: RotationRate(pitch: values[4], yaw: values[5], roll: values[6])
            ))
        }
        return poses
    }
}
