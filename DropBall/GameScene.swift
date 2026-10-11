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
    private var score = 0

    /// Draws the collision rectangles over the ball and platforms. Development aid only.
    let showHitboxes = false

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
        
        ball.setScale(scale: 0.75)

        loadPlatforms()
        loadClouds()
        top.strech(sX: 750)
        ball.getSpriteNode().zPosition = 2
        addChild(ball.getSpriteNode())
        addChild(ball.initSecondarySprite())
        _ = ball.initParticles()

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
            addChild(i)
        }

        for s in scoreDisplay.getSpriteNode(){
            addChild(s)
            s.zPosition = 20
        }

        addChild(top.getSpriteNode())
        top.getSpriteNode().zPosition = 10
        Entity.cameraTranslationY = -ball.posY
    }
    
    func reset()->(){
        Entity.cameraTranslationX = 0
        Entity.cameraTranslationY = 0
        if let scene = SKScene(fileNamed: "GameScene") {
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

        isTouched=true
        deaccelerate = false
    }
    
    func touchMoved(toPoint pos : CGPoint) {
        // The ball tracks the distance the finger has travelled from where it first landed,
        // so the drag distance sets the speed rather than the absolute finger position.
        if(isTouched && abs(pos.x - initialPosition) > 5){
            // Ignore tiny movements so a stationary finger doesn't nudge the ball.
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
        let context = AppDelegate.sharedAppDelegate.coreDataStack.managedContext
        let newScore = Score(context: context)

        newScore.name = "None"
        newScore.score = Int64(self.score)
        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()
    }
    
    var gameLost = false
    var shake = false
    var shakeDuration = 20
    
    var scores = [Score]()
    func getScores(){
        let fet: NSFetchRequest<Score> = Score.fetchRequest()
        fet.fetchLimit = 1
        let byScore = NSSortDescriptor(key: #keyPath(Score.score), ascending: false)
        fet.sortDescriptors = [byScore]
        do{
            let context = AppDelegate.sharedAppDelegate.coreDataStack.managedContext
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

        // save() has just inserted this run's score, so there is normally at least one row.
        // Fall back to the current score rather than trapping if the fetch comes back empty.
        scoreBest.setScore(score: Int(scores.first?.score ?? Int64(score)))
        
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
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
        }
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Holding the screen makes the ball fall faster. The hitbox tint is only visible
        // when showHitboxes is on, and marks which of the two states is active.
        if(isHolding){
            ball.hitbox.color = SKColor.init(red: 0.0, green: 0, blue: 1, alpha: 0.5)
            ball.speedAcc()
        }else{
            ball.hitbox.color = SKColor.init(red: 0.0, green: 1, blue: 0, alpha: 0.5)
            ball.slowAcc()
        }
        
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
        
        // `clouds` is mutated below while this loop walks a snapshot of it, so a positional
        // index would go stale after the first removal and delete the wrong cloud. Removing
        // by identity is correct no matter how many are recycled in a single frame.
        for cloud in clouds {
            cloud.update()

            if(cloud.cloud.sprite.position.y > 1400 * vScale){
                clouds.removeAll { $0 === cloud }
                removeChildren(in: [cloud.getSpriteNode()])

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
        ball.update()
        // Same stale-index hazard as the cloud loop above: remove by identity, not position.
        // A mis-indexed removal left a platform in the array with its sprites already
        // detached from the scene, so the ball could still die on an invisible end cap.
        for platform in platforms {
            platform.update()
            
            if(platform.leftPlatform.sprite.position.y > 1400 * vScale){
                platforms.removeAll { $0 === platform }
                removeChildren(in: platform.getSpriteNode())

                let p = Platform(pY:(-400 * vScale)-platoffset)
                platforms.append(p)
                platoffset = platoffset + (450 * vScale)
                for pf in p.getSpriteNode(){
                    addChild(pf)
                    pf.zPosition = 1
                }
                continue
            }
            if(platform.passed == false){
                if(ball.isColliding(obj: platform.pass)){
                    platform.passed = true
                    score = score + 1

                    // The score is drawn from per-digit sprites, so a new digit count means
                    // rebuilding the whole display rather than editing a label.
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

        // The background drifts at a fraction of the ball's fall speed for a parallax effect.
        background.position.y = GameViewController.HEIGHT/2 + 100 - (ball.truePosY)*0.01

        Entity.cameraTranslationY = -ball.posY
    }
}
