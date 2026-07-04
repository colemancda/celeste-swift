import CSDL2
import SDL2Swift
import SDL2Mixer
import Foundation
import CelesteCore

// MARK: - Resource location

let dataDirectory: URL = {
    if let bundleURL = Bundle.module.url(forResource: "data", withExtension: nil) {
        return bundleURL
    }
    // Dev-time fallback: this file's own compile-time source path, walked up to
    // ports/SDL2/Sources/CelesteSDL2/Resources/data (mirrors the #filePath trick
    // used by ports/SDL2 in junkbot-swift's main.swift).
    return URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // main.swift
        .appendingPathComponent("Resources/data")
}()

// MARK: - SDL setup

do {
    try SDL.initialize(subSystems: [.video, .audio])
} catch {
    FileHandle.standardError.write(Data("SDL.initialize failed: \(error)\n".utf8))
    exit(1)
}
defer { SDL.quit() }

let scale: Int32 = 4
let windowWidth = Int32(PixelRenderer.width) * scale
let windowHeight = Int32(PixelRenderer.height) * scale

let window: SDLWindow
do {
    window = try SDLWindow(
        title: "Celeste Classic",
        frame: (x: .centered, y: .centered, width: Int(windowWidth), height: Int(windowHeight)),
        options: [.resizable])
} catch {
    FileHandle.standardError.write(Data("SDLWindow init failed: \(error)\n".utf8))
    exit(1)
}

let sdlRenderer: SDLRenderer
do {
    sdlRenderer = try SDLRenderer(window: window)
} catch {
    FileHandle.standardError.write(Data("SDLRenderer init failed: \(error)\n".utf8))
    exit(1)
}
try? sdlRenderer.setLogicalSize(width: Int32(PixelRenderer.width), height: Int32(PixelRenderer.height))
_ = SDL_RenderSetIntegerScale(sdlRenderer.unsafePointer, SDL_TRUE)

let pixelRenderer = PixelRenderer(renderer: sdlRenderer)

// MARK: - Audio

let audioAvailable: Bool = {
    do {
        try SDL.initializeMixer(formats: [.ogg])
    } catch {
        FileHandle.standardError.write(Data("SDL.initializeMixer failed: \(error)\n".utf8))
        return false
    }
    do {
        try SDL.openAudio()
    } catch {
        FileHandle.standardError.write(Data("SDL.openAudio failed: \(error)\n".utf8))
        return false
    }
    return true
}()
defer {
    if audioAvailable { SDL.closeAudio() }
    SDL.quitMixer()
}

let audioBackend = AudioBackend(dataDirectory: dataDirectory)

// MARK: - Engine

let engine = CelesteEngine(renderer: pixelRenderer, audio: audioBackend)
engine.start()

// MARK: - Input
// Mirrors sdl12main.c's key mapping: arrows for movement, Z/C/N for jump, X/V/M for dash.

var heldKeycodes: Set<Int32> = []

func sdlk(_ value: SDL_KeyCode) -> Int32 { Int32(bitPattern: value.rawValue) }

func updateInputState() {
    var input = CelesteInputState()
    input.set(.left, heldKeycodes.contains(sdlk(SDLK_LEFT)))
    input.set(.right, heldKeycodes.contains(sdlk(SDLK_RIGHT)))
    input.set(.up, heldKeycodes.contains(sdlk(SDLK_UP)))
    input.set(.down, heldKeycodes.contains(sdlk(SDLK_DOWN)))
    input.set(.jump, heldKeycodes.contains(sdlk(SDLK_z)) || heldKeycodes.contains(sdlk(SDLK_c)) || heldKeycodes.contains(sdlk(SDLK_n)))
    input.set(.dash, heldKeycodes.contains(sdlk(SDLK_x)) || heldKeycodes.contains(sdlk(SDLK_v)) || heldKeycodes.contains(sdlk(SDLK_m)))
    engine.input = input
}

// MARK: - Main loop
// ccleste runs its simulation at a fixed 30 Hz (Celeste_P8_update()/Celeste_P8_draw() once per
// tick); this reproduces that tick rate independent of display refresh rate.

let tickIntervalNanoseconds: UInt64 = 1_000_000_000 / 30
var lastTickTime = SDL.ticks

var running = true
while running {
    while let event = SDL.pollEvent() {
        switch event {
        case .quit:
            running = false
        case .keyDown(_, let keycode):
            heldKeycodes.insert(keycode.rawValue)
        case .keyUp(_, let keycode):
            heldKeycodes.remove(keycode.rawValue)
        default:
            break
        }
    }

    let now = SDL.ticks
    while now - lastTickTime >= tickIntervalNanoseconds {
        lastTickTime += tickIntervalNanoseconds
        updateInputState()
        engine.update()
    }

    engine.draw()

    try? sdlRenderer.setDrawColor(red: 0, green: 0, blue: 0, alpha: 255)
    try? sdlRenderer.clear()
    pixelRenderer.present()
    sdlRenderer.present()

    SDL.delay(nanoseconds: 1_000_000)
}
