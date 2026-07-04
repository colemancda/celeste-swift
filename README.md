# celeste-swift

Celeste Classic ported to Swift, from the [ccleste](https://github.com/lemon-sherbet/ccleste) C
port of the original PICO-8 cart by Matt Thorson & Noel Berry.

## Structure

- `Sources/CelesteCore/` — the gameplay engine, a line-by-line port of `celeste.c`. Platform
  agnostic: it knows nothing about SDL, SpriteKit, windows, or files. A host provides:
  - `CelesteRenderer` — draw primitives (`spr`/`rectfill`/`circfill`/`print`/`line`/`pal`/`camera`)
    at native PICO-8 resolution (128x128, 16-color palette indices).
  - `CelesteAudio` — `music(index:fadeMs:)` / `sfx(_:)`.
  - `CelesteInputState` — a 6-button bitmask (left/right/up/down/jump/dash), set once per frame.
  - `Sources/CelesteCore/Generated/` holds the game's built-in assets (tilemap, sprite sheet, font)
    converted from `tilemap.h`/`gfx.bmp`/`font.bmp`, plus the base PICO-8 palette.

  This is a symlink into `ports/Darwin/CelesteMobile.swiftpm/Sources/CelesteCore/`, its canonical
  location (mirroring junkbot-swift's layout) — that's the one App Playgrounds/Xcode can treat as
  a single self-contained `.swiftpm` document without an external relative-path dependency.

- `ports/SDL2/` — a desktop port using [PureSwift/SDL](https://github.com/PureSwift/SDL). Renders
  the engine's palette-indexed draw calls through a software 128x128 framebuffer uploaded to a
  single stretched texture each frame (mirroring ccleste's own `sdl12main.c` approach), and plays
  `data/*.wav`/`*.ogg` via SDL2_mixer.

- `ports/Darwin/CelesteMobile.swiftpm/` — a SwiftUI + SpriteKit App Playground for iOS/iPadOS
  (macOS via `swift run` too). `SpriteKitRenderer` implements `CelesteRenderer` the same way as
  `ports/SDL2`'s `PixelRenderer` — a software 128x128 palette-indexed framebuffer, rebuilt as a
  `CGImage`/`SKTexture` once per frame and displayed on a single full-scene `SKSpriteNode` (no
  per-entity nodes, no `SKPhysicsBody` — `CelesteEngine` remains the sole simulation authority).
  Input is `GCKeyboard` polling (arrows + Z/C/N jump, X/V/M dash) plus an on-screen D-pad/buttons
  overlay for touch-only devices. Audio goes through `AVAudioPlayer`; the original `data/*.ogg`
  music tracks are pre-transcoded to `.caf` (`afconvert`) since AVFoundation has no Ogg Vorbis
  decoder on Apple platforms — sound effects stay as the original `.wav` files.

## Running

Desktop (SDL2):

```sh
cd ports/SDL2
swift run
```

Controls: arrow keys to move, Z/C/N to jump, X/V/M to dash.

Darwin (SpriteKit): open `ports/Darwin/CelesteMobile.swiftpm` in Xcode or the Swift Playgrounds
app and run it (iOS/iPadOS simulator or device), or `cd ports/Darwin/CelesteMobile.swiftpm &&
swift run` on macOS. Same keyboard controls as above, plus an on-screen D-pad/jump/dash overlay
on touch devices.
