#if canImport(UIKit)
import UIKit
import SpriteKit

/// Hosts the one `SKView`/`CelesteScene` the tvOS target presents. iOS has no equivalent target
/// here (that's `CelesteMobile.swiftpm`, an App Playground using SwiftUI's `SpriteView`
/// instead), but this stays UIKit-based (rather than tvOS-specific) in case a matching iOS Xcode
/// target is ever added alongside the Playground.
final class GameViewController: UIViewController {
    public override func loadView() {
        let skView = SKView(frame: UIScreen.main.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view = skView
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }
        skView.ignoresSiblingOrder = true
        let scale: CGFloat = 4
        let size = CGSize(width: CGFloat(SpriteKitRenderer.width) * scale, height: CGFloat(SpriteKitRenderer.height) * scale)
        let scene = CelesteScene(size: size)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)
    }

    #if os(iOS)
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    public override var prefersStatusBarHidden: Bool { true }
    #endif
}
#endif
