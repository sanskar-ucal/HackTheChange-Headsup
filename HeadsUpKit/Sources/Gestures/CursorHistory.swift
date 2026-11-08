import CoreGraphics
import Foundation

/// Bounded buffer of recent cursor positions, used to roll the cursor back to where it was when a nod or shake began.
public struct CursorHistory: Sendable {
    public struct Entry: Sendable, Equatable {
        public var time: TimeInterval
        public var point: CGPoint
    }

    public var duration: TimeInterval
    public private(set) var entries: [Entry] = []

    public init(duration: TimeInterval) {
        self.duration = duration
    }

    public mutating func append(_ point: CGPoint, at time: TimeInterval) {
        entries.append(Entry(time: time, point: point))
        let cutoff = time - duration
        if let firstKept = entries.firstIndex(where: { $0.time >= cutoff }), firstKept > 0 {
            entries.removeFirst(firstKept)
        }
    }

    public mutating func removeAll() {
        entries.removeAll()
    }

    /// The most recent position recorded at or before `time`; the oldest position if `time` predates the buffer.
    public func point(at time: TimeInterval) -> CGPoint? {
        if let entry = entries.last(where: { $0.time <= time }) { return entry.point }
        return entries.first?.point
    }
}
