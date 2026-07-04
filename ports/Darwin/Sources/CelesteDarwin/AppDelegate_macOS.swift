#if os(macOS)
import Cocoa
import SpriteKit

/// macOS-only entry point: creates the window/`SKView`/`CelesteScene` directly (no
/// `GameViewController` - that's shared with tvOS instead, see `AppDelegate_tvOS.swift` and
/// `GameViewController.swift`, since `NSViewController`/`UIViewController` aren't the same type).
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    /// Overrides `NSApplicationDelegate`'s own default `@main`-compatible `static func main()`
    /// (which just calls the classic `NSApplicationMain` C entry point) - that default relies on
    /// a storyboard/nib to instantiate the delegate and assign it to `NSApp.delegate`, and this
    /// project has neither (pure-code SpriteKit app). Without this override, `NSApp.delegate`
    /// stays `nil` forever and `applicationDidFinishLaunching` never runs.
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Celeste Classic's native resolution (128x128) at a 4x integer scale, matching
        // `ports/SDL2`'s default window size and the iOS Playground's `CelesteMobileApp.swift`.
        let scale: CGFloat = 4
        let size = CGSize(width: CGFloat(SpriteKitRenderer.width) * scale, height: CGFloat(SpriteKitRenderer.height) * scale)
        let contentRect = NSRect(origin: .zero, size: size)

        window = NSWindow(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Celeste Classic"
        window.center()
        // Don't allow shrinking below the default size, matching `ports/SDL2`'s
        // `SDL_RenderSetIntegerScale` fixed-logical-size behavior.
        window.minSize = contentRect.size
        window.isRestorable = false

        let view = SKView(frame: contentRect)
        view.ignoresSiblingOrder = true
        view.autoresizingMask = [.width, .height]
        let scene = CelesteScene(size: size)
        // The scene stays fixed at that logical size; `.aspectFit` scales it uniformly to fill
        // the actual window without distorting the square PICO-8 canvas as the window resizes.
        scene.scaleMode = .aspectFit
        view.presentScene(scene)
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
#endif
