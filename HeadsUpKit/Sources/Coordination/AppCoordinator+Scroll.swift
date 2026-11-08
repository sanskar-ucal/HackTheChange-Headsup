import CoreGraphics
import Foundation

/// In-place scroll mode: a double nod freezes the pointer and head pitch scrolls.
/// A shake or another double nod exits.
extension AppCoordinator {
    func enterScrollMode() {
        guard state == .tracking else { return }
        scrollMode = ScrollModeRecognizer(settings: settings)
        modeRecognizer.reset()
        scrollAnchor = lastPostedPoint ?? deps.cursor.currentPosition
        enter(.scrollMode)
        deps.feedback.play(.scrollOn)
        announce("Scroll mode. Look up or down to scroll. Shake to stop.")
    }

    public func exitScrollMode() {
        guard state == .scrollMode else { return }
        scrollMode = nil
        deps.feedback.play(.scrollOff)
        returnToTracking()
    }

    func handleScrollMode(raw: HeadPose, filtered: HeadPose) {
        for event in modeRecognizer.process(raw) {
            switch event {
            case .confirmed(.doubleNod, _), .confirmed(.shake, _):
                exitScrollMode()
                return
            default:
                break
            }
        }
        scrollVelocity = scrollMode?.velocity(for: filtered) ?? .zero
        updatePointerContext()
    }
}
