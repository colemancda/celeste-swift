//---------------------------------------------------------------------------------
//
//  Celeste Classic for iPod Nano 2G -- Embedded Swift compiled for
//  armv4t-none-none-eabi, linked into a Rockbox plugin.
//
//  Unlike the 3DS port (where Swift owns main()), Rockbox owns the process:
//  plugin/celeste.c's plugin_start() drives a 30Hz loop and calls the three
//  @_cdecl entry points below. All hardware access (LCD, buttons, timing,
//  audio) stays on the C side; Swift only simulates and rasterizes.
//
//  Threading invariant: every one of these entry points runs on the plugin's
//  main thread. That is what makes the non-atomic __atomic_* stubs in
//  rockbox_shim.c correct -- never call into Swift from any other context.
//
//---------------------------------------------------------------------------------

private var engine: CelesteEngine?

/// C passes a static 128x128 RGB565 buffer it owns (and later blits); seed
/// feeds the PICO-8 RNG so runs differ per boot (C uses current_tick).
@_cdecl("celeste_init")
public func celeste_init(_ canvas: UnsafeMutablePointer<UInt16>?, _ seed: UInt32) -> Int32 {
    guard let canvas else { return -1 }
    let renderer = RockboxRenderer(canvas: canvas)
    let e = CelesteEngine(renderer: renderer, audio: RockboxAudio(), seed: seed)
    e.start()
    engine = e
    return 0
}

/// One 30Hz frame: latch the 6-bit CelesteInputState mask (see Input.swift for
/// bit order: left/right/up/down/jump/dash), simulate, rasterize into the
/// canvas. C blits and paces afterwards.
@_cdecl("celeste_frame")
public func celeste_frame(_ buttons: UInt8) -> Int32 {
    guard let engine else { return -1 }
    engine.input = CelesteInputState(bits: buttons)
    engine.update()
    engine.draw()
    return 0
}

/// Pause-menu "Restart": back to the title screen, same engine instance.
@_cdecl("celeste_restart")
public func celeste_restart() {
    engine?.start()
}
