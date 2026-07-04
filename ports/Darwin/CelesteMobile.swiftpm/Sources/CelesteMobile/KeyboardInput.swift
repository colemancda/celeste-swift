@preconcurrency import GameController
import CelesteCore

/// Physical-keyboard polling via `GameController.framework`'s `GCKeyboard`, which (unlike raw
/// key-event handling) works uniformly across macOS and iPadOS with an attached keyboard - the
/// same rationale as junkbot-swift's `ports/Darwin/.../GamepadInput.swift`. Mirrors ccleste's own
/// `sdl12main.c` mapping: arrows for movement, Z/C/N for jump, X/V/M for dash.
enum KeyboardInput {
    static func poll() -> CelesteInputState {
        var input = CelesteInputState()
        guard let keyboard = GCKeyboard.coalesced?.keyboardInput else { return input }

        func isPressed(_ code: GCKeyCode) -> Bool {
            keyboard.button(forKeyCode: code)?.isPressed ?? false
        }

        input.set(.left, isPressed(.leftArrow))
        input.set(.right, isPressed(.rightArrow))
        input.set(.up, isPressed(.upArrow))
        input.set(.down, isPressed(.downArrow))
        input.set(.jump, isPressed(.keyZ) || isPressed(.keyC) || isPressed(.keyN))
        input.set(.dash, isPressed(.keyX) || isPressed(.keyV) || isPressed(.keyM))
        return input
    }
}
