//
//  StartScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-08-28.
//

import SpriteKit
import GameplayKit



class StartScene: SKScene, PresentedScene {
    
    let offset: CGFloat = -50

    /// Scales the menu's bounce sound down relative to gameplay.
    ///
    /// The menu ball drops from a fixed height on a 1.67s cycle, so it lands at exactly the
    /// same force every time with nothing else going on to mask it. At full level that
    /// works out at 0.75 against music sitting at 0.45; this brings the two level.
    private static let menuBounceVolume: CGFloat = 0.6

    let background = SKSpriteNode(imageNamed: "background")

    var startButton = SKButton(x:0, y:0, unclick:"play", click:"playclick", test_function: {} )
    
    var highscoreButton = SKButton(x:0, y:100, unclick:"highscore", click:"highscoreclick", test_function: {} )
    
    var settingsButton = SKButton(x:0, y:100, unclick:"settings", click:"settings", test_function: {} )

    private var settingsDropdown: SettingsDropdown?
    
    
    let logo = SKSpriteNode(imageNamed: "logo")
    
    let mountains = SKSpriteNode(imageNamed: "mountains")
    
    let ball = Entity(posX:0, posY:-60 * GameViewController.vScale, imageNamed:"ball", falls:true)
    
    var platform : SinglePlatform = SinglePlatform(pY: GameViewController.menuGroundY * GameViewController.vScale)
    
    var clouds : [Cloud] = [];
    
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH
    
    
    
    func didPresent() {
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0

        // Clouds 1-6 always appear; the rest show up at random so the menu varies per launch.
        for i in 1...14{
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
        mountains.position.y = GameViewController.mountainsBaseY
        mountains.zPosition = 3
        
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        background.zPosition = -20
        self.addChild(background)

        // This scene stacks its layers differently from the others — background at -20,
        // clouds from 1 to 14, mountains at 3 — so the overlay goes just above the
        // gradient rather than at the shared default.
        addChild(BackgroundOverlay.make(z: -19))
        
        addChild(ball.getSpriteNode())
        ball.setScale(scale: 0.75)
        ball.isCircular = true
        ball.update()

        // Sound only. Haptics stay game-only on purpose — a menu that buzzes in your hand
        // while you're reading it is a different proposition from one that makes a noise.
        //
        // Captures nothing, so there's no reference cycle back into the scene.
        ball.onBounce = { strength in
            Audio.playBounce(strength: strength, scale: StartScene.menuBounceVolume)
        }
        
        addChild(platform.getSpriteNode()[0])
        platform.getSpriteNode()[0].zPosition = 2
        platform.update()
        
        startButton = SKButton(x:-125, y:120+offset, unclick:"play", click:"playclick", test_function: go_to_game )
        
        for i in startButton.getSpriteNode(){
            self.addChild(i)
        }
        
        
        highscoreButton = SKButton(x:125, y:120+offset, unclick:"highscore", click:"highscoreclick", test_function: go_to_highscores )
        
        for i in highscoreButton.getSpriteNode(){
            self.addChild(i)
        }

        // Both images are the gear. The pressed state used to be "homebuttonsmall", which
        // made tapping settings flash a house.
        settingsButton = SKButton(x:(WIDTH/2-75), y:HEIGHT/2-75, unclick:"settings", click:"settings", test_function: toggle_settings )
        settingsButton.scale(scale: 0.65)
        // Pulled in from the corner only where it would otherwise be off-screen or under
        // the camera, rounded corners or home indicator.
        settingsButton.keep(inside: safeFrame)
        
        for i in settingsButton.getSpriteNode(){
            self.addChild(i)
        }

        settingsDropdown = SettingsDropdown(below: settingsButton, in: self)
        settingsDropdown?.onShowCredits = { [weak self] in
            self?.go_to_credits()
        }
        settingsDropdown?.onSettingChanged = { [weak self] key, isOn in
            // Sound effects read the setting on each play, so they need nothing here. Music
            // is already running, so it has to be told to stop or start straight away.
            if key == "MusicOff" {
                Music.shared.setEnabled(isOn)
            }

            // Zooming changes how much of the scene is on screen, and the corner buttons are
            // placed against that when the scene is built — so build the menu again, with
            // the usual cross-fade, rather than leave the gear where it may now be cropped.
            if key == ScreenFit.zoomOffKey {
                self?.reload_menu()
            }
        }
        
        logo.position = CGPoint(x: 0, y:275+offset)
        addChild(logo)
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
    }
    
    func go_to_game()->(){
        Entity.cameraTranslationY = 0
        Entity.cameraTranslationX = 0
        if let scene = SKScene(fileNamed: "GameScene") {
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            transition(to: scene)
        }
    }
    
    func go_to_highscores()->(){
        if let scene = SKScene(fileNamed: "HighscoreScene") {
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            transition(to: scene)
        }
    }
    
    func toggle_settings(){
        settingsDropdown?.toggleExpanded()
    }

    /// A fresh copy of this menu, laid out for the current screen framing.
    func reload_menu(){
        if let scene = SKScene(fileNamed: "StartScene") {
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            transition(to: scene)
        }
    }

    /// Built in code rather than loaded from a .sks, so it's constructed directly.
    func go_to_credits(){
        let scene = AttributionsScene(size: CGSize(width: GameViewController.WIDTH,
                                                   height: GameViewController.HEIGHT))
        scene.scaleMode = .aspectFill
        transition(to: scene)
    }
    
    func touchDown(atPoint pos : CGPoint) {
        // Given first refusal on the touch. While the panel is open it swallows everything,
        // including taps meant to dismiss it, so closing the menu can't also start a game.
        // A tap on the gear counts as "outside", which is what closes it again.
        if settingsDropdown?.handleTouch(at: pos) == true {
            return
        }

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
        for t in touches { self.touchDown(atPoint: location(of: t)) }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: location(of: t)) }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: location(of: t)) }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: location(of: t)) }
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
