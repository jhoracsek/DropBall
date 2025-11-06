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
    
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH
    
    //let ball = SKSpriteNode(imageNamed: "ball")
    let top = Top(posY:500)
    let background = SKSpriteNode(imageNamed: "background")
    
    let scoreOverlay = SKSpriteNode(imageNamed: "scoreoverlay")
    
    var homeButton = SKButton(x:0, y:100, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: {} )
    
    let mountains = SKSpriteNode(imageNamed: "mountains")
    
    var scrollOffset : CGFloat = 0
    var iScrollOffset : CGFloat = 0
    
    var velocity : CGFloat = 0
    
    var offsetMax : CGFloat = 0

    //let platform = Platform(pY: -400)
    
    
    
    
    var platforms : [Platform] = []
    var scores = [Score]()
    
    func getScores(){
        let fet: NSFetchRequest<Score> = Score.fetchRequest()
        fet.fetchLimit = 50
        let byScore = NSSortDescriptor(key: #keyPath(Score.score), ascending: false)
        fet.sortDescriptors = [byScore]
        do{
            let context = (UIApplication.shared.delegate as!AppDelegate).coreDataStack.managedContext
            self.scores = try context.fetch(fet)
        } catch let error as NSError{
            print("Fetch error: \(error) description: \(error.userInfo)")
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
        
        //This should be moved into a different function maybe??
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
            
            //divider.position.y += 50
            cropNode.addChild(divider)
            lineHolder.append(divider)
            /*
            let shape = SKShapeNode()
            shape.path = UIBezierPath(roundedRect: CGRect(x: -256, y: 0, width: 512, height: 100), cornerRadius: 32).cgPath
            //shape.position = CGPoint(x:0,y:500+offset)
            shape.fillColor = UIColor.lightGray
            shape.strokeColor = UIColor.darkGray
            shape.lineWidth = 2
            //shape.zPosition=10
            sc.addChild(shape)
            if index >= 4 {
                break
            }
            */
        }
        offsetMax = offset
        cropNode.position = CGPoint(x:6, y:-51)
        cropNode.maskNode = mask
        addChild(cropNode)
        cropNode.zPosition = 40
        
        /*
        let shape = SKShapeNode()
        let w = 554
        let h = 794
        let xO = 6
        let yO = -51
        shape.path = UIBezierPath(roundedRect: CGRect(x: -w/2+xO, y: -h/2+yO, width: w, height: h), cornerRadius: 32).cgPath
        //shape.position = CGPoint(x:0,y:500+offset)
        shape.zPosition = 51
        shape.fillColor = UIColor.lightGray
        shape.strokeColor = UIColor.darkGray
        shape.lineWidth = 2
        addChild(shape)
        */

    }
    
    func goBack(){
        if let scene = SKScene(fileNamed: "StartScene") {
            // Set the scale mode to scale to fit the window
            //scene.scaleMode = .aspectFill
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            let reveal = SKTransition.crossFade(withDuration: 0.5)
            self.view?.presentScene(scene, transition: reveal)
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
        homeButton.checkPressed(pos: pos)
        
        initialPosition = pos.y
        isTouched=true
        deaccelerate = false
        prevY = pos.y
        curY = pos.y
    }
    
    var up = 0
    func touchMoved(toPoint pos : CGPoint) {
        prevY = curY
        curY = pos.y
        
        velocity = curY - prevY
        
        
        fingerPosition = pos.y
        difference = (fingerPosition - initialPosition)
    }
    

    func touchUp(atPoint pos : CGPoint) {
        //prevY = curY
        curY = pos.y
        //trail = prevY - curY
        //trail = 50
        difference=0
        homeButton.unpressed()
        
        for i in holder{
            iScrollOffset = scrollOffset
            i.initPosY = i.posY
            i.update()
        }
        for i in indexHolder{
            iScrollOffset = scrollOffset
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
        //Now holder should not be empty
        //print(holder[0].posY)
        
        /*
        if (holder[0].posY + velocity <= 330){
            var offset:CGFloat = 0
            let initial:CGFloat = 330
            return
        }*/
        print("Offset max:")
        print(offsetMax)
        print(holder[0].posY)
        print("Done")
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
                //lineHolder[index].position.y = i.posY+50
                if(i.posY >= -offsetMax-420 + offset){
                    i.posY = -offsetMax-420 + offset
                    //lineHolder[index].position.y = -offsetMax-420 + offset+50
                }
                if(i.posY <= initial + offset){
                    i.posY = initial + offset
                    //lineHolder[index].position.y = initial + offset + 50
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
