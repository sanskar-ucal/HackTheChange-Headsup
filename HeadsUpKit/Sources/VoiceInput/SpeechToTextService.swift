import Foundation

/// Updates from a speech recognition session.
public enum SpeechEvent: Sendable, Equatable {
    case partial(String)
    case final(String)
    case failed(String)
}

/// Speech recognition for voice input into text fields.
@MainActor
public protocol SpeechToTextService: AnyObject {
    var authorization: AuthorizationState { get }
    func requestAuthorization()
    func start(useBuiltInMicrophone: Bool, silenceTimeout: TimeInterval,
               onEvent: @escaping @MainActor (SpeechEvent) -> Void) -> Bool
    func finish()
    func cancel()
}
