//
//  SettingsScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2025-11-07.
//

//
//  GameScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import SpriteKit
import GameplayKit
import CoreData

class SettingsScene: SKScene {
    //Make an enum state...
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    private var xPos : CGFloat = 0
    private var yPos : CGFloat = 0
    private var prevX : CGFloat = 0
    private var xDelta : CGFloat = 0
    private var yDelta : CGFloat = 0
    private var score = 0
    private var sceneNum = 0
    
    
    private var buttons: [SKButton] = []
    
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH
    
    //let ball = SKSpriteNode(imageNamed: "ball")

    let background = SKSpriteNode(imageNamed: "background")
    
    var rumbleText = SKLabelNode()
    
    let scoreOverlay = SKSpriteNode(imageNamed: "scoreoverlay")
    
    var homeButton = SKButton(x:0, y:100, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: {} )
    var rumbleButton = SKButton(x:0, y:100, unclick:"play", click:"play", test_function: {} )
    
    var rumbleOff = UserDefaults.standard.bool(forKey: "RumbleOff")

    
    let mountains = SKSpriteNode(imageNamed: "mountains")
    
    var scrollOffset : CGFloat = 0
    var iScrollOffset : CGFloat = 0
    
    var velocity : CGFloat = 0
    
    var offsetMax : CGFloat = 0

    func go_home(){
        Entity.cameraTranslationY = 0
        if let scene = SKScene(fileNamed: "StartScene") {
            // Set the scale mode to scale to fit the window
            Entity.cameraTranslationY = 0
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
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
    
    
    override func didMove(to view: SKView) {
        
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        self.addChild(background)
        background.zPosition = -1
        
        
        
        addChild(mountains)
        mountains.anchorPoint = CGPoint(x:0,y:0)
        mountains.position.x = -WIDTH/2
        mountains.position.y = -HEIGHT/2
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
        buttons.append(homeButton)
        
        rumbleButton = SKButton(x:0, y:0, unclick:"play", click:"play", test_function: toggle_rumble )
        buttons.append(rumbleButton)
        
        
        for button in buttons{
            for child in button.getSpriteNode(){
                addChild(child)
            }
        }
        
    }
    
    
    var isTouched=false
    var initialPosition:CGFloat = 0
    var difference:CGFloat = 0
    var deaccelerate = false
    var fingerPosition:CGFloat = 0
    var prevY : CGFloat = 0
    var curY : CGFloat = 0
    var trail : CGFloat = 0
    func touchDown(atPoint pos : CGPoint) {
        for button in buttons {
            button.checkPressed(pos: pos)
        }
        initialPosition = pos.y
        isTouched=true
        deaccelerate = false
        prevY = pos.y
        curY = pos.y
    }
    
    func touchUp(atPoint pos : CGPoint) {
        for button in buttons {
            button.unpressed()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {

        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
   
}
