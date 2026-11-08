import CoreGraphics
import Foundation

/// An actionable on-screen element (button, link, field…). `frame` is in global top-left
/// coordinates.
public struct ClickTarget: Sendable, Equatable {
    public var frame: CGRect
    public var role: String

    public init(frame: CGRect, role: String) {
        self.frame = frame
        self.role = role
    }

    public var center: CGPoint { CGPoint(x: frame.midX, y: frame.midY) }
    public var area: Double { Double(frame.width * frame.height) }
}

/// Finds actionable elements near the pointer.
@MainActor
public protocol TargetProvider: AnyObject {
    /// Looks up targets around `point` (global coordinates). The completion may run
    /// synchronously (cache hit) or later; it is not called if a scan is already running.
    func requestTargets(near point: CGPoint, completion: @escaping @MainActor ([ClickTarget]) -> Void)
    func invalidate()
}

/// Short-lived cache of the last scan, valid while the pointer stays well inside the
/// scanned box, the frontmost app is unchanged, and nothing has invalidated it.
public struct TargetCache: Sendable {
    public var maxAge: TimeInterval

    private var box: CGRect?
    private var pid: Int32 = 0
    private var time: TimeInterval = 0
    private var targets: [ClickTarget] = []

    public init(maxAge: TimeInterval = 1.0) {
        self.maxAge = maxAge
    }

    public mutating func store(_ targets: [ClickTarget], box: CGRect, pid: Int32, time: TimeInterval) {
        self.targets = targets
        self.box = box
        self.pid = pid
        self.time = time
    }

    /// Cached targets if still valid for `point`; `margin` keeps a border so targets just
    /// outside the scanned box aren't missed.
    public func lookup(point: CGPoint, pid: Int32, time: TimeInterval, margin: CGFloat) -> [ClickTarget]? {
        guard let box, pid == self.pid, time - self.time <= maxAge,
              box.insetBy(dx: margin, dy: margin).contains(point) else { return nil }
        return targets
    }

    public mutating func invalidate() {
        box = nil
        targets = []
    }
}
