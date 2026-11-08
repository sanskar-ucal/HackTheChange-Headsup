import CoreGraphics
import Foundation

/// Display-rate rendering: spring/glide pointer motion, at most one move per frame,
/// smooth pixel scrolling, and the pointer context.
extension AppCoordinator {
    /// Called by the frame clock once per display refresh (`timestamp` on the
    /// `CACurrentMediaTime` timebase).
    public func renderFrame(at timestamp: TimeInterval) {
        let interval = Self.signposter.beginInterval("frame")
        defer { Self.signposter.endInterval("frame", interval) }
        let dt = lastFrameTime.map { timestamp - $0 } ?? 1.0 / 60.0
        lastFrameTime = timestamp

        if pointerFrozen, let until = freezeUntil, timestamp >= until { releasePointer() }

        // During a gesture (and the hold after a click) nothing moves the pointer.
        if state.allowsPointerMotion, !pointerFrozen, let target = pointerTarget {
            if !animator.isGliding, let current = lastPostedPoint,
               hypot(target.x - current.x, target.y - current.y) < CGFloat(settings.pointerDeadZonePoints) {
                animator.place(at: current)  // dead zone: hold still
            } else {
                let step = animator.step(toward: target, now: timestamp, dt: dt)
                let point = engine?.geometry.clamp(step.position) ?? step.position
                let last = lastPostedPoint ?? CGPoint(x: CGFloat.infinity, y: 0)
                // At most one move per frame, and none for sub-pixel changes.
                if hypot(point.x - last.x, point.y - last.y) >= CGFloat(settings.minMoveDistance) {
                    postMotion { deps.cursor.move(to: point) }
                    lastPostedPoint = point
                    reportLatency(at: timestamp)
                }
            }
        }

        if !scrollVelocity.isZero, state == .tracking || state == .scrollMode {
            let sign = settings.naturalScrolling ? 1.0 : -1.0
            let anchor = scrollAnchor ?? lastPostedPoint ?? deps.cursor.currentPosition
            let frameDt = min(max(dt, 0), 0.05)
            postAction {
                deps.scroll.scroll(dx: scrollVelocity.horizontal * frameDt * sign,
                                   dy: scrollVelocity.vertical * frameDt * sign, at: anchor)
            }
        }

        if let until = pressingUntil, timestamp >= until { pressingUntil = nil }
        updatePointerContext()
    }

    /// If display frames stop arriving (no display link, display asleep), render from the
    /// sensor loop instead so the pointer never stalls.
    func fallbackFrameIfStalled() {
        let now = deps.clock()
        if let last = lastFrameTime, now - last < 0.1 { return }
        renderFrame(at: now)
    }

    /// Sample-to-cursor latency: time from the sensor sample that set the target to the
    /// frame that posted the move. Visible in Instruments (Points of Interest).
    private func reportLatency(at timestamp: TimeInterval) {
        guard let updated = targetUpdatedAt else { return }
        targetUpdatedAt = nil
        let milliseconds = (deps.clock() - updated) * 1000
        latestLatencyMs = milliseconds
        Self.signposter.emitEvent("sample-to-cursor", "\(milliseconds, format: .fixed(precision: 1)) ms")
    }

    func updatePointerContext() {
        let inputs = PointerContextInputs(
            state: state,
            isPressing: pressingUntil != nil,
            scrollDirection: PointerContextResolver.direction(of: scrollVelocity),
            holdFraction: holdProgress?.fraction)
        let context = PointerContextResolver.context(for: inputs)
        if context != pointerContext { pointerContext = context }
    }
}
