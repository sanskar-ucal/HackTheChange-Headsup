import CoreGraphics
import Foundation

/// Something HeadsUp does in response to a gesture.
public enum HeadsUpAction: String, Sendable, Equatable, Codable {
    case click
    case escape
    case togglePause
    case recenter
    case none
}

/// Maps gestures to actions and performs the input actions (click, escape) together with
/// their feedback cue. App-control actions (pause, recenter) are returned to the
/// coordinator, which owns the state machine.
@MainActor
public final class ActionDispatcher {
    public var mapping: [HeadGesture: HeadsUpAction]

    private let cursor: CursorController
    private let feedback: FeedbackService

    public static let defaultMapping: [HeadGesture: HeadsUpAction] = [
        .nod: .click,
        .shake: .escape,
        .tiltHoldLeft: .togglePause,
        .tiltHoldRight: .recenter,
    ]

    public init(cursor: CursorController, feedback: FeedbackService,
                mapping: [HeadGesture: HeadsUpAction] = ActionDispatcher.defaultMapping) {
        self.cursor = cursor
        self.feedback = feedback
        self.mapping = mapping
    }

    public func action(for gesture: HeadGesture) -> HeadsUpAction {
        mapping[gesture] ?? .none
    }

    /// Performs input actions at `point` and returns the action so the caller can handle
    /// app-control actions. The caller is responsible for only dispatching while tracking.
    @discardableResult
    public func dispatch(_ gesture: HeadGesture, at point: CGPoint) -> HeadsUpAction {
        let action = action(for: gesture)
        switch action {
        case .click:
            cursor.click(at: point)
            feedback.play(.select)
        case .escape:
            cursor.move(to: point)
            cursor.pressKey(.escape)
            feedback.play(.cancel)
        case .togglePause, .recenter, .none:
            break
        }
        return action
    }
}
