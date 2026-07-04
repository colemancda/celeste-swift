//---------------------------------------------------------------------------------
// assets.h -- extern declarations for the bin2s-embedded audio blobs, plus
// stable-pointer accessors for Swift.
//
// A C global array imports into Swift as a tuple (a *copy*), so
// `withUnsafeBytes(of:)` would only yield a temporary; these accessors return
// the address of the real linked symbol, valid for the program's lifetime.
// Symbol names follow bin2s's convention for `sfx.bin` / `music.bin`. Unlike
// junkbot-swift's 3DS port, sprite/font/tilemap data isn't embedded this way at
// all -- CelesteCore's `Generated/` Swift arrays (tiny, ~8-11KB each) are just
// compiled straight into the ELF's .rodata like any other Swift constant.
//---------------------------------------------------------------------------------
#ifndef SWIFT_3DS_ASSETS_H
#define SWIFT_3DS_ASSETS_H

#include <stdint.h>

extern const uint8_t sfx_bin[];
extern const uint32_t sfx_bin_size;
extern const uint8_t music_bin[];
extern const uint32_t music_bin_size;

static inline const void *ctru_asset_sfx_bin(void) { return sfx_bin; }
static inline uint32_t ctru_asset_sfx_bin_size(void) { return sfx_bin_size; }
static inline const void *ctru_asset_music_bin(void) { return music_bin; }
static inline uint32_t ctru_asset_music_bin_size(void) { return music_bin_size; }

#endif // SWIFT_3DS_ASSETS_H
