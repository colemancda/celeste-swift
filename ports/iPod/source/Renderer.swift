/// Software rasterizer for the iPod Nano 2G's LCD: executes `CelesteEngine`'s
/// `spr`/`rectfill`/`circfill`/`print`/`line`/`pal`/`camera` calls into a
/// 128x128 row-major RGB565 canvas (Celeste Classic's native PICO-8
/// resolution, drawn 1:1 -- it fits the 176x132 panel with borders).
///
/// Ported from `ports/3DS`'s `Renderer3DS` with two differences: the canvas is
/// owned by the C plugin (a static buffer passed through `celeste_init`, blitted
/// with `rb->lcd_bitmap` after each frame -- the Nano's framebuffer is row-major,
/// so there is no present/transpose step here), and palette lookups go through a
/// 16-entry RGB565 LUT rebuilt on `pal`/`palReset` instead of resolving
/// palette->RGB888->RGB565 per plotted pixel, which matters on a 191MHz ARM940T.
final class RockboxRenderer: CelesteRenderer {
    static let width = 128
    static let height = 128

    private let canvas: UnsafeMutablePointer<UInt16>

    /// `lut[a]` is the RGB565 color currently mapped to palette index `a`,
    /// maintained under pal(a,b) / palReset() (mirrors `paletteMap` in the
    /// other renderers, pre-resolved to the wire format).
    private var lut = [UInt16](repeating: 0, count: 16)
    private var cameraX = 0
    private var cameraY = 0

    init(canvas: UnsafeMutablePointer<UInt16>) {
        self.canvas = canvas
        canvas.update(repeating: 0, count: RockboxRenderer.width * RockboxRenderer.height)
        palReset()
    }

    @inline(__always)
    private static func rgb565(_ baseIndex: Int) -> UInt16 {
        let c = pico8BasePalette[baseIndex]
        let r = UInt16(c.r) >> 3
        let g = UInt16(c.g) >> 2
        let b = UInt16(c.b) >> 3
        return (r << 11) | (g << 5) | b
    }

    @inline(__always)
    private func plot(_ x: Int, _ y: Int, _ colorIndex: Int) {
        let px = x - cameraX
        let py = y - cameraY
        guard px >= 0, py >= 0, px < RockboxRenderer.width, py < RockboxRenderer.height else { return }
        canvas[px + py * RockboxRenderer.width] = lut[((colorIndex % 16) + 16) % 16]
    }

    // MARK: - CelesteRenderer

    func spr(_ sprite: Int, x: Float, y: Float, flipX: Bool, flipY: Bool) {
        guard sprite >= 0 else { return }
        let ix = Int(x), iy = Int(y)
        let sheetX = 8 * (sprite % 16)
        let sheetY = 8 * (sprite / 16)
        for row in 0..<8 {
            for col in 0..<8 {
                let srcX = sheetX + (flipX ? 7 - col : col)
                let srcY = sheetY + (flipY ? 7 - row : row)
                guard srcX < gfxWidth, srcY < gfxHeight else { continue }
                let idx = Int(gfxIndices[srcX + srcY * gfxWidth])
                if idx == 0 { continue }
                plot(ix + col, iy + row, idx)
            }
        }
    }

    func circfill(x: Float, y: Float, r: Float, color: Int) {
        let cx = Int(x), cy = Int(y), radius = Int(r)
        if radius <= 1 {
            fillRect(cx - 1, cy, 3, 1, color)
            fillRect(cx, cy - 1, 1, 3, color)
        } else if radius <= 2 {
            fillRect(cx - 2, cy - 1, 5, 3, color)
            fillRect(cx - 1, cy - 2, 3, 5, color)
        } else if radius <= 3 {
            fillRect(cx - 3, cy - 1, 7, 3, color)
            fillRect(cx - 1, cy - 3, 3, 7, color)
            fillRect(cx - 2, cy - 2, 5, 5, color)
        } else {
            var f = 1 - radius
            var ddFx = 1
            var ddFy = -2 * radius
            var px = 0
            var py = radius

            drawLine(cx, cy - py, cx, cy + radius, color)
            drawLine(cx + radius, cy, cx - radius, cy, color)

            while px < py {
                if f >= 0 {
                    py -= 1
                    ddFy += 2
                    f += ddFy
                }
                px += 1
                ddFx += 2
                f += ddFx

                drawLine(cx + px, cy + py, cx - px, cy + py, color)
                drawLine(cx + px, cy - py, cx - px, cy - py, color)
                drawLine(cx + py, cy + px, cx - py, cy + px, color)
                drawLine(cx + py, cy - px, cx - py, cy - px, color)
            }
        }
    }

    func rectfill(x0: Float, y0: Float, x1: Float, y1: Float, color: Int) {
        let ix0 = Int(x0), iy0 = Int(y0), ix1 = Int(x1), iy1 = Int(y1)
        fillRect(ix0, iy0, ix1 - ix0 + 1, iy1 - iy0 + 1, color)
    }

    private func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ color: Int) {
        guard w > 0, h > 0 else { return }
        // Clip once, then fill rows with the resolved color directly; full-canvas
        // rectfills (background, letterbox) are the hottest draw calls we get.
        let x0 = max(x - cameraX, 0)
        let y0 = max(y - cameraY, 0)
        let x1 = min(x - cameraX + w, RockboxRenderer.width)
        let y1 = min(y - cameraY + h, RockboxRenderer.height)
        guard x0 < x1, y0 < y1 else { return }
        let c = lut[((color % 16) + 16) % 16]
        for row in y0..<y1 {
            let base = canvas + row * RockboxRenderer.width
            for col in x0..<x1 {
                base[col] = c
            }
        }
    }

    func line(x0: Float, y0: Float, x1: Float, y1: Float, color: Int) {
        drawLine(Int(x0), Int(y0), Int(x1), Int(y1), color)
    }

    private func drawLine(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ color: Int) {
        var (x0, y0, x1, y1) = (x0, y0, x1, y1)
        let dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1
        let dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1
        var err = dx + dy
        while true {
            plot(x0, y0, color)
            if x0 == x1 && y0 == y1 { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; x0 += sx }
            if e2 <= dx { err += dx; y0 += sy }
        }
    }

    func print(_ text: String, x: Float, y: Float, color: Int) {
        var cx = Int(x)
        let iy = Int(y)
        for scalar in text.unicodeScalars {
            let c = Int(scalar.value) & 0x7F
            let sheetX = 8 * (c % 16)
            let sheetY = 8 * (c / 16)
            for row in 0..<8 {
                for col in 0..<8 {
                    guard sheetX + col < fontWidth, sheetY + row < fontHeight else { continue }
                    let idx = fontIndices[(sheetX + col) + (sheetY + row) * fontWidth]
                    if idx == 0 { continue }
                    plot(cx + col, iy + row, color)
                }
            }
            cx += 4
        }
    }

    func pal(_ a: Int, _ b: Int) {
        guard a >= 0, a < 16, b >= 0, b < 16 else { return }
        lut[a] = RockboxRenderer.rgb565(b)
    }

    func palReset() {
        for i in 0..<16 {
            lut[i] = RockboxRenderer.rgb565(i)
        }
    }

    func camera(x: Int, y: Int) {
        cameraX = x
        cameraY = y
    }
}
