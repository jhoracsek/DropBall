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
