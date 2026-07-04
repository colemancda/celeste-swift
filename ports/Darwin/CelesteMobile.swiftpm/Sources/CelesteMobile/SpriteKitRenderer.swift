import SpriteKit
import CoreGraphics
import CelesteCore

/// Implements `CelesteRenderer` as a software 128x128 indexed-color framebuffer, converted to a
/// `CGImage`/`SKTexture` once per frame and displayed on a single full-scene `SKSpriteNode`.
///
/// This mirrors `ports/SDL2`'s `PixelRenderer` (same rationale: ccleste's own SDL platform layer
/// draws everything through a runtime-remappable 16-color palette rather than fixed RGB, so
/// sprite pixels are palette-index lookups here too, not baked-in colors/textures) rather than
/// the more typical SpriteKit approach of one `SKSpriteNode`+texture per game entity - PICO-8's
/// `pal(a,b)` mid-frame palette swaps (used for the player's hair color and the title-screen
/// flash) don't map cleanly onto SpriteKit's node/texture model, but do onto "recolor a palette
/// table, then rasterize" exactly like the original.
final class SpriteKitRenderer: CelesteRenderer {
    static let width = 128
    static let height = 128

    /// RGBA8, row-major, `width * height * 4` bytes.
    private var framebuffer = [UInt8](repeating: 0, count: SpriteKitRenderer.width * SpriteKitRenderer.height * 4)
    /// `paletteMap[a] = b` mirrors `palette[a] = base_palette[b]` from pal(a,b).
    private var paletteMap: [Int] = Array(0..<16)
    private var cameraX = 0
    private var cameraY = 0

    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    private func resolvedColor(_ colorIndex: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        pico8BasePalette[paletteMap[((colorIndex % 16) + 16) % 16]]
    }

    private func plot(_ x: Int, _ y: Int, _ colorIndex: Int) {
        let px = x - cameraX
        let py = y - cameraY
        guard px >= 0, py >= 0, px < SpriteKitRenderer.width, py < SpriteKitRenderer.height else { return }
        let color = resolvedColor(colorIndex)
        let offset = (px + py * SpriteKitRenderer.width) * 4
        framebuffer[offset] = color.r
        framebuffer[offset + 1] = color.g
        framebuffer[offset + 2] = color.b
        framebuffer[offset + 3] = 255
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
                if idx == 0 { continue } // color-keyed transparent, matches Xblit's `if (p)` check
                plot(ix + col, iy + row, idx)
            }
        }
    }

    func circfill(x: Float, y: Float, r: Float, color: Int) {
        let cx = Int(x), cy = Int(y), radius = Int(r)
        // Mirrors pico8emu's CELESTE_P8_CIRCFILL: ccleste only ever needs r<=2 in practice
        // (hair segments, the orb ring uses r=1), but the general midpoint algorithm below
        // covers larger radii too, should any ever be requested.
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
        for row in 0..<h {
            for col in 0..<w {
                plot(x + col, y + row, color)
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
                    // p8_print's Xblit call passes a non-zero override color, so every opaque
                    // glyph pixel draws in `color` regardless of the font bitmap's own index.
                    plot(cx + col, iy + row, color)
                }
            }
            cx += 4
        }
    }

    func pal(_ a: Int, _ b: Int) {
        guard a >= 0, a < 16, b >= 0, b < 16 else { return }
        paletteMap[a] = b
    }

    func palReset() {
        paletteMap = Array(0..<16)
    }

    func camera(x: Int, y: Int) {
        cameraX = x
        cameraY = y
    }

    // MARK: - presentation

    /// Builds an `SKTexture` from the current framebuffer contents. Call once per frame after
    /// `CelesteEngine.draw()` and assign it to the display node.
    func texture() -> SKTexture {
        let data = Data(framebuffer)
        let provider = CGDataProvider(data: data as CFData)!
        let image = CGImage(
            width: SpriteKitRenderer.width,
            height: SpriteKitRenderer.height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: SpriteKitRenderer.width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .nearest
        return texture
    }
}
