#if os(tvOS)
import UIKit
import SpriteKit

/// tvOS-only entry point (the iOS target is `CelesteMobile.swiftpm`, an App Playground, which
/// boots through a SwiftUI `App` instead of a `UIApplicationDelegate` - see that package's
/// `CelesteMobileApp.swift`). Shares `GameViewController` (`GameViewController.swift`) with a
/// hypothetical iOS Xcode target; only the bootstrap differs. See `AppDelegate_macOS.swift` for
/// the AppKit equivalent.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = GameViewController()
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}
#endif
