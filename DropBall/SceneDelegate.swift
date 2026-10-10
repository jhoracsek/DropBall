//
//  SceneDelegate.swift
//  DropBall
//

import UIKit

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
}
