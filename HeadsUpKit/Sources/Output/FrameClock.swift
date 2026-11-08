import AppKit
import QuartzCore

/// Calls back once per display refresh so pointer motion is rendered at display rate,
/// independent of the 25–50 Hz sensor rate.
@MainActor
public protocol FrameClock: AnyObject {
    /// `timestamp` is on the `CACurrentMediaTime()` clock.
    func start(_ onFrame: @escaping @MainActor (_ timestamp: TimeInterval) -> Void)
    func stop()
}

/// `NSScreen.displayLink` (macOS 14 `CADisplayLink`). Falls back to a 60 Hz timer when no
/// screen is available. `CVDisplayLink` is deprecated on macOS 14 and not used.
@MainActor
public final class DisplayLinkFrameClock: NSObject, FrameClock {
    private var link: CADisplayLink?
    private var timer: Timer?
    private var handler: (@MainActor (TimeInterval) -> Void)?

    public override init() {
        super.init()
    }

    public func start(_ onFrame: @escaping @MainActor (TimeInterval) -> Void) {
        handler = onFrame
        guard link == nil, timer == nil else { return }
        if let screen = NSScreen.main {
            let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            self.link = link
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.handler?(CACurrentMediaTime()) }
            }
        }
    }

    public func stop() {
        link?.invalidate()
        link = nil
        timer?.invalidate()
        timer = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        handler?(link.timestamp)
    }
}
