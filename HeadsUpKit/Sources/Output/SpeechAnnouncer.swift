import AVFoundation
import Foundation

/// Speaks calibration prompts and state changes with `AVSpeechSynthesizer`.
@MainActor
public final class SpeechAnnouncer: Announcer {
    public var isEnabled: Bool
    private let synthesizer = AVSpeechSynthesizer()
    private let rate: Float

    public init(isEnabled: Bool = true, rate: Float = AVSpeechUtteranceDefaultSpeechRate) {
        self.isEnabled = isEnabled
        self.rate = rate
    }

    public func announce(_ text: String) {
        guard isEnabled, !text.isEmpty else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        synthesizer.speak(utterance)
    }
}
