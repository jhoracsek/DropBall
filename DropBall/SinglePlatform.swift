//
//  Platform.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-07.
//

import Foundation
import SpriteKit
import GameplayKit

class SinglePlatform {
    var leftPlatform : Entity
    
    var pass : Entity
    
    var posY : CGFloat
    var offset : CGFloat
    
    var seperate : CGFloat = 200
    var endOffset : CGFloat = 55
    var sep : CGFloat = 50
    var passed : Bool = false
    
    init(pY: CGFloat){
        self.posY = pY
        offset = 0
        
        self.leftPlatform = Entity(posX:0, posY:self.posY, imageNamed:"platform", falls:false)
        self.leftPlatform.strech(sX: 1000)
        self.pass = Entity(posX:0+offset, posY:self.posY-20, imageNamed:"end", falls:false)
    }
    
    
    func getSpriteNode() -> [SKSpriteNode]{
        
        return [leftPlatform.getSpriteNode()]
    }
    
    
    func update(){
        self.pass.update()
        self.leftPlatform.update()
        return
    }

    
    
}
