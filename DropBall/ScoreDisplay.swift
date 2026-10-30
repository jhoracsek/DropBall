//
//  Entity.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import Foundation
import SpriteKit

class ScoreDisplay {
    var posX : CGFloat
    var posY : CGFloat
    var initPosY : CGFloat
    
    //var height : CGFloat
    //var width : CGFloat
    
    var sprites : [SKSpriteNode]
    // Up to three digit nodes, created once and reused; `sprites` holds the ones currently shown.
    private var digitNodes : [SKSpriteNode] = []
    static var cameraTranslationX : CGFloat = 0
    static var cameraTranslationY : CGFloat = 0

    var score: Int = 0
    
    var factor : CGFloat = 1
    
    
    
    
    init(posX: CGFloat, posY: CGFloat, factor: CGFloat = 1){
        self.posX = posX
        self.posY = posY
        self.initPosY = posY
        self.sprites = [];
        self.factor = factor
        //self.height = sprite.size.height
        //self.width = sprite.size.width
        
        var scaling = CGSize()
        scaling.width = 64*factor
        scaling.height = 64*factor
        for _ in 0..<3 {
            let node = SKSpriteNode(texture: TextureCache.texture(named: "0"))
            node.size = scaling
            digitNodes.append(node)
        }
        self.sprites.append(digitNodes[0])
    }
    
    func addScore(){
        score+=1
        updateSprite()
        
    }
    
    func setScore(score: Int){
        self.score = score
        updateSprite()
    }
    
    func updateSprite(){
        /*
            x in 0-9         -> x/10 = 0
            x in 10-99       -> x/10 in 1-9
            x in 100-999     -> x/10 in 10-99
         */
        
        let switchNum: Int = score/10
        let digits: [Int]
        
        if(switchNum == 0){
            digits = [score]
        }else if (switchNum <= 9){
            digits = [score/10, score%10]
        }else{
            digits = [score/100, (score/10)%10, score%10]
        }
        
        // Callers remove the old sprites and add the new ones; detaching here too
        // guarantees a reused node never gets added to a scene twice.
        for node in digitNodes {
            node.removeFromParent()
        }
        
        sprites.removeAll()
        for (index, digit) in digits.enumerated() {
            let node = digitNodes[index]
            node.texture = TextureCache.texture(named: String(digit))
            sprites.append(node)
        }
        
    }
    
    
    //testing function
    func setPos(pX: CGFloat, pY: CGFloat){
        posX=pX
        posY=pY
        
        return
    }
    
    func setPos(pY: CGFloat){
        posY=pY
        return
    }

    
    func getSpriteNode() -> [SKSpriteNode]{
        return sprites
    }

    
    func update(){
        let switchNum: Int = score/10
        if(switchNum == 0){
            sprites[0].position.x = posX
            sprites[0].position.y = posY
        }else if (switchNum <= 9){
            sprites[0].position.x = posX-25*factor
            sprites[0].position.y = posY
            
            sprites[1].position.x = posX+25*factor
            sprites[1].position.y = posY
            
        }else{
            sprites[0].position.x = posX-50*factor
            sprites[0].position.y = posY
            
            sprites[1].position.x = posX
            sprites[1].position.y = posY
            
            sprites[2].position.x = posX+50*factor
            sprites[2].position.y = posY
        }
        
        return
    }
}
