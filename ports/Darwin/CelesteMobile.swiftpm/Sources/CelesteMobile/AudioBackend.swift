import Foundation
import AVFoundation
import CelesteCore

/// Implements `CelesteAudio` against `AVAudioPlayer`, loading the original ccleste
/// `data/sndN.wav` assets as-is and the `data/musN.ogg` tracks pre-transcoded to `.caf`
/// (`Scripts/`-less one-off conversion via `afconvert`, mirroring `ports/Darwin`'s
/// `Scripts/transcode-audio.sh` in junkbot-swift) since AVFoundation has no built-in Ogg
/// Vorbis decoder on Apple platforms.
///
/// Note: like `ports/SDL2`'s `AudioBackend`, `fadeMs` is accepted for API parity with the
/// original `music(idx,fade,mask)` callback but not applied (`AVAudioPlayer` fades are
/// asynchronous and not worth the complexity here) - cosmetic only, doesn't affect gameplay.
final class AudioBackend: CelesteAudio {
    private var musicByIndex: [Int: AVAudioPlayer] = [:]
    private var chunksById: [Int: AVAudioPlayer] = [:]
    private var currentMusic: AVAudioPlayer?

    init() {
        let musicIds = [0, 10, 20, 30, 40]
        for id in musicIds {
            guard let url = Bundle.module.url(forResource: "mus\(id)", withExtension: "caf") else { continue }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.numberOfLoops = -1
            player.prepareToPlay()
            musicByIndex[id] = player
        }

        let sfxIds = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15, 16, 23, 35, 37, 38, 40, 50, 51, 54, 55]
        for id in sfxIds {
            guard let url = Bundle.module.url(forResource: "snd\(id)", withExtension: "wav") else { continue }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            chunksById[id] = player
        }
    }

    func music(index: Int, fadeMs: Int) {
        if index == -1 {
            currentMusic?.stop()
            currentMusic = nil
            return
        }
        guard let player = musicByIndex[index] else { return }
        currentMusic?.stop()
        player.currentTime = 0
        player.play()
        currentMusic = player
    }

    func sfx(_ id: Int) {
        guard let player = chunksById[id] else { return }
        if player.isPlaying {
            // AVAudioPlayer can't overlap playback of the same instance (unlike SDL_mixer's
            // auto-picked free channel per Mix_PlayChannel call); restarting from 0 is close
            // enough for ccleste's short one-shot effects.
            player.currentTime = 0
        } else {
            player.play()
        }
    }
}
