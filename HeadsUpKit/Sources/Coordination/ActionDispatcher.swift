import CoreGraphics
import Foundation

/// Something HeadsUp does in response to a gesture.
public enum HeadsUpAction: String, Sendable, Equatable, Codable {
    case click
    case escape
    case togglePause
    case recenter
    case toggleScrollMode
    case none
}

/// Maps gestures to actions and performs the input actions (click, escape) together with their feedback cue.
@MainActor
public final class ActionDispatcher {
    public var mapping: [HeadGesture: HeadsUpAction]

    private let cursor: CursorController
    private let feedback: FeedbackService

    public static let defaultMapping: [HeadGesture: HeadsUpAction] = [
        .nod: .click,
        .doubleNod: .toggleScrollMode,
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

    @discardableResult
    public func dispatch(_ gesture: HeadGesture, at point: CGPoint) -> HeadsUpAction {
        let action = action(for: gesture)
        switch action {
        case .click:
            cursor.click(at: point)
            feedback.play(.select)
        case .escape:
            cursor.pressKey(.escape)
            feedback.play(.cancel)
        case .togglePause, .recenter, .toggleScrollMode, .none:
            break
        }
        return action
    }
}
