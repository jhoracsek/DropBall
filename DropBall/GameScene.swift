//
//  GameScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import SpriteKit
import GameplayKit

class GameScene: SKScene {
    //Make an enum state...
    private var label : SKLabelNode?
    private var spinnyNode : SKShapeNode?
    private var xPos : CGFloat = 0
    private var yPos : CGFloat = 0
    private var prevX : CGFloat = 0
    private var prevY : CGFloat = 0
    private var xDelta : CGFloat = 0
    private var yDelta : CGFloat = 0
    private var score = 0
    //let ball = SKSpriteNode(imageNamed: "ball")
    let ball = Entity(posX:0, posY:100, imageNamed:"ball", falls:true)
    let top = Top(posY:500)
    let background = SKSpriteNode(imageNamed: "background")
    //let platform = Platform(pY: -400)
    
    //Testing text
    let test = SKLabelNode(fontNamed: "Chalkduster")
    
    var platforms : [Platform] = []
    
    //Probably deque for platforms and array for platofrms to draw..
    func loadPlatforms(){
        var offset : CGFloat = 0
        for _ in 1...500{
            platforms.append(Platform(pY:-400-offset))
            offset = offset+450
        }
    }
    
    
    override func didMove(to view: SKView) {
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = 667
        self.addChild(background)
        
        ball.setScale(scale: 0.75)
        
        loadPlatforms()
        top.strech(sX: 750)
        //addChild(background)
        //platform.setScale(scaleX: 3, scaleY: 1)
        ball.getSpriteNode().zPosition = 2
        addChild(ball.getSpriteNode())
        
        for platform in platforms {
            for i in platform.getSpriteNode(){
                i.zPosition=1
                addChild(i)
            }
        }
        
        test.text = String(score)
        addChild(test)
        test.fontSize = 80
        test.position = CGPoint(x: 0, y:300)
        test.zPosition=20
        addChild(top.getSpriteNode())
        top.getSpriteNode().zPosition = 10

    }
    
    
    func touchDown(atPoint pos : CGPoint) {
        prevX = pos.x
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        xDelta = pos.x - prevX
        ball.moveHorizontally(pX: xDelta)
        prevX = pos.x
        
        //ball.setPos(pX: pos.x, pY: pos.y)
    }
    
    func touchUp(atPoint pos : CGPoint) {
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        /*
        if let label = self.label {
            label.run(SKAction.init(named: "Pulse")!, withKey: "fadeInOut")
        }*/
        
        for t in touches { self.touchDown(atPoint: t.location(in: self)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: t.location(in: self)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: t.location(in: self)) }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Called before each frame is rendered
        test.text = String(score)
        xPos = xPos + xDelta*0.75
        xDelta = xDelta*0.50
        ball.update()

        top.update()
        var isHit = false
       
        for platform in platforms {
            platform.update()
            if(platform.passed == false){
                if(ball.isColliding(obj: platform.pass)){
                    platform.passed = true
                    score = score + 1
                    top.boost()
                    top.increaseVel()
                }
            }
            if(ball.isColliding(obj: platform)){
                ball.setHitGroud(val:true)
                isHit = true
                ball.posY = platform.rightPlatform.height/2+ball.height/2+platform.rightPlatform.posY+2
            }else{
                if isHit == false{
                    ball.setHitGroud(val:false)
                }
            }
            ball.checkCollision()
        }
        //top.setPos(pY: ball.posY+400)
        background.position.y = 767-(ball.truePosY)*0.01
        Entity.cameraTranslationY = -ball.posY
        
        //ball.position = CGPoint(x:xPos,y:yPos)
    }
}
