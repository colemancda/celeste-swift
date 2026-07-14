/// Audio boundary for the Rockbox port. The engine's `music`/`sfx` calls
/// route through the `Rockbox` wrapper (Rockbox.swift) to the C mixer
/// (plugin/mixer.c): SFX play from the sfx.bin blob loaded at startup;
/// music is still a no-op pending the next audio phase (see
/// ports/iPod/README.md).
final class RockboxAudio: CelesteAudio {
    func music(index: Int, fadeMs: Int) {
        Rockbox.music(index: index, fadeMs: fadeMs)
    }

    func sfx(_ id: Int) {
        Rockbox.sfx(id)
    }
}
