import CTRU

/// `CelesteAudio` against the 3DS's NDSP (audio DSP), mirroring junkbot-swift's
/// `ports/3DS/source/Audio.swift`. Every clip is pre-converted at build time
/// (`tools/gen_audio.py`, embedded as `sfx.bin`/`music.bin`) to signed 16-bit PCM
/// mono at its native sample rate -- `ctru_play_pcm16` (common/shim.c) owns the
/// actual `ndspChnWaveBufAdd` call and the DSP-safe linear-memory copies of both
/// blobs.
final class Audio3DS: CelesteAudio {
    /// NDSP channel reserved for music; sound effects round-robin over the rest.
    private let musicChannel: Int32 = 0
    private let sfxChannelCount: Int32 = 7
    private var nextSFXChannel: Int32 = 1

    init() {
        ctru_audio_init()
    }

    func music(index: Int, fadeMs: Int) {
        if index == -1 {
            ctru_stop_channel(musicChannel)
            return
        }
        let group = index / 10
        guard group >= 0, group < musicClipTable.count else { return }
        let clip = musicClipTable[group]
        guard clip.length > 0 else { return }
        ctru_play_pcm16(
            musicChannel, /* bank: */ 1, UInt32(clip.offset) / 2, UInt32(clip.length) / 2,
            Float(clip.sampleRate), /* loop: */ 1)
    }

    func sfx(_ id: Int) {
        guard id >= 0, id < sfxClipTable.count else { return }
        let clip = sfxClipTable[id]
        guard clip.length > 0 else { return }
        let channel = nextSFXChannel
        nextSFXChannel = 1 + (nextSFXChannel % sfxChannelCount)
        ctru_play_pcm16(
            channel, /* bank: */ 0, UInt32(clip.offset) / 2, UInt32(clip.length) / 2,
            Float(clip.sampleRate), /* loop: */ 0)
    }
}
