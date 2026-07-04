//---------------------------------------------------------------------------------
//
//  Celeste Classic for Nintendo 3DS -- Embedded Swift ARM11 binary.
//
//  The game renders on the top screen at 1:1 scale (Celeste Classic's native
//  128x128 PICO-8 resolution, centered - see source/Renderer.swift); the bottom
//  screen hosts a simple text console with controls/status, mirroring ccleste's
//  own libctru/SDL 3DS port (which likewise only draws to the top screen).
//
//    Circle Pad / D-pad / C-stick   move
//    A                              jump
//    B or X                         dash
//    START                          return to title screen
//
//---------------------------------------------------------------------------------

import CTRU

func consolePrint(_ s: StaticString) {
    ctru_puts(UnsafeRawPointer(s.utf8Start).assumingMemoryBound(to: CChar.self))
}

// MARK: - Video / audio setup

gfxInitDefault()
gfxSetScreenFormat(GFX_TOP, GSP_RGB565_OES)
consoleInit(GFX_BOTTOM, nil)

consolePrint("\u{1b}[2J\u{1b}[0;0H CELESTE CLASSIC\n\n")
consolePrint(" Circle Pad/D-pad  move\n")
consolePrint(" A                 jump\n")
consolePrint(" B or X            dash\n")
consolePrint(" START             title screen\n")

let renderer = Renderer3DS()
let audio = Audio3DS()
let engine = CelesteEngine(renderer: renderer, audio: audio)
engine.start()

// MARK: - Main loop
// ccleste runs its simulation at a fixed 30Hz; the 3DS's display refreshes at
// ~60Hz, so tick every other VBlank.

var tickAccumulator: Int32 = 0

while aptMainLoop() {
    // gspWaitForVBlank() is a function-like macro the Clang importer can't
    // surface; call what it expands to (gspWaitForEvent) directly.
    gspWaitForEvent(GSPGPU_EVENT_VBlank0, true)
    hidScanInput()
    let pressed = hidKeysDown()
    let held = hidKeysHeld()

    if pressed & KEY_START != 0 {
        engine.start()
    }

    var input = CelesteInputState()
    input.set(.left, held & (KEY_DLEFT | KEY_CPAD_LEFT | KEY_CSTICK_LEFT) != 0)
    input.set(.right, held & (KEY_DRIGHT | KEY_CPAD_RIGHT | KEY_CSTICK_RIGHT) != 0)
    input.set(.up, held & (KEY_DUP | KEY_CPAD_UP | KEY_CSTICK_UP) != 0)
    input.set(.down, held & (KEY_DDOWN | KEY_CPAD_DOWN | KEY_CSTICK_DOWN) != 0)
    input.set(.jump, held & KEY_A != 0)
    input.set(.dash, held & (KEY_B | KEY_X) != 0)
    engine.input = input

    tickAccumulator += 30
    if tickAccumulator >= 60 {
        tickAccumulator -= 60
        engine.update()
    }

    engine.draw()
    renderer.present()
}

gfxExit()
