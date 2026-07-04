import Foundation
import SDL2Swift
import SDL2Mixer
import CelesteCore

/// Implements `CelesteAudio` against SDL2_mixer, loading the original
/// ccleste `data/sndN.wav` / `data/musN.ogg` assets bundled as package
/// resources. Track/effect ids match celeste.c's numbering exactly (e.g.
/// `music(index:)` uses `index/10` to select `musN.ogg`, `sfx(_:)` indexes
/// `sndN.wav` directly), mirroring `pico8emu`'s MUSIC/SFX cases.
///
/// Note: the `SDL2Mixer` Swift wrapper only exposes `Mix_PlayMusic`/
/// `Mix_HaltMusic` (no fade variants), so `fadeMs` is accepted for API
/// parity with the original but not applied — a cosmetic simplification,
/// it doesn't affect gameplay timing/logic.
final class AudioBackend: CelesteAudio {
    private var musicByIndex: [Int: SDLMusic] = [:]
    private var chunksById: [Int: SDLAudioChunk] = [:]

    init(dataDirectory: URL) {
        let musicIds = [0, 10, 20, 30, 40]
        for id in musicIds {
            let url = dataDirectory.appendingPathComponent("mus\(id).ogg")
            if let music = try? SDLMusic(contentsOfFile: url.path) {
                musicByIndex[id] = music
            }
        }

        let sfxIds = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 13, 14, 15, 16, 23, 35, 37, 38, 40, 50, 51, 54, 55]
        for id in sfxIds {
            let url = dataDirectory.appendingPathComponent("snd\(id).wav")
            if let chunk = try? SDLAudioChunk(contentsOfFile: url.path) {
                chunksById[id] = chunk
            }
        }
    }

    func music(index: Int, fadeMs: Int) {
        if index == -1 {
            try? SDLMusic.halt()
            return
        }
        guard let music = musicByIndex[index] else { return }
        try? music.play(loops: -1)
    }

    func sfx(_ id: Int) {
        guard let chunk = chunksById[id] else { return }
        _ = try? chunk.play(loops: 0)
    }
}
