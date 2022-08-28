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

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as! SKView? {
            // Load the SKScene from 'GameScene.sks'
            //print(mod(-50,500))
            if let scene = SKScene(fileNamed: "GameScene") {
                // Set the scale mode to scale to fit the window
                //scene.scaleMode = .aspectFill
                scene.size = CGSize(width:750.0, height:1334.0)
                scene.scaleMode = .aspectFill
                print(scene.size)
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
