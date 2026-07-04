import SpriteKit
import Foundation
import CelesteCore

/// The one `SKScene` this app presents. Drives `CelesteEngine.update()`/`draw()` at a fixed 30Hz
/// tick rate (matching ccleste's own `mainLoop()`) from SpriteKit's `update(_:)` callback, and
/// displays the resulting frame via `SpriteKitRenderer.texture()` on a single full-scene sprite -
/// there is deliberately no `SKPhysicsBody`/per-entity node usage anywhere; `CelesteEngine`
/// remains the sole simulation authority, same as `ports/SDL2`.
final class CelesteScene: SKScene {
    private let renderer = SpriteKitRenderer()
    private let audio = AudioBackend()
    private var engine: CelesteEngine!

    private let displayNode = SKSpriteNode()
    #if canImport(UIKit)
    private var touchControls: TouchControls!
    #endif

    private let tickIntervalNanoseconds: UInt64 = 1_000_000_000 / 30
    private var lastTickTime: UInt64 = 0
    private var didStart = false

    override func didMove(to view: SKView) {
        guard !didStart else { return }
        didStart = true

        backgroundColor = .black

        displayNode.size = size
        displayNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
        // No manual Y-flip needed here: SKTexture(cgImage:) already reorients a top-down CGImage
        // to display right-side up on a standard (bottom-left-origin) SKSpriteNode. An earlier
        // version added `displayNode.yScale = -1` on top of that, which double-flipped the frame
        // and rendered the game upside down.
        addChild(displayNode)

        #if canImport(UIKit)
        touchControls = TouchControls(in: self)
        #endif

        engine = CelesteEngine(renderer: renderer, audio: audio)
        engine.start()

        lastTickTime = DispatchTime.now().uptimeNanoseconds
    }

    override func update(_ currentTime: TimeInterval) {
        guard didStart else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        while now - lastTickTime >= tickIntervalNanoseconds {
            lastTickTime += tickIntervalNanoseconds
            engine.input = currentInput()
            engine.update()
        }

        engine.draw()
        displayNode.texture = renderer.texture()
    }

    private func currentInput() -> CelesteInputState {
        var input = KeyboardInput.poll()
        #if canImport(UIKit)
        input.bits |= touchControls.state.bits
        #endif
        return input
    }

    #if canImport(UIKit)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchControls.touchesBegan(touches, in: self)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchControls.touchesMoved(touches, in: self)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchControls.touchesEnded(touches)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchControls.touchesEnded(touches)
    }
    #endif
}
