import Foundation

/// A short, distinct confirmation cue.
public enum FeedbackCue: String, Sendable, Equatable, CaseIterable {
    case select
    case cancel
    case paused
    case resumed
    case recentered
    case calibrationStep
    case calibrationDone
    case error
    case scrollOn
    case scrollOff
    case listeningStart
    case listeningStop
}

/// Plays feedback cues. AirPods have no haptic actuator or public haptics API, so the
/// shipping implementation is audio (`AudioFeedbackService`); real haptics can be added
/// behind this protocol if Apple ever exposes them.
@MainActor
public protocol FeedbackService: AnyObject {
    func play(_ cue: FeedbackCue)
    func configure(volume: Double, muted: Bool)
}

/// Speaks prompts and state changes.
@MainActor
public protocol Announcer: AnyObject {
    var isEnabled: Bool { get set }
    func announce(_ text: String)
}
