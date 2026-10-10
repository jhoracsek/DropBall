//
//  GameViewController.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import UIKit
import SpriteKit
import GameplayKit

var gameScene = SKScene(fileNamed: "StartScene")



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
        //2.163551401869159
        super.viewDidLoad()
        
        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            //print(mod(-50,500))
            
            view.ignoresSiblingOrder = true;
            view.shouldCullNonVisibleNodes = true;
           
            if let scene = SKScene(fileNamed: "StartScene") {
                // Set the scale mode to scale to fit the window
                //scene.scaleMode = .aspectFill
                //scene.size = CGSize(width:750.0, height:1334.0)
                
                scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
                scene.scaleMode = .aspectFill
                //scene.scaleMode = .aspectFit
                
                //print(scene.size)
                // Present the scene
                view.presentScene(scene)
            }
            /*
            let scene = GameScene(size: CGSize(width:1000, height:1000))
            scene.scaleMode = .aspectFill
            view.presentScene(scene)
            */
            
            view.ignoresSiblingOrder = true
            
            view.showsFPS = true
            view.showsNodeCount = true
        }
        
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
