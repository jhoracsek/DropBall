//
//  Audio.swift
//  DropBall
//

import Foundation
import AVFoundation
import CoreGraphics

/// Sound effects.
///
/// Built on AVAudioEngine with pre-decoded PCM buffers rather than AVAudioPlayer. An
/// AVAudioPlayer has to be re-seeked and restarted on every trigger, and `play()` can block
/// the calling thread while it buffers — which is the main thread here, so it showed up as
/// a frame hitch on every bounce. Scheduling a buffer onto an already-running player node
/// hands the work to the engine's own render thread instead, and costs almost nothing at
/// the call site.
enum Audio {

    /// Variants of the bounce, picked between so repeated landings don't sound mechanical.
    private static let bounceNames = ["bounce1", "bounce2", "bounce3"]

    /// Player nodes sharing one pool, used round-robin. Generous for ~150ms clips landing
    /// under a second apart, but nodes are cheap and it guarantees overlaps never clip.
    private static let voiceCount = 6

    /// Volume range the bounce strength maps into.
    private static let minVolume: Float = 0.35
    private static let maxVolume: Float = 1.0

    private static let engine = AVAudioEngine()
    private static var buffers: [AVAudioPCMBuffer] = []
    private static var players: [AVAudioPlayerNode] = []
    private static var nextVoice = 0
    private static var lastVariant = -1
    private static var isLoaded = false

    /// Read live rather than cached, so toggling Sound Effects takes effect straight away.
    static var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "SoundOff")
    }

    /// Decodes the clips and starts the engine. Safe to call repeatedly; only the first
    /// call does any work. Worth calling at launch so the decode doesn't land on the first
    /// frame of a run.
    static func prepare() {
        guard !isLoaded else { return }
        isLoaded = true

        configureSession()
        loadBuffers()
        startEngine()
    }

    private static func configureSession() {
        // .playback ignores the ring/silent switch, so effects are still heard with the
        // phone muted. .mixWithOthers is what keeps that from being rude — without it
        // .playback would stop whatever music or podcast the player already had going.
        // The two are independent: the category decides the mute switch, the option
        // decides whether other audio survives.
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private static func loadBuffers() {
        for name in bounceNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else {
                print("Missing sound file: \(name).wav")
                continue
            }

            do {
                let file = try AVAudioFile(forReading: url)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                    frameCapacity: AVAudioFrameCount(file.length)) else {
                    print("Could not allocate buffer for \(name).wav")
                    continue
                }
                // Decoded once, here, rather than on every trigger.
                try file.read(into: buffer)
                buffers.append(buffer)
            } catch {
                print("Could not decode \(name).wav: \(error)")
            }
        }
    }

    private static func startEngine() {
        // Every clip is the same format, so one connection format serves all the nodes.
        guard let format = buffers.first?.format else { return }

        for _ in 0..<voiceCount {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            players.append(node)
        }

        do {
            try engine.start()

            // Started once and left running. A running node with nothing scheduled sits
            // idle, and scheduling onto it then plays immediately — which is what removes
            // the per-trigger start cost.
            for node in players {
                node.play()
            }
        } catch {
            print("Audio engine error: \(error)")
        }
    }

    /// - Parameters:
    ///   - strength: 0 for the gentlest landing, 1 for the hardest. Same value the haptics
    ///     use, so the two stay in step.
    ///   - scale: an overall multiplier on the result, for contexts that want the same
    ///     sound at a lower level. Defaults to 1, so gameplay is unaffected.
    static func playBounce(strength: CGFloat, scale: CGFloat = 1.0) {
        guard isEnabled, !buffers.isEmpty, !players.isEmpty else { return }

        // An interruption or route change (headphones, a call) can stop the engine. Without
        // this the game would simply go quiet for the rest of the session.
        if !engine.isRunning {
            try? engine.start()
            for node in players where !node.isPlaying {
                node.play()
            }
        }

        let buffer = buffers[pickVariant()]

        let node = players[nextVoice]
        nextVoice = (nextVoice + 1) % players.count

        let clamped = Float(min(max(strength, 0), 1))
        let base = minVolume + (maxVolume - minVolume) * clamped
        node.volume = base * Float(min(max(scale, 0), 1))

        // .interrupts replaces anything still playing on this node, so a trigger is always
        // immediate even if the round-robin wraps onto a node that's still finishing.
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }

    /// Never the same variant twice running — a straight random pick repeats often enough
    /// to be noticeable with only three to choose from.
    ///
    /// Written to avoid allocating a candidate array, since this runs from the game loop.
    private static func pickVariant() -> Int {
        let count = buffers.count

        guard lastVariant >= 0, count > 1 else {
            lastVariant = Int.random(in: 0..<count)
            return lastVariant
        }

        var pick = Int.random(in: 0..<(count - 1))
        if pick >= lastVariant {
            pick += 1
        }
        lastVariant = pick
        return pick
    }
}
