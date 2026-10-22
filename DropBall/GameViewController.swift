//
//  GameViewController.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    static var HEIGHT : CGFloat = 1624.0
    static var WIDTH : CGFloat = 750.0

    /// The scene height every vertical gameplay constant in the project was authored against.
    static let REFERENCE_HEIGHT : CGFloat = 1334.0

    /// Scene width is fixed at 750 on every device, but the scene height grows on taller
    /// phones so nothing gets cropped. That means a vertical distance of 1 scene unit covers
    /// a smaller fraction of the screen on a tall phone than on a short one, so unscaled
    /// per-frame speeds and world spacing make the game look slower and more tightly packed
    /// there. Multiplying every vertical world distance and speed by this factor keeps motion
    /// and layout at a constant fraction of the screen on all aspect ratios. It is exactly 1.0
    /// on devices that use the reference height, so their behaviour is unchanged.
    static var vScale : CGFloat { HEIGHT / REFERENCE_HEIGHT }

    override func viewDidLoad() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        if (screenHeight/screenWidth) >= 2 {
            GameViewController.HEIGHT = 1624.0
            GameViewController.WIDTH = 750.0
        }else{
            GameViewController.HEIGHT = 1334.0
            GameViewController.WIDTH = 750.0
        }
        super.viewDidLoad()
        
        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()

        // Started here rather than in the app delegate because signing in may need to put a
        // view controller on screen, and this is the first point at which there's a root
        // view controller for it to be presented from.
        GameCenter.authenticate()

        if let view = self.view as? SKView {
            view.ignoresSiblingOrder = true
            view.shouldCullNonVisibleNodes = true

            if let scene = SKScene(fileNamed: "StartScene") {
                scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
                scene.scaleMode = .aspectFill
                view.presentScene(scene)
            }

            // Debug overlays are useful while developing but must never reach a release build.
            #if DEBUG
            view.showsFPS = true
            view.showsNodeCount = true
            #endif
        }
    }

    override var shouldAutorotate: Bool {
        return false
    }

    // The scene is a fixed-width portrait layout, so every orientation other than portrait
    // crops the playfield. Keep this in sync with UISupportedInterfaceOrientations in Info.plist.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
