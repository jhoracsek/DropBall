//
//  ScoreDisplay.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import Foundation
import SpriteKit

/// Renders a number as a row of per-digit sprites, since the game uses custom digit art
/// rather than a font.
class ScoreDisplay {
    var posX : CGFloat
    var posY : CGFloat
    var initPosY : CGFloat

    var sprites : [SKSpriteNode]

    var score: Int = 0

    /// Scales the digit art; 1 is the in-game HUD size, 0.5 the smaller lose-screen size.
    var factor : CGFloat = 1

    init(posX: CGFloat, posY: CGFloat, factor: CGFloat = 1){
        self.posX = posX
        self.posY = posY
        self.initPosY = posY
        self.sprites = [];
        self.sprites.append(SKSpriteNode(imageNamed: "0"))
        self.factor = factor

        var scaling = CGSize()
        scaling.width = 64*factor
        scaling.height = 64*factor
        sprites[0].size = scaling
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
        
        sprites.removeAll()
        let switchNum: Int = score/10
        var scaling = CGSize()
        scaling.width = 64*factor
        scaling.height = 64*factor
        
        if(switchNum == 0){
            sprites.append(SKSpriteNode(imageNamed: String(score)))
            sprites[0].size = scaling
            
        }else if (switchNum <= 9){
            let firstDigit:Int = score/10
            let secondDigit:Int = score%10
            sprites.append(SKSpriteNode(imageNamed: String(firstDigit)))
            sprites.append(SKSpriteNode(imageNamed: String(secondDigit)))
            sprites[0].size = scaling
            sprites[1].size = scaling
            
        }else{
            let firstDigit:Int = score/100
            let secondDigit:Int = (score/10)%10
            let thirdDigit:Int = score%10
            sprites.append(SKSpriteNode(imageNamed: String(firstDigit)))
            sprites.append(SKSpriteNode(imageNamed: String(secondDigit)))
            sprites.append(SKSpriteNode(imageNamed: String(thirdDigit)))
            sprites[0].size = scaling
            sprites[1].size = scaling
            sprites[2].size = scaling
        }
        
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
    }
}
