/*
 * rockbox_shim.h -- the C surface CelesteCore's Embedded Swift sees on Rockbox.
 *
 * This header is parsed twice, by two different compilers:
 *   1. swiftc's Clang importer (via module.modulemap, as the `RB` module,
 *      -ffreestanding, armv4t-none-none-eabi) when compiling the engine, and
 *   2. arm-elf-eabi-gcc when compiling rockbox_shim.c inside the Rockbox tree.
 * So it must stay self-contained: no plugin.h, no libc headers beyond what a
 * freestanding compiler provides. Mirrors the role ctru_umbrella.h plays for
 * the 3DS port, minus libctru (the iPod side keeps all hardware access in C).
 */
#ifndef CELESTE_ROCKBOX_SHIM_H
#define CELESTE_ROCKBOX_SHIM_H

/* libm gaps: Rockbox has no libm, so rockbox_shim.c carries small soft-float
 * implementations. PicoMath.swift only calls sinf/fmodf (see the canImport(RB)
 * branch there); floorf is declared for completeness. */
float sinf(float x);
float fmodf(float x, float y);
float floorf(float x);

/* Audio triggers, called by RockboxAudio (source/Audio.swift). No-ops until
 * the SFX/music phases land; the C mixer behind them never runs Swift (it
 * executes in IRQ context -- see the threading invariant in rockbox_shim.c). */
void rb_audio_sfx(int id);
void rb_audio_music(int index, int fade_ms);

/* Fixed-arity debug print (Embedded Swift can't call varargs). Splash-based;
 * compiled out unless CELESTE_DEBUG. */
void rb_puts(const char *s);

#endif /* CELESTE_ROCKBOX_SHIM_H */
