# celeste-swift

Celeste Classic ported to Swift, from the [ccleste](https://github.com/lemon-sherbet/ccleste) C
port of the original PICO-8 cart by Matt Thorson & Noel Berry.

## Structure

- `Sources/CelesteCore/` — the gameplay engine, a line-by-line port of `celeste.c`. Platform
  agnostic: it knows nothing about SDL, windows, or files. A host provides:
  - `CelesteRenderer` — draw primitives (`spr`/`rectfill`/`circfill`/`print`/`line`/`pal`/`camera`)
    at native PICO-8 resolution (128x128, 16-color palette indices).
  - `CelesteAudio` — `music(index:fadeMs:)` / `sfx(_:)`.
  - `CelesteInputState` — a 6-button bitmask (left/right/up/down/jump/dash), set once per frame.
  - `Sources/CelesteCore/Generated/` holds the game's built-in assets (tilemap, sprite sheet, font)
    converted from `tilemap.h`/`gfx.bmp`/`font.bmp`, plus the base PICO-8 palette.
- `ports/SDL2/` — a desktop port using [PureSwift/SDL](https://github.com/PureSwift/SDL). Renders
  the engine's palette-indexed draw calls through a software 128x128 framebuffer uploaded to a
  single stretched texture each frame (mirroring ccleste's own `sdl12main.c` approach), and plays
  `data/*.wav`/`*.ogg` via SDL2_mixer.

## Running

```sh
cd ports/SDL2
swift run
```

Controls: arrow keys to move, Z/C/N to jump, X/V/M to dash.
