import Foundation

/// Debug helper: records live poses to CSV so gestures and thresholds can be tuned offline
/// and recordings can be replayed with `ReplayMotionSource`.
@MainActor
public final class MotionRecorder: ObservableObject {
    @Published public private(set) var isRecording = false
    @Published public private(set) var sampleCount = 0
    @Published public private(set) var lastSavedURL: URL?

    private var samples: [HeadPose] = []
    private let directory: URL

    public init(directory: URL = MotionRecorder.defaultDirectory) {
        self.directory = directory
    }

    public nonisolated static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("HeadsUp/Recordings", isDirectory: true)
    }

    public func start() {
        samples.removeAll()
        sampleCount = 0
        isRecording = true
    }

    public func record(_ pose: HeadPose) {
        guard isRecording else { return }
        samples.append(pose)
        sampleCount = samples.count
    }

    /// Stops recording and writes the CSV. Returns the file URL, or nil if nothing was saved.
    @discardableResult
    public func stop() -> URL? {
        isRecording = false
        guard !samples.isEmpty else { return nil }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let url = directory.appendingPathComponent("headsup-\(formatter.string(from: Date())).csv")
            try PoseCSV.encode(samples).write(to: url, atomically: true, encoding: .utf8)
            lastSavedURL = url
            return url
        } catch {
            return nil
        }
    }
}
