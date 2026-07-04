//---------------------------------------------------------------------------------
// shim.h -- shared C support for the Celeste 3DS port.
//
// Three jobs:
//   1. Fixed-arity wrappers around the console's variadic printf, which
//      Embedded Swift can import but not call directly.
//   2. NDSP (audio DSP) playback -- Embedded Swift can't touch the
//      `ndspWaveBuf` tagged union directly, so this owns wave-buffer storage
//      and the linear-memory copies NDSP's DMA requires (see shim.c).
//   3. A software-rasterizer present step: both LCD framebuffers are stored
//      column-major (physically portrait panels rotated for landscape
//      display), so writing our row-major 128x128 game canvas straight into
//      one would come out sideways -- ctru_present_top transposes it, and
//      (unlike ccleste's own SDL/libctru port, whose bottom screen is left
//      blank/console) centers it within the wider 400x240 top screen.
//---------------------------------------------------------------------------------
#ifndef SWIFT_3DS_SHIM_H
#define SWIFT_3DS_SHIM_H

#include <stdint.h>

// printf(fmt, a)        -- one 32-bit argument (use for %d, %u, %x, ...).
void ctru_printf_1i(const char *fmt, int a);

// Print an already-formatted string (no varargs).
void ctru_puts(const char *s);

// --- Audio (NDSP) ------------------------------------------------------------

// Initializes NDSP and copies the bin2s-embedded sfx.bin/music.bin blobs
// into linear (DSP-DMA-safe) memory. Call once at startup.
void ctru_audio_init(void);

// Plays `sampleCount` signed 16-bit PCM mono samples starting at the given
// element offset into sfx.bin (`bank` 0) or music.bin (`bank` 1) on NDSP
// channel `channel`, looping the whole buffer forever if `loop` is set.
void ctru_play_pcm16(int channel, int bank, unsigned sampleOffset, unsigned sampleCount,
                      float rate, int loop);

// Stops whatever is playing (if anything) on the given NDSP channel.
void ctru_stop_channel(int channel);

// --- Top-screen present -----------------------------------------------------

// Clears the top screen, then transposes `canvas` (canvasWidth x canvasHeight,
// row-major RGB565) into the top LCD's current hardware framebuffer, centered
// at (offsetX, offsetY) in the screen's logical 400x240 landscape space, and
// flips it.
void ctru_present_top(const uint16_t *canvas, int canvasWidth, int canvasHeight,
                       int offsetX, int offsetY);

#endif // SWIFT_3DS_SHIM_H
