import AVFoundation
import Foundation
import OSLog

/// Plays programmatically generated earcons through the current output (the AirPods).
@MainActor
public final class AudioFeedbackService: FeedbackService {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var buffers: [FeedbackCue: AVAudioPCMBuffer] = [:]
    private var muted: Bool
    private var configObserver: NSObjectProtocol?

    private static let log = Logger(subsystem: "com.hackthechange.HeadsUp", category: "audio")

    public init(volume: Double, muted: Bool) {
        self.muted = muted
        format = AVAudioFormat(standardFormatWithSampleRate: Earcon.sampleRate, channels: 1)!
        for cue in FeedbackCue.allCases {
            buffers[cue] = Earcon.buffer(for: Earcon.tones(for: cue), format: format)
        }
        engine.attach(player)
        player.volume = Self.sanitizedVolume(volume)
        configObserver = AudioEngineSupport.observeConfigurationChanges(of: engine) { [weak self] in
            self?.rebuildIfNeeded(reason: "audio configuration changed")
        }
        AudioEngineSupport.observeDefaultOutputChanges { [weak self] in
            self?.rebuildIfNeeded(reason: "default output changed")
        }
        rebuild()
    }

    /// Skips notifications the rebuild itself caused, so re-routing can't loop.
    private func rebuildIfNeeded(reason: String) {
        let target = AudioEngineSupport.defaultOutputDevice()
        if engine.isRunning, target == nil || AudioEngineSupport.currentDevice(of: engine) == target { return }
        Self.log.info("\(reason, privacy: .public); rebuilding cue engine")
        rebuild()
    }

    /// Stops the engine, points it at the current default output (the AirPods when connected),
    /// reconnects the graph and starts again. A configuration or route change stops the engine
    /// and can leave stale connections, so a plain `start()` isn't enough.
    private func rebuild() {
        engine.stop()
        if let device = AudioEngineSupport.defaultOutputDevice() {
            AudioEngineSupport.route(engine, to: device)
        }
        engine.disconnectNodeOutput(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
        engine.prepare()
        do {
            try engine.start()
            player.play()
        } catch {
            Self.log.error("cue engine failed to start: \(error.localizedDescription, privacy: .public)")
        }
    }

    public func configure(volume: Double, muted: Bool) {
        player.volume = Self.sanitizedVolume(volume)
        self.muted = muted
    }

    /// Out-of-range or zero volumes fall back to the default; "Mute cues" is the way to silence them.
    static func sanitizedVolume(_ volume: Double) -> Float {
        guard volume.isFinite, volume > 0 else { return Float(HeadsUpSettings.defaults.feedbackVolume) }
        return Float(min(volume, 1))
    }

    public func play(_ cue: FeedbackCue) {
        guard !muted, let buffer = buffers[cue] else { return }
        if !engine.isRunning { rebuild() }
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

    static func tones(for cue: FeedbackCue) -> [Tone] {
        switch cue {
        case .select: return [Tone(frequency: 880, duration: 0.05), Tone(frequency: 1318.5, duration: 0.07)]
        case .cancel: return [Tone(frequency: 659.3, duration: 0.05), Tone(frequency: 440, duration: 0.07)]
        case .paused: return [Tone(frequency: 523.3, duration: 0.06), Tone(frequency: 392, duration: 0.08)]
        case .resumed: return [Tone(frequency: 392, duration: 0.06), Tone(frequency: 523.3, duration: 0.08)]
        case .recentered:
            return [Tone(frequency: 1046.5, duration: 0.035), Tone(frequency: 0, duration: 0.02),
                    Tone(frequency: 1046.5, duration: 0.035), Tone(frequency: 0, duration: 0.02),
                    Tone(frequency: 1046.5, duration: 0.035)]
        case .calibrationStep: return [Tone(frequency: 1568, duration: 0.05)]
        case .calibrationDone:
            return [Tone(frequency: 784, duration: 0.045), Tone(frequency: 987.8, duration: 0.045),
                    Tone(frequency: 1174.7, duration: 0.055)]
        case .error:
            return [Tone(frequency: 220, duration: 0.05), Tone(frequency: 0, duration: 0.03),
                    Tone(frequency: 220, duration: 0.05)]
        case .scrollOn:
            return [Tone(frequency: 587.3, duration: 0.04), Tone(frequency: 784, duration: 0.04),
                    Tone(frequency: 587.3, duration: 0.05)]
        case .scrollOff:
            return [Tone(frequency: 784, duration: 0.04), Tone(frequency: 587.3, duration: 0.04),
                    Tone(frequency: 440, duration: 0.05)]
        case .listeningStart: return [Tone(frequency: 698.5, duration: 0.05), Tone(frequency: 1396.9, duration: 0.08)]
        case .listeningStop: return [Tone(frequency: 1396.9, duration: 0.05), Tone(frequency: 698.5, duration: 0.08)]
        }
    }

    static func totalDuration(of tones: [Tone]) -> Double {
        tones.reduce(0) { $0 + $1.duration }
    }

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
