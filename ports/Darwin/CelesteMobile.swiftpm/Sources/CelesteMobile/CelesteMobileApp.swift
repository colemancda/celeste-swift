import SwiftUI
import SpriteKit
// `SpriteView` lives in this separate underscored SDK module rather than being re-exported by
// `SpriteKit` itself - without this import, plain SwiftPM builds (unlike an Xcode app target,
// which links it implicitly) fail to resolve `SpriteView` below.
import _SpriteKit_SwiftUI

/// App Playground entry point. Presents the single `CelesteScene` via SwiftUI's `SpriteView`
/// rather than a `UIViewControllerRepresentable`-wrapped `SKView` - junkbot-swift's
/// `GameViewController` exists to share SpriteKit setup with a separate tvOS Xcode target, which
/// this port doesn't have, so there's nothing to share and `SpriteView` alone is simpler.
@main
struct CelesteMobileApp: App {
    /// Celeste Classic's native resolution (128x128) at a 4x integer scale, matching
    /// `ports/SDL2`'s default window size. `.aspectFit` (below) scales this uniformly to fill
    /// the actual screen without distorting the square PICO-8 canvas.
    private static let sceneSize = CGSize(width: 128 * 4, height: 128 * 4)

    var body: some Scene {
        WindowGroup {
            SpriteView(scene: {
                let scene = CelesteScene(size: Self.sceneSize)
                scene.scaleMode = .aspectFit
                return scene
            }())
            .ignoresSafeArea()
            #if os(iOS)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            #endif
        }
    }
}
