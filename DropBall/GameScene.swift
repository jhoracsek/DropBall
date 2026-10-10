//
//  GameScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import SpriteKit
import GameplayKit
import AudioToolbox
import CoreData

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
    private var sceneNum = 0

    //Values which can be changed for testing.
    let topBarEndsGame = true
    let showHitboxes = false
    // End testing values.
    
    //let ball = SKSpriteNode(imageNamed: "ball")
    let ball = Entity(posX:0, posY:0, imageNamed:"ball", falls:true)
    
    let top = Top(posY:500 * GameViewController.vScale)
    let background = SKSpriteNode(imageNamed: "background")
    let pauseText = SKSpriteNode(imageNamed: "pausetext")
    let mountains = SKSpriteNode(imageNamed: "mountains")
    let overlay = SKSpriteNode(imageNamed: "loseoverlay")
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH
    let vScale : CGFloat = GameViewController.vScale

    var pauseButton = SKButton(x:0, y:100, unclick:"pause", click:"pause", test_function: {} )
    var resumeButton = SKButton(x:0, y:100, unclick:"resume", click:"resume", test_function: {} )
    
    var startButton = SKButton(x:0, y:0, unclick:"play", click:"playclick", test_function: {} )
    var homeButton = SKButton(x:0, y:0, unclick:"homebutton", click:"homebutton", test_function: {} )
    
    var gamePaused = false
    
    let scoreDisplay = ScoreDisplay(posX:0, posY:300)
    
    let scoreFinal = ScoreDisplay(posX:65, posY:21, factor:0.5)
    let scoreBest = ScoreDisplay(posX:65, posY:16-42, factor:0.5)
    
    var pauseCooldown = 5
    
    let rumbleOff = UserDefaults.standard.bool(forKey: "RumbleOff")
    
    
    var platforms : [Platform] = []
    var clouds : [Cloud] = []
    
    //Probably deque for platforms and array for platofrms to draw..
    var platoffset : CGFloat = 0
    func loadPlatforms(){
        for _ in 1...10{
            platforms.append(Platform(pY:(-400 * vScale)-platoffset))
            platoffset = platoffset + (450 * vScale)
        }
    }
    
    var cloudOffset : CGFloat = (450/2) * GameViewController.vScale
    var prev = -1
    func loadClouds(){
        
        for _ in 1...10{
            var cNum = Int.random(in: 1...14)
            while(prev == cNum){
                cNum = Int.random(in: 1...14)
            }
            clouds.append(Cloud(pY:(-400 * vScale)-cloudOffset, cloudNum: cNum, prob:0))
            cloudOffset = cloudOffset + (450 * vScale)
            prev = cNum
        }
    }
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor(red: 18/256, green: 45/256, blue: 110/256, alpha: 1)
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        self.addChild(background)
        background.zPosition = -1
        
        addChild(pauseText)
        pauseText.zPosition = 50
        pauseText.alpha = 0
        pauseText.position.y += 70
        pauseText.scale(to: CGSize(width:pauseText.size.width*0.5,height:pauseText.size.height*0.5))
        
        addChild(mountains)
        mountains.anchorPoint = CGPoint(x:0,y:0)
        mountains.position.x = -WIDTH/2
        mountains.position.y = -HEIGHT/2
        mountains.zPosition = -0.9
        
        
        pauseButton = SKButton(x:(WIDTH/2-75), y:HEIGHT/2-75, unclick:"pause", click:"pause", test_function:
                                { self.pauseButton.toggleDisable(); self.gamePaused = true;self.resumeButton.toggleDisable();} )
        pauseButton.scale(scale: 0.65)
        
        resumeButton = SKButton(x:WIDTH/2-75, y:HEIGHT/2-75, unclick:"resume", click:"resume", test_function:
                                    { if(self.pauseCooldown == 0 ){self.pauseButton.toggleDisable(); self.resumeButton.toggleDisable();self.gamePaused = false; self.pauseCooldown=5}}  )
        resumeButton.scale(scale: 0.65)
        
        for i in pauseButton.getSpriteNode(){
            self.addChild(i)
        }
        
        for i in resumeButton.getSpriteNode(){
            self.addChild(i)
        }
        
        resumeButton.toggleDisable()
    
        startButton = SKButton(x:-125, y:-175, unclick:"play", click:"playclick", test_function: reset )
        homeButton = SKButton(x:125, y:-175, unclick:"homebutton", click:"homebutton", test_function: go_home )
        
        switch sceneNum{
        case 0:
            ball.setScale(scale: 0.75)
            
            loadPlatforms()
            loadClouds()
            top.strech(sX: 750)
            //addChild(background)
            //platform.setScale(scaleX: 3, scaleY: 1)
            ball.getSpriteNode().zPosition = 2
            addChild(ball.getSpriteNode())
            addChild(ball.initSecondarySprite())
            //addChild(ball.initParticles())
                ball.initParticles()
            // Now also add the hitbox for the ball
            if(showHitboxes){
                addChild(ball.hitbox)
            }
                
            for platform in platforms {
                if(showHitboxes){
                    addChild(platform.leftEndCap.hitbox)
                    addChild(platform.rightEndCap.hitbox)
                    
                    platform.leftPlatform.hitbox.color = SKColor.init(red: 1.0, green: 0.7, blue: 0.1, alpha: 0.85)
                    platform.rightPlatform.hitbox.color = SKColor.init(red: 1.0, green: 0.7, blue: 0.1, alpha: 0.85)
                    
                    addChild(platform.leftPlatform.hitbox)
                    addChild(platform.rightPlatform.hitbox)
                }
                for i in platform.getSpriteNode(){
                    i.zPosition=1
                    addChild(i)
                }
            }
            for cloud in clouds {
                let i = cloud.getSpriteNode()
                i.zPosition = -0.5
                //i.alpha = 0.5
                addChild(i)
                
            }

            
            /*
            test.text = String(score)
            addChild(test)
            test.fontSize = 80
            test.position = CGPoint(x: 0, y:300)
            test.zPosition=20
            */
            
            for s in scoreDisplay.getSpriteNode(){
                addChild(s)
                s.zPosition = 20
            }
            
            addChild(top.getSpriteNode())
            top.getSpriteNode().zPosition = 10
            Entity.cameraTranslationY = -ball.posY
            
            break
        default:
            
            break
        }
    }
    
    func reset()->(){
        Entity.cameraTranslationX = 0
        Entity.cameraTranslationY = 0
        if let scene = SKScene(fileNamed: "GameScene") {
            // Set the scale mode to scale to fit the window
            //scene.scaleMode = .aspectFill
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
        }
    }
    
    var isTouched = false
    var initialPosition:CGFloat = 0
    var difference:CGFloat = 0
    var deaccelerate = false
    
    func touchDown(atPoint pos : CGPoint) {
            /*
            if(!gamePaused){
                if(abs(pos.x - prevX) < 25 ){
                    //prevX = pos.x
                }
            }
            */
      
        if(lost_sec){
            startButton.checkPressed(pos: pos)
            homeButton.checkPressed(pos: pos)
        }
        var ispressed = false
        if(resumeButton.checkPressed(pos: pos)){
            ispressed=true
        }
        if(pauseButton.checkPressed(pos: pos)){
            ispressed=true
        }
        if(ispressed || gamePaused){
            return
        }
        
        if(!isTouched){
            initialPosition = pos.x
        }
        //difference = 0
        
        isTouched=true
        deaccelerate = false

    }
    
    func touchMoved(toPoint pos : CGPoint) {
        //OLD
        /*
        if(!gamePaused){
            if(abs(pos.x - prevX) < 50 ){
            xDelta = pos.x - prevX
            ball.moveHorizontally(pX: xDelta)
            prevX = pos.x
            }
        }*/
        
        //Should move according to the initial position and the position of the finger.
        //Speed should be determined by the difference of the position of the finger and the initialPosition.
        //let ballPosition = ball.sprite.position.x
        
        if(isTouched && abs(pos.x - initialPosition) > 5){
            // Implement some degree of tolerance.
            let fingerPosition = pos.x
            ball.fingerPosition = pos.x
            difference = 0.1*(fingerPosition - initialPosition)
        }
        
    }
    
    func touchUp(atPoint pos : CGPoint) {
        if(lost_sec){
            startButton.unpressed()
            homeButton.unpressed()
        }
        deaccelerate = true
        isTouched=false
        pauseButton.unpressed()
        resumeButton.unpressed()
    }
    
    
    /*
        Implementing long press speed up.
     */

    var holdTimer: Timer?
    var isTouchForHold = false
    var isHolding = false
    
    var initialHoldLocation: CGPoint = .zero
    let holdTolerance: CGFloat = 40
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        /*
        if let label = self.label {
            label.run(SKAction.init(named: "Pulse")!, withKey: "fadeInOut")
        }*/
        
        
        isTouchForHold = true
        isHolding = false
        
        if let touch = touches.first {
            initialHoldLocation = touch.location(in: self)
        }
        
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false){ [weak self] _ in
            guard let self = self else { return }
            if self.isTouchForHold {
                self.isHolding = true
                //Here you should tell the ball to be pushed down.
                ball.pushDown()
                
            }
            
        }
        
        for t in touches {
            self.touchDown(atPoint: t.location(in: self))
            return
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let location = touch.location(in: self)
            
            if !isHolding{
                let distance = hypot(location.x - initialHoldLocation.x, location.y - initialHoldLocation.y)
                if distance > holdTolerance {
                    cancelHold()
                }
            }
        }
        
        
        for t in touches {
            self.touchMoved(toPoint: t.location(in: self))
            return
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
        for t in touches { self.touchUp(atPoint: t.location(in: self));return }
        
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endTouch()
        for t in touches { self.touchUp(atPoint: t.location(in: self));return }
        
    }
    
    private func cancelHold(){
        holdTimer?.invalidate()
        holdTimer = nil
    }
    
    private func endTouch(){
        isTouchForHold = false
        isHolding = false
        cancelHold()
    }
    
    func save(){
        let context = (UIApplication.shared.delegate as!AppDelegate).coreDataStack.managedContext
        let newScore = Score(context: context)
        
        newScore.name = "None"
        newScore.score = Int64(self.score)
        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()
        print("Saved context")
        DispatchQueue.main.async {
            
        }
        
    }
    
    var gameLost = false
    var shake = false
    var shakeDuration = 20
    
    func displayOverlay(){
        
    }
    
    var scores = [Score]()
    func getScores(){
        let fet: NSFetchRequest<Score> = Score.fetchRequest()
        fet.fetchLimit = 1
        let byScore = NSSortDescriptor(key: #keyPath(Score.score), ascending: false)
        fet.sortDescriptors = [byScore]
        do{
            let context = (UIApplication.shared.delegate as!AppDelegate).coreDataStack.managedContext
            self.scores = try context.fetch(fet)
        } catch let error as NSError{
            print("Fetch error: \(error) description: \(error.userInfo)")
        }
    }
    
    func shakeScreen(){
        let randomX = CGFloat.random(in:-10...10)
        let randomY = CGFloat.random(in:-10...10)
        Entity.cameraTranslationX += randomX
        Entity.cameraTranslationY += randomY
        if(shakeDuration <= 0){
            shake = false
        }
        overlay.alpha += 1/20
        shakeDuration-=1
        if (overlay.position.y <= 0){
            overlay.position.y += 32
        }
        
    }
    
    func lost(){
        
        save()
        
        getScores()
        
        scoreBest.setScore(score: Int(scores[0].score))
        
        for sc in scoreDisplay.getSpriteNode(){
            sc.alpha = 0
        }
        gameLost=true
        shake=true
        pauseButton.disable()
        resumeButton.disable()
        addChild(overlay)
        overlay.position.y = -320
        overlay.zPosition = 30
        overlay.alpha = 0
        for child in startButton.getSpriteNode(){
            child.alpha = 0
            addChild(child)
        }
        
        for child in homeButton.getSpriteNode(){
            child.alpha = 0
            addChild(child)
        }
        for child in scoreFinal.getSpriteNode(){
            child.alpha = 0
            child.zPosition = 40
            addChild(child)
        }
        for child in scoreBest.getSpriteNode(){
            child.alpha = 0
            child.zPosition = 40
            addChild(child)
        }
        if(!rumbleOff){
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }
        //lose()
    }
    
    var op:CGFloat = 0
    var lost_sec = false
    func lost_second(){
        lost_sec = true
        
        scoreFinal.update()
        scoreBest.update()
        if(scoreFinal.score < score){
            removeChildren(in:scoreFinal.getSpriteNode())
            scoreFinal.addScore()
            for s in scoreFinal.getSpriteNode(){
                addChild(s)
                s.zPosition = 40
            }
            scoreFinal.update()
        }
        
        /*
        removeChildren(in:scoreDisplay.getSpriteNode())
        scoreDisplay.addScore()
        for s in scoreDisplay.getSpriteNode(){
            addChild(s)
            s.zPosition = 20
        }
        */
        for child in scoreFinal.getSpriteNode(){
            child.alpha = 1
        }
        for child in scoreBest.getSpriteNode(){
            child.alpha = 1
            
        }
        
        if(op < 1){
            op+=0.05
            for child in startButton.getSpriteNode(){
                child.alpha += 0.05
            }
            
            for child in homeButton.getSpriteNode(){
                child.alpha += 0.05
            }
        }
        
    }
    
    func go_home(){
        Entity.cameraTranslationY = 0
        
        if let scene = SKScene(fileNamed: "StartScene") {
            // Set the scale mode to scale to fit the window
            //scene.scaleMode = .aspectFill
            Entity.cameraTranslationY = 0
            //scene.update(0)
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            var reveal = SKTransition.crossFade(withDuration: 0.5)
            //reveal = SKTransition.flipHorizontal(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
            //save()
           
        }
        
    }
    
    override func update(_ currentTime: TimeInterval) {
        /*
         For Testing
         */
        if(isHolding){
            ball.hitbox.color = SKColor.init(red: 0.0, green: 0, blue: 1, alpha: 0.5)
            ball.speedAcc()
        }else{
            ball.hitbox.color = SKColor.init(red: 0.0, green: 1, blue: 0, alpha: 0.5)
            ball.slowAcc()
        }
        //print(ball.cooldownTimer)
        
        if(gameLost){
            ball.falls = false
            if(shake){
                shakeScreen()
                for platform in platforms {
                    platform.update()
                }
                for cloud in clouds {
                    cloud.update()
                }
                ball.update()
            }else{
                lost_second()
            }
            return
        }
        if(gamePaused){
            pauseText.alpha = 1
            if (pauseCooldown != 0){
                pauseCooldown -= 1
            }
            //pauseButton.update()
            //print(difference)
            return
        }
        pauseText.alpha = 0
        
        
        
        
        if(deaccelerate){
            if(difference < 0.1 && difference > -0.1){
                difference = 0
            }
            if(difference > 0){
                difference-=0.15
            }
            if(difference < 0){
                difference+=0.15
            }
        }
        ball.posX += difference
        
       
        
        top.update()
        var isHit = false
        
        var j = -1
        for cloud in clouds {
            j+=1
            cloud.update()

            if(cloud.cloud.sprite.position.y > 1400 * vScale){
                clouds.remove(at:j)
                removeChildren(in: [cloud.getSpriteNode()])
                for _ in 1...1{
                    var cNum = Int.random(in: 1...14)
                    while(prev == cNum){
                        cNum = Int.random(in: 1...14)
                    }
                    let c = Cloud(pY:(-400 * vScale)-cloudOffset, cloudNum: cNum, prob:0)
                    c.update()
                    clouds.append(c)
                    cloudOffset = cloudOffset + (450 * vScale)
                    prev = cNum
                    addChild(c.getSpriteNode())
                    c.getSpriteNode().zPosition = -0.5
                }
            }
            
        }
        ball.update()
        var i = -1
        for platform in platforms {
            i+=1
            platform.update()
            
            if(platform.leftPlatform.sprite.position.y > 1400 * vScale){
                platforms.remove(at:i)
                removeChildren(in: platform.getSpriteNode())
                for _ in 1...1{
                    let p = Platform(pY:(-400 * vScale)-platoffset)
                    platforms.append(p)
                    platoffset = platoffset + (450 * vScale)
                    for pf in p.getSpriteNode(){
                        addChild(pf)
                        pf.zPosition = 1
                    }
                }
                continue
            }
            if(platform.passed == false){
                if(ball.isColliding(obj: platform.pass)){
                    platform.passed = true
                    score = score + 1
                    //Update scoreDisplay
                    removeChildren(in:scoreDisplay.getSpriteNode())
                    scoreDisplay.addScore()
                    for s in scoreDisplay.getSpriteNode(){
                        addChild(s)
                        s.zPosition = 20
                    }
                    
                    
                    top.boost()
                    top.increaseVel()
                }
            }
            
            if(ball.isColliding(obj: platform)){
                ball.setHitGroud(val:true)
                isHit = true
                ball.posY = platform.rightPlatform.height/2+ball.height/2+platform.rightPlatform.posY+2
            }else if (ball.isColliding_endcap(obj: platform)){
                lost()
            }else{
                if isHit == false{
                    ball.setHitGroud(val:false)
                }
            }
            ball.checkCollision()
        }
        
        scoreDisplay.update()
        //top.setPos(pY: ball.posY+400)
        //background.position.y = 767-(ball.truePosY)*0.01
        background.position.y = GameViewController.HEIGHT/2 + 100 - (ball.truePosY)*0.01
        
        Entity.cameraTranslationY = -ball.posY
        
        //ball.position = CGPoint(x:xPos,y:yPos)
        
    }
}
