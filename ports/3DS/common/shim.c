//---------------------------------------------------------------------------------
// shim.c -- shared C support for the Celeste 3DS port (see shim.h).
//---------------------------------------------------------------------------------
#include <3ds.h>
#include <errno.h>
#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "shim.h"
#include "assets.h"

//---------------------------------------------------------------------------------
// Runtime support the Embedded Swift object needs but devkitARM's newlib does
// not provide for this target (same gaps as junkbot-swift's ports/3DS/ports/NDS).
//---------------------------------------------------------------------------------

// Swift's allocator calls posix_memalign; newlib's armv6k/fpu libc only ships
// memalign (declared, but never defined).
int posix_memalign(void **memptr, size_t alignment, size_t size) {
    void *p = memalign(alignment, size);
    if (!p) return ENOMEM;
    *memptr = p;
    return 0;
}

// Embedded Swift's runtime can reference arc4random_buf; newlib's implementation
// falls through to getentropy for seeding, which libctru doesn't implement.
// Supply a small xorshift PRNG as the missing entropy source instead. NOT
// cryptographically secure -- fine here, since CelesteEngine has its own
// PICO-8-faithful RNG and never touches Swift's Random for gameplay.
static uint32_t s_entropyState = 0x2545F491u;

int getentropy(void *buf, size_t buflen) {
    uint8_t *p = (uint8_t *)buf;
    for (size_t i = 0; i < buflen; i++) {
        s_entropyState ^= s_entropyState << 13;
        s_entropyState ^= s_entropyState >> 17;
        s_entropyState ^= s_entropyState << 5;
        p[i] = (uint8_t)s_entropyState;
    }
    return 0;
}

int _getentropy_r(void *reent, void *buf, size_t buflen) {
    (void)reent;
    return getentropy(buf, buflen);
}

void ctru_puts(const char *s) {
    printf("%s", s);
}

void ctru_printf_1i(const char *fmt, int a) {
    printf(fmt, a);
}

//---------------------------------------------------------------------------------
// Audio (NDSP) -- see shim.h. sfx.bin/music.bin are embedded read-only in the
// ELF's .rodata (bin2s), but NDSP's DMA needs its source in "linear" memory, so
// both blobs are copied once (at ctru_audio_init) into linearAlloc'd buffers;
// playback just points wave buffers at offsets into those persistent copies --
// no per-play allocation.
//---------------------------------------------------------------------------------
static int16_t *linearSFXPCM = NULL;
static int16_t *linearMusicPCM = NULL;

// One NDSP channel needs one ndspWaveBuf that stays alive for as long as that
// channel might be playing; Embedded Swift can't touch this tagged-union
// struct directly (see shim.h), so every channel's wave buffer lives here.
#define CTRU_NDSP_CHANNEL_COUNT 8
static ndspWaveBuf channelWaveBuf[CTRU_NDSP_CHANNEL_COUNT];

void ctru_audio_init(void) {
    ndspInit();
    ndspSetOutputMode(NDSP_OUTPUT_STEREO);
    ndspSetMasterVol(1.0f);

    uint32_t sfxLen = ctru_asset_sfx_bin_size();
    linearSFXPCM = (int16_t *)linearAlloc(sfxLen);
    memcpy(linearSFXPCM, ctru_asset_sfx_bin(), sfxLen);
    DSP_FlushDataCache(linearSFXPCM, sfxLen);

    uint32_t musicLen = ctru_asset_music_bin_size();
    linearMusicPCM = (int16_t *)linearAlloc(musicLen);
    memcpy(linearMusicPCM, ctru_asset_music_bin(), musicLen);
    DSP_FlushDataCache(linearMusicPCM, musicLen);
}

void ctru_play_pcm16(int channel, int bank, unsigned sampleOffset, unsigned sampleCount,
                      float rate, int loop) {
    if (channel < 0 || channel >= CTRU_NDSP_CHANNEL_COUNT || sampleCount == 0) return;

    int16_t *base = bank == 0 ? linearSFXPCM : linearMusicPCM;

    ndspChnReset(channel);
    ndspChnSetInterp(channel, NDSP_INTERP_LINEAR);
    ndspChnSetRate(channel, rate);
    ndspChnSetFormat(channel, NDSP_FORMAT_MONO_PCM16);

    float mix[12] = {0};
    mix[0] = 1.0f;  // left
    mix[1] = 1.0f;  // right
    ndspChnSetMix(channel, mix);

    ndspWaveBuf *buf = &channelWaveBuf[channel];
    memset(buf, 0, sizeof(*buf));
    buf->data_pcm16 = base + sampleOffset;
    buf->nsamples = sampleCount;
    buf->looping = loop ? true : false;
    ndspChnWaveBufAdd(channel, buf);
}

void ctru_stop_channel(int channel) {
    if (channel < 0 || channel >= CTRU_NDSP_CHANNEL_COUNT) return;
    ndspChnWaveBufClear(channel);
    ndspChnReset(channel);
}

//---------------------------------------------------------------------------------
// Top-screen present -- see shim.h's module doc for why this transposes and
// centers. Celeste's canvas (128x128) is much smaller than the physical top
// screen (400x240 logical), unlike junkbot-swift's 3DS port, whose bottom-screen
// canvas fills the whole physical screen and needs no centering/clearing.
//---------------------------------------------------------------------------------
void ctru_present_top(const uint16_t *canvas, int canvasWidth, int canvasHeight,
                      int offsetX, int offsetY) {
    u16 fbWidth = 0, fbHeight = 0;
    uint16_t *fb = (uint16_t *)gfxGetFramebuffer(GFX_TOP, GFX_LEFT, &fbWidth, &fbHeight);
    if (!fb) return;

    // fbWidth/fbHeight are the *physical* (portrait) dimensions -- fbWidth is
    // the screen's logical height (240) and fbHeight is its logical width (400).
    int screenLogicalHeight = fbWidth;
    int screenLogicalWidth = fbHeight;

    memset(fb, 0, (size_t)fbWidth * fbHeight * sizeof(uint16_t));

    for (int y = 0; y < canvasHeight; y++) {
        int logicalY = offsetY + y;
        if (logicalY < 0 || logicalY >= screenLogicalHeight) continue;
        const uint16_t *srcRow = canvas + y * canvasWidth;
        int dstRow = screenLogicalHeight - 1 - logicalY;
        for (int x = 0; x < canvasWidth; x++) {
            int logicalX = offsetX + x;
            if (logicalX < 0 || logicalX >= screenLogicalWidth) continue;
            fb[logicalX * screenLogicalHeight + dstRow] = srcRow[x];
        }
    }

    gfxFlushBuffers();
    gfxSwapBuffers();
}
