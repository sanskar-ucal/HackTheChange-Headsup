import AVFoundation
import Foundation

/// Speaks calibration prompts and state changes with `AVSpeechSynthesizer`. Speech goes to
/// the current output device, which macOS switches to the Mac speakers when the AirPods
/// disconnect, so "paused" announcements are still heard.
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
        // A new prompt supersedes whatever is still being said.
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        synthesizer.speak(utterance)
    }
}
