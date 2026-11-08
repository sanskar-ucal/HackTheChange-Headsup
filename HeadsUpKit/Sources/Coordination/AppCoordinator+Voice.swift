import CoreGraphics
import Foundation

/// Automatic voice input: after a HeadsUp click lands in a (search) text field, listen, insert the transcript.
extension AppCoordinator {
    func didPerformClick() {
        lastClickTime = deps.clock()
        guard settings.voiceInputTrigger != .off else { return }
        deps.schedule(settings.voiceDetectDelay) { [weak self] in self?.checkFocusForVoiceInput() }
    }

    func handleFocusChange() {
        guard deps.clock() - lastClickTime <= settings.voiceClickFocusWindow else { return }
        checkFocusForVoiceInput()
    }

    func checkFocusForVoiceInput() {
        guard state == .tracking, settings.voiceInputTrigger != .off,
              let element = deps.focusReader.focusedElement(),
              TextFieldDetector.shouldListen(element.info, trigger: settings.voiceInputTrigger) else { return }
        let started = deps.speech.start(
            useBuiltInMicrophone: settings.useBuiltInMicrophone, silenceTimeout: settings.voiceSilenceTimeout
        ) { [weak self] event in
            self?.handleSpeech(event)
        }
        guard started else { return }
        voiceTarget = element
        voiceInsertion = nil
        modeRecognizer.reset()
        enter(.listening)
        transcript = ""
        deps.feedback.play(.listeningStart)
    }

    func handleSpeech(_ event: SpeechEvent) {
        guard state == .listening else { return }
        switch event {
        case let .partial(text):
            transcript = text
        case let .final(text):
            deps.feedback.play(.listeningStop)
            let spoken = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !spoken.isEmpty, let target = voiceTarget else {
                endVoiceInput()
                return
            }
            transcript = spoken
            var record: InsertionRecord?
            postAction { record = deps.textInserter.insert(spoken, into: target) }
            guard let record else {
                deps.feedback.play(.error)
                endVoiceInput()
                return
            }
            voiceInsertion = record
            voiceReviewStart = nil
            modeRecognizer.reset()
            enter(.voiceReview)
        case .failed:
            deps.feedback.play(.error)
            endVoiceInput()
        }
    }

    func handleVoiceGestures(_ pose: HeadPose) {
        if state == .voiceReview {
            let start = voiceReviewStart ?? pose.timestamp
            voiceReviewStart = start
            if pose.timestamp - start > settings.voiceReviewTimeout {
                endVoiceInput()
                return
            }
        }
        for event in modeRecognizer.process(pose) {
            guard case let .confirmed(gesture, _) = event else { continue }
            switch (state, gesture) {
            case (.listening, .nod), (.listening, .doubleNod):
                deps.speech.finish()
            case (.listening, .shake):
                deps.speech.cancel()
                deps.feedback.play(.cancel)
                endVoiceInput()
            case (.voiceReview, .nod), (.voiceReview, .doubleNod):
                postAction { deps.textInserter.pressReturn() }
                deps.feedback.play(.select)
                endVoiceInput()
            case (.voiceReview, .shake):
                if let record = voiceInsertion { postAction { deps.textInserter.undo(record) } }
                deps.feedback.play(.cancel)
                endVoiceInput()
            default:
                continue
            }
            return
        }
    }

    private func endVoiceInput() {
        voiceTarget = nil
        voiceInsertion = nil
        voiceReviewStart = nil
        returnToTracking()
    }
}
