import XCTest
@testable import CelesteCore

final class NullRenderer: CelesteRenderer {
    func spr(_ sprite: Int, x: Float, y: Float, flipX: Bool, flipY: Bool) {}
    func circfill(x: Float, y: Float, r: Float, color: Int) {}
    func rectfill(x0: Float, y0: Float, x1: Float, y1: Float, color: Int) {}
    func print(_ text: String, x: Float, y: Float, color: Int) {}
    func line(x0: Float, y0: Float, x1: Float, y1: Float, color: Int) {}
    func pal(_ a: Int, _ b: Int) {}
    func palReset() {}
    func camera(x: Int, y: Int) {}
}

final class NullAudio: CelesteAudio {
    func music(index: Int, fadeMs: Int) {}
    func sfx(_ id: Int) {}
}

final class EngineSmokeTests: XCTestCase {
    func testRunsManyFramesWithoutCrashing() {
        let engine = CelesteEngine(renderer: NullRenderer(), audio: NullAudio(), seed: 1)
        engine.start()

        for frame in 0..<3000 {
            var input = CelesteInputState()
            // Nudge through the title screen, then hold right + occasionally jump/dash so
            // the player actually moves through rooms and exercises collision/entity logic.
            if frame < 5 {
                input.set(.jump, true)
            }
            input.set(.right, true)
            if frame % 30 == 0 { input.set(.jump, true) }
            if frame % 47 == 0 { input.set(.dash, true) }
            engine.input = input
            engine.update()
            engine.draw()
        }
    }
}
