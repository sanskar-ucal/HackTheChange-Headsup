import Foundation

public enum SpeechEvent: Sendable, Equatable {
    case partial(String)
    /// Listening ended; the text may be empty.
    case final(String)
    case failed(String)
}

/// Speech recognition for voice input into text fields.
@MainActor
public protocol SpeechToTextService: AnyObject {
    var authorization: AuthorizationState { get }
    func requestAuthorization()
    /// Starts listening. Events arrive on the main actor; listening ends by itself after
    /// `silenceTimeout` without new speech. Returns false if recognition is unavailable.
    func start(useBuiltInMicrophone: Bool, silenceTimeout: TimeInterval,
               onEvent: @escaping @MainActor (SpeechEvent) -> Void) -> Bool
    /// Stop now and deliver `.final` with what was heard so far.
    func finish()
    /// Stop without delivering anything.
    func cancel()
}
