//
//  SceneDelegate.swift
//  DropBall
//

import UIKit
import SpriteKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // UIKit creates this window from Main.storyboard (UISceneStoryboardFile in Info.plist).
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard scene is UIWindowScene else { return }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // With the scene life cycle, applicationDidEnterBackground is no longer called, so save here instead.
        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()
    }

    /// The background overlay's drift is derived from a clock, and that clock keeps running
    /// while the app is away even though iOS has stopped the render loop. Discounting the
    /// time spent inactive stops the next scene built after returning from computing a
    /// position as though the background had carried on, and jumping.
    ///
    /// Resign/become rather than background/foreground, so a brief interruption such as the
    /// app switcher or a notification shade is covered too.
    func sceneWillResignActive(_ scene: UIScene) {
        BackgroundOverlay.setPaused(true, reason: .appInactive)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        BackgroundOverlay.setPaused(false, reason: .appInactive)
    }
}
