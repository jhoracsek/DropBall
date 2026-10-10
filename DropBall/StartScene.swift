//
//  StartScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-08-28.
//

import SpriteKit
import GameplayKit



class StartScene: SKScene {
    
    let offset: CGFloat = -50

    let background = SKSpriteNode(imageNamed: "background")
    
    let test = SKLabelNode(fontNamed: "Chalkduster")
    
    let rectangle = SKShapeNode(rectOf: CGSize(width: 300, height: 150))
    
    
    func testFunc(){print("test")}
    
    //let startButton = SKButton(x:0, y:0, unclick:"startbutton", click:"startbuttonclick", test_function: test_func )
    
    var startButton = SKButton(x:0, y:0, unclick:"play", click:"playclick", test_function: {} )
    
    var highscoreButton = SKButton(x:0, y:100, unclick:"highscore", click:"highscoreclick", test_function: {} )
    
    var settingsButton = SKButton(x:0, y:100, unclick:"pause", click:"pause", test_function: {} )
    
    
    let logo = SKSpriteNode(imageNamed: "logo")
    
    let mountains = SKSpriteNode(imageNamed: "mountains")
    
    let ball = Entity(posX:0, posY:-60 * GameViewController.vScale, imageNamed:"ball", falls:true)
    
    var platform : SinglePlatform = SinglePlatform(pY:-380 * GameViewController.vScale)
    
    var clouds : [Cloud] = [];
    
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH
    
    
    
    override func didMove(to view: SKView) {
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
        //let screen = SKScene.getVisibleScreen(sceneRect: self.scene!.frame, viewRect: self.view!.frame)
        for i in 1...14{
            //Maybe make every cloud after 7 appear with pr 50 or 60
            let addOffset = CGFloat.random(in: -100...50)
            let isIncluded = Bool.random()
            if (i > 6){
                if(isIncluded){
                    let cloud = Cloud(pY:(500+addOffset) * GameViewController.vScale, cloudNum: i)
                    clouds.append(cloud)
                    addChild(cloud.getSpriteNode())
                    cloud.getSpriteNode().zPosition = CGFloat(i)
                    cloud.getSpriteNode().alpha = 1
                }
            }else{
                let cloud = Cloud(pY:(500+addOffset) * GameViewController.vScale, cloudNum: i)
                clouds.append(cloud)
                addChild(cloud.getSpriteNode())
                cloud.getSpriteNode().zPosition = CGFloat(i)
                cloud.getSpriteNode().alpha = 1
            }
        }
        addChild(mountains)
        mountains.anchorPoint = CGPoint(x:0,y:0)
        mountains.position.x = -WIDTH/2
        mountains.position.y = -HEIGHT/2
        mountains.zPosition = 3
        
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        background.zPosition = -20
        self.addChild(background)
        
        addChild(ball.getSpriteNode())
        ball.setScale(scale: 0.75)
        ball.update()
        
        addChild(platform.getSpriteNode()[0])
        platform.getSpriteNode()[0].zPosition = 2
        platform.update()
        
        startButton = SKButton(x:-125, y:120+offset, unclick:"play", click:"playclick", test_function: go_to_game )
        
        for i in startButton.getSpriteNode(){
            self.addChild(i)
        }
        
        
        highscoreButton = SKButton(x:125, y:120+offset, unclick:"highscore", click:"highscoreclick", test_function: test_func )
        
        for i in highscoreButton.getSpriteNode(){
            self.addChild(i)
        }
        //HEIGHT/2-75
        settingsButton = //SKButton(x:(WIDTH/2-75), y:-HEIGHT/2+75, unclick:"pause", click:"pause", test_function: go_to_settings )
                           SKButton(x:(WIDTH/2-75), y:HEIGHT/2-75, unclick:"pause", click:"homebuttonsmall", test_function: go_to_settings )
        settingsButton.scale(scale: 0.65)
        
        for i in settingsButton.getSpriteNode(){
            self.addChild(i)
        }
        
        //A little bit of code
        logo.position = CGPoint(x: 0, y:275+offset)
        addChild(logo)
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
    }
    
    func go_to_game()->(){
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
        if let scene = SKScene(fileNamed: "GameScene") {
            // Set the scale mode to scale to fit the window
            //scene.scaleMode = .aspectFill
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
        }
    }
    
    func test_func()->(){
        if let scene = SKScene(fileNamed: "HighscoreScene") {
            // Set the scale mode to scale to fit the window
            //scene.scaleMode = .aspectFill
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
        }
    }
    
    func go_to_settings(){
        if let scene = SKScene(fileNamed: "SettingsScene") {
            // Set the scale mode to scale to fit the window
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
        }
    }
    
    func within(pos: CGPoint, origin: CGPoint, rect: CGSize ) -> Bool{
        let halfWidth = rect.width/2
        let halfHeight = rect.height/2
        
        let boundX1 = origin.x - halfWidth
        let boundX2 = origin.x + halfWidth
        
        let boundY1 = origin.y - halfHeight
        let boundY2 = origin.y + halfHeight
        
        let posX = pos.x
        let posY = pos.y
        
        if posX < boundX1 || posX > boundX2 || posY < boundY1 || posY > boundY2{
            return false
        }
        return true
    }

    
    func touchDown(atPoint pos : CGPoint) {
        //print(within(pos:pos, origin:rectangle.position, rect:CGSize(width:300,height:150) )  )
        //if()
        startButton.checkPressed(pos: pos)
        highscoreButton.checkPressed(pos: pos)
        settingsButton.checkPressed(pos: pos)
    }
    
    func touchMoved(toPoint pos : CGPoint) {

    }
    
    func touchUp(atPoint pos : CGPoint) {
        startButton.unpressed()
        highscoreButton.unpressed()
        settingsButton.unpressed()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
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
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
        ball.update()
        
        platform.update()
        
        var isHit = false
        
        for cloud in clouds {
            cloud.update()
        }
        
        if(platform.passed == false){
            if(ball.isColliding(obj: platform.pass)){
                platform.passed = true
                
            }
        }
        if(ball.isColliding(obj: platform)){
            ball.setHitGroud(val:true)
            isHit = true
            ball.posY = platform.leftPlatform.height/2+ball.height/2+platform.leftPlatform.posY+2
        }else{
            if isHit == false{
                ball.setHitGroud(val:false)
            }
        }
        ball.checkCollision()
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
    }
}
