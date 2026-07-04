// The rendering boundary between CelesteCore and a platform port, mirroring
// the P8spr/P8circfill/P8rectfill/P8print/P8line/P8pal/P8camera callbacks in
// celeste.c. All coordinates and colors are in native PICO-8 space: a 128x128
// canvas addressed in pixels, with palette indices 0-15. Camera offsetting is
// the renderer's responsibility (as in the original SDL platform layer),
// applied at draw time based on the last `camera(x:y:)` call.
public protocol CelesteRenderer: AnyObject {
    /// Draw one 8x8 sprite from the built-in Celeste Classic sprite sheet.
    /// `sprite` indexes a 16-column grid (see `gfxIndices`/`gfxWidth`).
    func spr(_ sprite: Int, x: Float, y: Float, flipX: Bool, flipY: Bool)

    func circfill(x: Float, y: Float, r: Float, color: Int)
    func rectfill(x0: Float, y0: Float, x1: Float, y1: Float, color: Int)
    func print(_ text: String, x: Float, y: Float, color: Int)
    func line(x0: Float, y0: Float, x1: Float, y1: Float, color: Int)

    /// Remap palette entry `a` to the base-palette color at index `b`.
    func pal(_ a: Int, _ b: Int)
    /// Restore the identity palette mapping.
    func palReset()

    /// Set the camera offset applied to all subsequent draw calls, in pixels.
    func camera(x: Int, y: Int)
}

/// Audio boundary, mirroring the P8music/P8sfx callbacks.
public protocol CelesteAudio: AnyObject {
    /// Play/crossfade to music track `index` (a multiple of 10, or -1 to stop) over `fadeMs`.
    func music(index: Int, fadeMs: Int)
    /// Fire-and-forget sound effect by id.
    func sfx(_ id: Int)
}
