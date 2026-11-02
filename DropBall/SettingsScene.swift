//
//  SettingsScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2025-11-07.
//

import SpriteKit
import GameplayKit

class SettingsScene: SKScene, PresentedScene {
    private var buttons: [SKButton] = []

    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH

    let background = SKSpriteNode(imageNamed: "background")
    let mountains = SKSpriteNode(imageNamed: "mountains")

    var rumbleText = SKLabelNode()

    var homeButton = SKButton(x:0, y:100, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: {} )
    var rumbleButton = SKButton(x:0, y:100, unclick:"play", click:"play", test_function: {} )

    var rumbleOff = UserDefaults.standard.bool(forKey: "RumbleOff")

    func go_home(){
        Entity.cameraTranslationY = 0
        if let scene = SKScene(fileNamed: "StartScene") {
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            transition(to: scene)
        }
    }
    
    func toggle_rumble(){
        rumbleOff = !rumbleOff
        UserDefaults.standard.set(rumbleOff, forKey: "RumbleOff")
        if(rumbleOff){
            rumbleText.text = "Rumble is: Off"
        }else{
            rumbleText.text = "Rumble is: On"
        }
    }
    
    
    func didPresent() {
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        self.addChild(background)
        background.zPosition = -1

        addChild(mountains)
        mountains.anchorPoint = CGPoint(x:0,y:0)
        mountains.position.x = -WIDTH/2
        mountains.position.y = GameViewController.mountainsBaseY
        mountains.zPosition = -0.9

        if(rumbleOff){
            rumbleText.text = "Rumble is: Off"
        }else{
            rumbleText.text = "Rumble is: On"
        }
        rumbleText.fontSize = 65
        rumbleText.fontColor = SKColor.black
        rumbleText.position = CGPoint(x: 0, y:-135)
        rumbleText.zPosition = 50
        self.addChild(rumbleText)

        homeButton = SKButton(x:(WIDTH/2-75), y:HEIGHT/2-75, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: go_home )
        homeButton.scale(scale: 0.65)
        // Pulled in from the corner only where it would otherwise be off-screen or under
        // the camera, rounded corners or home indicator.
        homeButton.keep(inside: safeFrame)
        buttons.append(homeButton)

        rumbleButton = SKButton(x:0, y:0, unclick:"play", click:"play", test_function: toggle_rumble )
        buttons.append(rumbleButton)

        for button in buttons{
            for child in button.getSpriteNode(){
                addChild(child)
            }
        }
    }

    func touchDown(atPoint pos : CGPoint) {
        for button in buttons {
            button.checkPressed(pos: pos)
        }
    }

    func touchUp(atPoint pos : CGPoint) {
        for button in buttons {
            button.unpressed()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        for t in touches { self.touchDown(atPoint: location(of: t)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: location(of: t)) }
    }
   
}
