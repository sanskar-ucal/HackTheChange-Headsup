import AVFoundation
import Foundation

/// Plays programmatically generated earcons through the current output (the AirPods).
/// All buffers are synthesized up front and the engine and player stay running, so a cue
/// starts within one render cycle of `play`.
@MainActor
public final class AudioFeedbackService: FeedbackService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [FeedbackCue: AVAudioPCMBuffer] = [:]
    private var muted: Bool
    private var configObserver: NSObjectProtocol?

    public init(volume: Double, muted: Bool) {
        self.muted = muted
        format = AVAudioFormat(standardFormatWithSampleRate: Earcon.sampleRate, channels: 1)!
        for cue in FeedbackCue.allCases {
            buffers[cue] = Earcon.buffer(for: Earcon.tones(for: cue), format: format)
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = Float(volume)
        configObserver = AudioEngineSupport.restartOnConfigurationChange(
            engine, shouldRun: { true }, afterRestart: { [weak self] in self?.player.play() })
        AudioEngineSupport.startIfNeeded(engine)
        if engine.isRunning { player.play() }
    }

    public func configure(volume: Double, muted: Bool) {
        player.volume = Float(min(max(volume, 0), 1))
        self.muted = muted
    }

    public func play(_ cue: FeedbackCue) {
        guard !muted, let buffer = buffers[cue] else { return }
        if !engine.isRunning {
            AudioEngineSupport.startIfNeeded(engine)
        }
        guard engine.isRunning else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}

/// Earcon definitions and a tiny sine synthesizer.
enum Earcon {
    static let sampleRate: Double = 44_100

    /// A sine note; `frequency == 0` is a rest.
    struct Tone: Equatable {
        var frequency: Double
        var duration: Double
    }

    /// Each cue is under 150 ms and has its own melodic contour.
    static func tones(for cue: FeedbackCue) -> [Tone] {
        switch cue {
        case .select: return [Tone(frequency: 880, duration: 0.05), Tone(frequency: 1318.5, duration: 0.07)]   // rising
        case .cancel: return [Tone(frequency: 659.3, duration: 0.05), Tone(frequency: 440, duration: 0.07)]    // falling
        case .paused: return [Tone(frequency: 523.3, duration: 0.06), Tone(frequency: 392, duration: 0.08)]    // low falling
        case .resumed: return [Tone(frequency: 392, duration: 0.06), Tone(frequency: 523.3, duration: 0.08)]   // low rising
        case .recentered:
            return [Tone(frequency: 1046.5, duration: 0.035), Tone(frequency: 0, duration: 0.02),
                    Tone(frequency: 1046.5, duration: 0.035), Tone(frequency: 0, duration: 0.02),
                    Tone(frequency: 1046.5, duration: 0.035)]                                                     // triple tick
        case .calibrationStep: return [Tone(frequency: 1568, duration: 0.05)]                                    // single tick
        case .calibrationDone:
            return [Tone(frequency: 784, duration: 0.045), Tone(frequency: 987.8, duration: 0.045),
                    Tone(frequency: 1174.7, duration: 0.055)]                                                     // arpeggio
        case .error:
            return [Tone(frequency: 220, duration: 0.05), Tone(frequency: 0, duration: 0.03),
                    Tone(frequency: 220, duration: 0.05)]                                                         // low double
        }
    }

    static func totalDuration(of tones: [Tone]) -> Double {
        tones.reduce(0) { $0 + $1.duration }
    }

    /// Renders tones into a mono float buffer with 5 ms attack / 15 ms release envelopes
    /// so cues don't click or startle.
    static func buffer(for tones: [Tone], format: AVAudioFormat, amplitude: Float = 0.35) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount((totalDuration(of: tones) * sampleRate).rounded(.up))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        var index = 0
        for tone in tones {
            let frames = Int(tone.duration * sampleRate)
            let attack = max(Int(0.005 * sampleRate), 1)
            let release = max(Int(0.015 * sampleRate), 1)
            for i in 0..<frames where index < Int(frameCount) {
                var sample: Float = 0
                if tone.frequency > 0 {
                    let envelope = min(1, Double(i) / Double(attack), Double(frames - i) / Double(release))
                    sample = amplitude * Float(envelope * sin(2 * .pi * tone.frequency * Double(i) / sampleRate))
                }
                channel[index] = sample
                index += 1
            }
        }
        while index < Int(frameCount) {
            channel[index] = 0
            index += 1
        }
        return buffer
    }
}
