//
//  Platform.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-07.
//

import Foundation
import SpriteKit
import GameplayKit

class Platform {
    var leftPlatform : Entity
    var rightPlatform : Entity
    
    var leftEndCap : Entity
    var rightEndCap : Entity
    
    var pass : Entity
    
    var posY : CGFloat
    var offset : CGFloat
    
    var seperate : CGFloat = 200
    var endOffset : CGFloat = 55
    var sep : CGFloat = 50
    var passed : Bool = false
    
    init(pY: CGFloat){
        self.posY = pY
        offset = CGFloat(Int.random(in:-100...100))
        
        self.leftPlatform = Entity(posX:seperate+262.5+offset+sep, posY:self.posY, imageNamed:"platform", falls:false)
        self.leftPlatform.strech(sX: 750)
        //self.leftPlatform.setScale(scaleX: 6, scaleY: 1)
        
        self.rightPlatform = Entity(posX:-262.5-seperate+offset-sep, posY:self.posY, imageNamed:"platform", falls:false)
        self.rightPlatform.strech(sX: 750)
        //self.rightPlatform.setScale(scaleX: 6, scaleY: 1)
        
        self.pass = Entity(posX:0+offset, posY:self.posY-20, imageNamed:"end", falls:false)
    
        self.leftEndCap =  Entity(posX:0+offset+endOffset+sep, posY:self.posY, imageNamed:"end", falls:false)
        //self.leftEndCap.setScale(scale: -1)
        self.leftEndCap.setScale(scaleX: -1, scaleY: 1)
        self.rightEndCap = Entity(posX:0+offset-endOffset-sep, posY:self.posY, imageNamed:"end", falls:false)
        
        self.rightEndCap.reductionX = 0.75
        self.rightEndCap.reductionY = 0.925
        self.leftEndCap.reductionX = 0.75
        self.leftEndCap.reductionY = 0.925
        //self.leftEndCap.xBound[0] = reduction
        //self.leftEndCap.xBound[1] = reduction
        //self.leftEndCap.yBound[0] = reduction
        //self.leftEndCap.yBound[1] = reduction
        
        //self.rightEndCap.xBound[0] = reduction
        //self.rightEndCap.xBound[1] = reduction
        //self.rightEndCap.yBound[0] = reduction
        //self.rightEndCap.yBound[1] = reduction
    }
    
    func getSpriteNode() -> [SKSpriteNode]{
        
        return [leftEndCap.getSpriteNode(), rightEndCap.getSpriteNode(), leftPlatform.getSpriteNode(),rightPlatform.getSpriteNode()]
    }
    
    
    func update(){
        self.pass.update()
        self.leftPlatform.update()
        self.rightPlatform.update()
        self.leftEndCap.update()
        self.rightEndCap.update()
        return
    }

    
    
}
