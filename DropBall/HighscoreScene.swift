//
//  GameScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import SpriteKit
import GameplayKit
import CoreData

class HighscoreScene: SKScene {
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH

    let background = SKSpriteNode(imageNamed: "background")
    let scoreOverlay = SKSpriteNode(imageNamed: "scoreoverlay")
    let mountains = SKSpriteNode(imageNamed: "mountains")

    var homeButton = SKButton(x:0, y:100, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: {} )

    /// Scroll speed in points per frame, carried over after the finger lifts.
    var velocity : CGFloat = 0

    /// Total height of the score list, used to clamp how far it can be scrolled.
    var offsetMax : CGFloat = 0

    var scores = [Score]()
    
    func getScores(){
        let fet: NSFetchRequest<Score> = Score.fetchRequest()
        fet.fetchLimit = 50
        let byScore = NSSortDescriptor(key: #keyPath(Score.score), ascending: false)
        fet.sortDescriptors = [byScore]
        do{
            let context = AppDelegate.sharedAppDelegate.coreDataStack.managedContext
            self.scores = try context.fetch(fet)
        } catch let error as NSError{
            print("Fetch error: \(error) description: \(error.userInfo)")
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
    
    var holder : [ScoreDisplay] = []
    var indexHolder : [ScoreDisplay] = []
    var lineHolder : [SKShapeNode] = []
    override func didMove(to view: SKView) {
        getScores()
        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        self.addChild(background)
        background.zPosition = -1
        addChild(scoreOverlay)
        scoreOverlay.zPosition = 10
        
        addChild(mountains)
        mountains.anchorPoint = CGPoint(x:0,y:0)
        mountains.position.x = -WIDTH/2
        mountains.position.y = -HEIGHT/2
        mountains.zPosition = -0.9
        
        homeButton = SKButton(x:(WIDTH/2-75), y:HEIGHT/2-75, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: go_home )
        homeButton.scale(scale: 0.65)
        
        for child in homeButton.getSpriteNode(){
            addChild(child)
        }
        
        // The score rows live inside a crop node so they clip to the overlay panel as they scroll.
        var offset:CGFloat = 0
        let mask = SKSpriteNode(color: SKColor.black, size: CGSize(width: 554, height: 794))
        let cropNode = SKCropNode()

        let initial:CGFloat = 330
        for (index, s) in scores.enumerated() {
            let scoreNum = ScoreDisplay(posX:-150, posY:initial+offset)
            scoreNum.setScore(score: index+1)
            for c in scoreNum.getSpriteNode(){
                cropNode.addChild(c)
                c.zPosition = 50
            }
            scoreNum.update()
            indexHolder.append(scoreNum)
            let score = ScoreDisplay(posX:0, posY:initial+offset)
            score.setScore(score: Int(s.score))
            for c in score.getSpriteNode(){
                cropNode.addChild(c)
                c.zPosition = 50
            }
            score.update()
            holder.append(score)
            offset-=100
            
            let divider = SKShapeNode()
            let path = UIBezierPath()
            path.move(to:CGPoint(x:-500, y:0))
            path.addLine(to:CGPoint(x:500,y:0))
            
            divider.path = path.cgPath
            divider.lineWidth = 4
            divider.strokeColor = .darkGray
            
            divider.zPosition = 51
            
            divider.position.y = initial+50+offset

            cropNode.addChild(divider)
            lineHolder.append(divider)
        }
        offsetMax = offset
        cropNode.position = CGPoint(x:6, y:-51)
        cropNode.maskNode = mask
        addChild(cropNode)
        cropNode.zPosition = 40
    }

    var isTouched=false
    var initialPosition:CGFloat = 0
    var difference:CGFloat = 0
    var deaccelerate = false
    var prevY : CGFloat = 0
    var curY : CGFloat = 0

    func touchDown(atPoint pos : CGPoint) {
        homeButton.checkPressed(pos: pos)

        initialPosition = pos.y
        isTouched=true
        deaccelerate = false
        prevY = pos.y
        curY = pos.y
    }

    func touchMoved(toPoint pos : CGPoint) {
        prevY = curY
        curY = pos.y

        // Velocity is the last frame's finger movement, which becomes the fling speed on lift.
        velocity = curY - prevY
        difference = (pos.y - initialPosition)
    }

    func touchUp(atPoint pos : CGPoint) {
        curY = pos.y
        difference=0
        homeButton.unpressed()

        // Bake the dragged position in as the new resting position before coasting starts.
        for i in holder{
            i.initPosY = i.posY
            i.update()
        }
        for i in indexHolder{
            i.initPosY = i.posY
            i.update()
        }
        isTouched=false
        deaccelerate = true
    }
    
    override func update(_ currentTime: TimeInterval) {
        if scores.count == 0{
            return
        }

        let d:CGFloat = 2
        if(deaccelerate){
            if(velocity < 1.5/d && velocity > -1.5/d){
                velocity = 0
                deaccelerate = false
            }
            if(velocity > 0){
                velocity-=1.5/d
            }
            if(velocity < 0){
                velocity+=1.5/d
            }
            let initial:CGFloat = 330
            var offset:CGFloat = 0
            
            for (index, i) in holder.enumerated() {
                i.posY = i.posY + velocity
                if(i.posY >= -offsetMax-420 + offset){
                    i.posY = -offsetMax-420 + offset
                }
                if(i.posY <= initial + offset){
                    i.posY = initial + offset
                }
                lineHolder[index].position.y = i.posY - 50
                i.initPosY = i.posY
                offset-=100
            }
            offset = 0
            for i in indexHolder{
                i.posY = i.posY + velocity

                if(i.posY >= -offsetMax-420 + offset){
                    i.posY = -offsetMax-420 + offset
                }
                if(i.posY <= initial + offset){
                    i.posY = initial + offset
                }
                i.initPosY = i.posY
                offset-=100
            }
        }


        if(isTouched){
            for (index, i) in holder.enumerated() {
                i.posY = i.initPosY + difference
                lineHolder[index].position.y = i.posY - 50
            }
            for i in indexHolder{
                i.posY = i.initPosY + difference
            }
        }
        for i in holder{
            i.update()
        }
        for i in indexHolder{
            i.update()
        }
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
    
   
}
