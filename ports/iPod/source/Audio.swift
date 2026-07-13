import RB

/// Audio boundary for the Rockbox port. The engine's `music`/`sfx` calls are
/// forwarded to the C shim (`rb_audio_*` in plugin/rockbox_shim.c), which is a
/// no-op today: the port ships silent first, then grows a C-side PCM mixer fed
/// from `/.rockbox/celeste/` blobs (see the audio phases in ports/iPod/README).
/// Keeping the Swift side calling through from day one means the audio phases
/// only ever touch C.
final class RockboxAudio: CelesteAudio {
    func music(index: Int, fadeMs: Int) {
        rb_audio_music(Int32(index), Int32(fadeMs))
    }

    func sfx(_ id: Int) {
        rb_audio_sfx(Int32(id))
    }
}
