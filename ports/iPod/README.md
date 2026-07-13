# Celeste Classic for iPod Nano 2G (Rockbox)

A [Rockbox](https://www.rockbox.org) plugin port of the shared `CelesteCore`
engine, compiled as **Embedded Swift for `armv4t-none-none-eabi`** — the Nano
2G's FPU-less ARM940T — and linked into `celeste.rock` by Rockbox's own build
system. The game renders at its native 128×128 centered on the 176×132 RGB565
LCD and runs at a fixed 30 Hz with the CPU boosted to ~191 MHz.

Architecturally this is the inverse of `ports/3DS` (where Swift owns `main`):
Rockbox calls the C `plugin_start()` in [plugin/celeste.c](plugin/celeste.c),
which owns the loop, buttons, pacing and blitting, and calls three `@_cdecl`
Swift entry points (`celeste_init` / `celeste_frame` / `celeste_restart`,
[source/Plugin.swift](source/Plugin.swift)). Everything the armv4t Swift
output needs that a plugin doesn't have — allocator, non-atomic `__atomic_*`
stubs, `memcpy` family, `sinf`/`fmodf` — lives in
[plugin/rockbox_shim.c](plugin/rockbox_shim.c).

## Controls

| Input | Action |
|---|---|
| LEFT / RIGHT | move |
| MENU | up (dash direction) |
| PLAY | down (dash direction) |
| SELECT | jump |
| **flick the scroll wheel** | dash |
| HOLD switch | pause menu (resume / restart / quit) |

Up/down held within the last 4 frames still count at the instant a dash
fires, so diagonals don't demand perfectly simultaneous presses.

## Prerequisites

- **Swift toolchain with an `armv4t-none-none-eabi` embedded stdlib** —
  swift-6.3.2-RELEASE or newer (`swiftly install 6.3.2` or a toolchain from
  swift.org). Point `SWIFT_TOOLCHAIN` at it if it isn't at the default path
  in the Makefile.
- **Docker** — the `arm-elf-eabi-gcc` 9.5.0 cross-compiler is built by
  Rockbox's `rockboxdev.sh` inside a Debian container into the `rbdev`
  Docker volume (GCC 9.5 can't be built with an arm64 macOS host natively).

## Building

```sh
cd ports/iPod
make toolchain   # once, ~40 min: arm-elf-eabi-gcc into the rbdev volume
make rock        # libceleste.a (host swiftc) + Rockbox in-tree build
make install IPOD=/Volumes/<your-ipod>   # → /.rockbox/rocks/games/celeste.rock
```

Then on the device: **Plugins → Games → celeste**.

Useful individual targets: `make swift` (just the audited `libceleste.a`),
`make sim` (Rockbox UI simulator with the C test-pattern stub — needs SDL on
the host), `make rockbox-tree` (fetch the pinned Rockbox checkout).

## How the pieces fit

1. `make swift` compiles all of `Sources/CelesteCore` + `source/*.swift` in
   one `-wmo -Osize` invocation (like the 3DS port), audits the object's
   undefined symbols against the shim's allowlist
   ([scripts/check-undefined.sh](scripts/check-undefined.sh)), and archives
   `build/libceleste.a` with `llvm-ar`.
2. [scripts/get-rockbox.sh](scripts/get-rockbox.sh) pins a Rockbox SHA
   (gitignored checkout under `rockbox/`);
   [scripts/sync-plugin.sh](scripts/sync-plugin.sh) copies `plugin/` +
   `libceleste.a` to `apps/plugins/celeste/` and registers the plugin in
   `SUBDIRS`/`CATEGORIES`.
3. Rockbox's `configure --target=ipodnano2g --type=n` + `make` builds
   `celeste.rock`; [plugin/celeste.make](plugin/celeste.make) links the
   prebuilt `.a` plus the tree's TLSF allocator (the same mechanic
   `mikmod`/`pdbox` use).

## Audio status

Silent for now, by design: the PCM assets are ~9 MB and can't live in the
512 KB plugin buffer. `RockboxAudio` already routes `music`/`sfx` calls to
`rb_audio_*` C stubs, so the planned phases (SFX from a
`/.rockbox/celeste/sfx.bin` blob mixed in a `pcm_play_data` callback, then
music with fades) touch only C. The mixer must never call Swift — see the
threading invariant in `rockbox_shim.c`.

## Targets other than the Nano 2G

Nothing here is Nano-specific except the default `configure` target: the
SUBDIRS guard enables any 16-bit color target with a 176×132+ LCD and the
keymap only assumes an iPod-style click wheel. Other clickwheel iPods
(4G color/Photo, Mini, Video, Nano 1G) should work with a different
`--target`.
