// PICO-8 runtime math emulation: the exact xorshift-like RNG used by PICO-8
// carts, plus small helpers (appr/sign/clamp/maybe) ported verbatim from
// celeste.c so that gameplay timing/randomness matches the original.

import Foundation

struct Pico8RNG {
    var seedLo: UInt32 = 0
    var seedHi: UInt32 = 1

    mutating func random(_ max: Int32) -> Int32 {
        if max == 0 { return 0 }
        seedHi = ((seedHi << 16) | (seedHi >> 16)) &+ seedLo
        seedLo = seedLo &+ seedHi
        return Int32(seedHi % UInt32(max))
    }

    mutating func seed(_ seed: UInt32) {
        var s = seed
        if s == 0 {
            seedHi = 0x60009755
            s = 0xdeadbeef
        } else {
            seedHi = s ^ 0xbead29ba
        }
        var i = 0x20
        while i > 0 {
            seedHi = ((seedHi << 16) | (seedHi >> 16)) &+ s
            s = s &+ seedHi
            i -= 1
        }
        seedLo = s
    }
}

enum PicoMath {
    static func modulo(_ a: Float, _ b: Float) -> Float {
        fmodf(fmodf(a, b) + b, b)
    }

    static func clamp(_ val: Float, _ a: Float, _ b: Float) -> Float {
        max(a, min(b, val))
    }

    static func appr(_ val: Float, _ target: Float, _ amount: Float) -> Float {
        val > target ? max(val - amount, target) : min(val + amount, target)
    }

    static func sign(_ v: Float) -> Float {
        v > 0 ? 1 : (v < 0 ? -1 : 0)
    }

    // https://pico-8.fandom.com/wiki/Math
    static func sin(_ x: Float) -> Float {
        -sinf(x * 6.2831853071796)
    }

    static func cos(_ x: Float) -> Float {
        -sin(x + 0.25)
    }
}
