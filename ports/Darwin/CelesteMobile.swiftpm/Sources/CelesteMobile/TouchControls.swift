#if canImport(UIKit)
import SpriteKit
import UIKit
import CelesteCore

/// On-screen touch controls for iOS/iPadOS (no physical keyboard assumed) - a D-pad in the
/// bottom-left and jump/dash buttons in the bottom-right, drawn directly in the scene's own
/// coordinate space (fixed logical size, same as the framebuffer display node) so they scale
/// and position consistently regardless of the device's actual screen size/aspect ratio.
@MainActor
final class TouchControls {
    private struct Zone {
        let button: CelesteButton
        let center: CGPoint
        let radius: CGFloat
    }

    private var zones: [Zone] = []
    /// Which button (if any) each active touch currently maps to - a touch may slide between
    /// zones (e.g. dragging from "left" to "left+up" on the D-pad), so this is recomputed on
    /// every move, not just on touch-down.
    private var touchButtons: [ObjectIdentifier: CelesteButton] = [:]

    private(set) var state = CelesteInputState()

    init(in scene: SKScene) {
        let size = scene.size
        let pad: CGFloat = size.width * 0.06
        let buttonRadius = size.width * 0.075
        let dpadRadius = size.width * 0.06
        let dpadCenter = CGPoint(x: pad + dpadRadius * 2.2, y: pad + dpadRadius * 2.2)

        addZone(.left, center: CGPoint(x: dpadCenter.x - dpadRadius * 1.6, y: dpadCenter.y), radius: dpadRadius, in: scene)
        addZone(.right, center: CGPoint(x: dpadCenter.x + dpadRadius * 1.6, y: dpadCenter.y), radius: dpadRadius, in: scene)
        addZone(.up, center: CGPoint(x: dpadCenter.x, y: dpadCenter.y + dpadRadius * 1.6), radius: dpadRadius, in: scene)
        addZone(.down, center: CGPoint(x: dpadCenter.x, y: dpadCenter.y - dpadRadius * 1.6), radius: dpadRadius, in: scene)

        let actionCenter = CGPoint(x: size.width - pad - buttonRadius, y: pad + buttonRadius * 1.2)
        addZone(.dash, center: CGPoint(x: actionCenter.x - buttonRadius * 1.3, y: actionCenter.y), radius: buttonRadius, in: scene, label: "X")
        addZone(.jump, center: CGPoint(x: actionCenter.x + buttonRadius * 1.3, y: actionCenter.y + buttonRadius * 0.6), radius: buttonRadius, in: scene, label: "Z")
    }

    private func addZone(_ button: CelesteButton, center: CGPoint, radius: CGFloat, in scene: SKScene, label: String? = nil) {
        zones.append(Zone(button: button, center: center, radius: radius))
        let node = SKShapeNode(circleOfRadius: radius)
        node.position = center
        node.fillColor = SKColor.white.withAlphaComponent(0.15)
        node.strokeColor = SKColor.white.withAlphaComponent(0.4)
        node.lineWidth = 2
        node.zPosition = 1000
        if let label {
            let text = SKLabelNode(text: label)
            text.fontSize = radius
            text.fontColor = SKColor.white.withAlphaComponent(0.6)
            text.verticalAlignmentMode = .center
            node.addChild(text)
        } else {
            let arrows: [CelesteButton: String] = [.left: "\u{25c0}", .right: "\u{25b6}", .up: "\u{25b2}", .down: "\u{25bc}"]
            if let glyph = arrows[button] {
                let text = SKLabelNode(text: glyph)
                text.fontSize = radius
                text.fontColor = SKColor.white.withAlphaComponent(0.6)
                text.verticalAlignmentMode = .center
                node.addChild(text)
            }
        }
        scene.addChild(node)
    }

    private func button(at point: CGPoint) -> CelesteButton? {
        for zone in zones {
            let dx = point.x - zone.center.x
            let dy = point.y - zone.center.y
            if dx * dx + dy * dy <= zone.radius * zone.radius {
                return zone.button
            }
        }
        return nil
    }

    private func recompute() {
        var s = CelesteInputState()
        for button in touchButtons.values {
            s.set(button, true)
        }
        state = s
    }

    func touchesBegan(_ touches: Set<UITouch>, in scene: SKScene) {
        for touch in touches {
            if let button = button(at: touch.location(in: scene)) {
                touchButtons[ObjectIdentifier(touch)] = button
            }
        }
        recompute()
    }

    func touchesMoved(_ touches: Set<UITouch>, in scene: SKScene) {
        for touch in touches {
            touchButtons[ObjectIdentifier(touch)] = button(at: touch.location(in: scene))
        }
        recompute()
    }

    func touchesEnded(_ touches: Set<UITouch>) {
        for touch in touches {
            touchButtons.removeValue(forKey: ObjectIdentifier(touch))
        }
        recompute()
    }
}
#endif
