//
//  Music.swift
//  DropBall
//

import Foundation
import AVFoundation
import UIKit

/// Background music: a playlist shuffled once per launch, then played in that order on a
/// loop, continuing across every scene.
///
/// Uses `AVAudioPlayer`, deliberately *not* the `AVAudioEngine` buffers that `Audio` uses
/// for the bounce effects. The two have opposite requirements: effects are tiny and fire
/// many times a second, so they need pre-decoded buffers and a near-zero trigger cost;
/// tracks are one to two minutes each and start once, so trigger cost is irrelevant but
/// decoding them into memory would cost around 20 MB apiece. AVAudioPlayer streams from
/// disk instead.
final class Music: NSObject {

    static let shared = Music()

    /// Filenames in the bundle. The display titles live in `Attributions`, not here.
    private static let tracks = [
        "music_world_of_nowhere",
        "music_your_tomorrow",
        "music_so_do_i",
        "music_with_my_name",
        "music_first_memories"
    ]

    /// Fixed level, chosen so the bounce effects cut through without the music ducking.
    /// Ducking was explicitly not wanted, so this is the only thing keeping them balanced.
    private static let volume: Float = 0.45

    /// Playback order, shuffled once in `start()` and then followed for the rest of the
    /// session, wrapping at the end. Shuffling once means no track repeats within a cycle.
    private var order: [Int] = []
    private var position = 0

    private var player: AVAudioPlayer?

    /// The next track, created and buffered while the current one plays, so the handover
    /// doesn't have a decode gap in it.
    private var nextPlayer: AVAudioPlayer?

    private var isStarted = false

    /// Whether playback was running before something external paused it, so the right
    /// decision can be made when the app or session comes back.
    private var wantsPlayback = false

    static var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "MusicOff")
    }

    // MARK: - Lifecycle

    /// Shuffles the playlist and begins, if music is enabled. Safe to call more than once.
    func start() {
        guard !isStarted else { return }
        isStarted = true

        // Guarantees the shared audio session is configured before any player is created.
        Audio.prepare()

        order = Array(Music.tracks.indices).shuffled()
        position = 0

        observeInterruptions()

        guard Music.isEnabled else { return }
        wantsPlayback = true
        playCurrent()
    }

    /// Called when the Music setting changes, so the toggle takes effect immediately
    /// instead of at the next track boundary.
    func setEnabled(_ enabled: Bool) {
        wantsPlayback = enabled

        guard enabled else {
            player?.pause()
            return
        }

        if player == nil {
            playCurrent()
        } else {
            player?.play()
        }
    }

    // MARK: - Playback

    private func playCurrent() {
        guard !order.isEmpty else { return }

        // Reuse the pre-buffered player when the previous track handed over to it.
        let current = nextPlayer ?? makePlayer(for: order[position])
        nextPlayer = nil

        guard let current = current else {
            // Missing or unreadable file: skip past it rather than stalling the playlist.
            advance()
            return
        }

        current.delegate = self
        current.volume = Music.volume
        current.play()
        player = current

        prepareNext()
    }

    private func prepareNext() {
        let upcoming = (position + 1) % order.count
        nextPlayer = makePlayer(for: order[upcoming])
        nextPlayer?.volume = Music.volume
        nextPlayer?.prepareToPlay()
    }

    private func makePlayer(for trackIndex: Int) -> AVAudioPlayer? {
        let name = Music.tracks[trackIndex]

        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a") else {
            print("Missing music file: \(name).m4a")
            return nil
        }

        do {
            return try AVAudioPlayer(contentsOf: url)
        } catch {
            print("Could not open \(name).m4a: \(error)")
            return nil
        }
    }

    private func advance() {
        position = (position + 1) % order.count
        playCurrent()
    }

    // MARK: - Interruptions

    private func observeInterruptions() {
        let centre = NotificationCenter.default

        centre.addObserver(self,
                           selector: #selector(handleInterruption(_:)),
                           name: AVAudioSession.interruptionNotification,
                           object: AVAudioSession.sharedInstance())

        // Backgrounding stops playback without an interruption notification, so returning
        // to the foreground has to resume it explicitly or the music stays silent.
        centre.addObserver(self,
                           selector: #selector(handleForeground),
                           name: UIApplication.didBecomeActiveNotification,
                           object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

        switch type {
        case .began:
            player?.pause()
        case .ended:
            guard wantsPlayback, Music.isEnabled else { return }
            try? AVAudioSession.sharedInstance().setActive(true)
            player?.play()
        @unknown default:
            break
        }
    }

    @objc private func handleForeground() {
        guard wantsPlayback, Music.isEnabled else { return }
        guard let player = player, !player.isPlaying else { return }

        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }
}

extension Music: AVAudioPlayerDelegate {

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Moves on either way — a decode failure part way through shouldn't leave the
        // playlist stuck on a broken track.
        advance()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Music decode error: \(String(describing: error))")
        advance()
    }
}
