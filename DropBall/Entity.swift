//
//  Entity.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import Foundation
import SpriteKit

class Entity {
    var posX : CGFloat
    var posY : CGFloat
    
    var truePosY : CGFloat
    
    var sprite : SKSpriteNode
    
    var xBound : [CGFloat] = []
    var yBound : [CGFloat] = []
    
    var height : CGFloat
    var width : CGFloat
    
    var falls : Bool
    var hitGround = false
    
    var cAcc : CGFloat = -0.220
    var yVel : CGFloat = 0
    
    var hitCooldown : Int = 10
    var cooldownTimer : Int = 0
    
    static var cameraTranslationX : CGFloat = 0
    static var cameraTranslationY : CGFloat = 0
    
    var hb : CGFloat = 7
    
    
    
    
    init(posX: CGFloat, posY: CGFloat, imageNamed: String, falls: Bool){
        self.posX = posX
        self.posY = posY
        self.truePosY = posY
        self.sprite = SKSpriteNode(imageNamed: imageNamed)
        
        self.sprite.position.x=posX
        self.sprite.position.y=posY
        
        
        self.height = sprite.size.height
        self.width = sprite.size.width
        
        self.xBound.append(posX - width/2)
        self.xBound.append(posX + width/2)
        
        self.yBound.append(posY - height/2)
        self.yBound.append(posY + height/2)
        
        self.falls = falls
    }
    
    private func inRect(p:[CGFloat], o1:[CGFloat], o4:[CGFloat]) -> Bool{
        let x = p[0]
        let y = p[1]
        
        if(x >= o1[0] && x <= o4[0]){
            if(y <= o4[1] && y >= o1[1]){
                return true
            }
        }
        
        return false
    }
    func isColliding(obj: Platform) -> Bool{
    
        if(self.isColliding(obj : obj.leftPlatform) || self.isColliding(obj : obj.rightPlatform)){
            return true
        }
        return false
    }
    
    func isColliding(obj: Entity) -> Bool{
        let p1 = [xBound[0], yBound[0]]
        let p2 = [xBound[1], yBound[0]]
        let p3 = [xBound[0], yBound[1]]
        let p4 = [xBound[1], yBound[1]]
        
        let o1 = [obj.xBound[0], obj.yBound[0]]
        let o2 = [obj.xBound[1], obj.yBound[0]]
        let o3 = [obj.xBound[0], obj.yBound[1]]
        let o4 = [obj.xBound[1], obj.yBound[1]]
        
        if(inRect(p:p1,o1:o1,o4:o4)){
            return true
        }
        if(inRect(p:p2,o1:o1,o4:o4)){
            return true
        }
        if(inRect(p:p3,o1:o1,o4:o4)){
            return true
        }
        if(inRect(p:p4,o1:o1,o4:o4)){
            return true
        }
        
        if(inRect(p:o1,o1:p1,o4:p4)){
            return true
        }
        if(inRect(p:o2,o1:p1,o4:p4)){
            return true
        }
        if(inRect(p:o3,o1:p1,o4:p4)){
            return true
        }
        if(inRect(p:o4,o1:p1,o4:p4)){
            return true
        }

        return false;
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
    
    func moveHorizontally(pX: CGFloat){
        posX=posX+pX
        return
    }
    
    func getSpriteNode() -> SKSpriteNode{
        return sprite
    }
    
    //var cAcc = -1
    //var yVel = 0
    func falling(){
        if(falls){
            if(hitGround == false){
                yVel = yVel + cAcc
                posY = posY + yVel
                truePosY = truePosY + yVel
            }else{
                /*  What I probably need to do here is just take the sign on the previous velocity
                    and make set it to (sign)*C where C is some constant velocity. This will ensure
                    that the ball always bounces to the same height. */
                //yVel = -yVel
                yVel = 11
            }
        }
    }
    
    func setHitGroud(val: Bool){
        if(val == true){
            if( (cooldownTimer > 0) ) {
                hitGround = false
            }
            else{
                cooldownTimer = 15
                hitGround = true
            }
            
        }else{
            hitGround = false
        }
    }
    
    func setScale(scale: CGFloat){
        var scaling = CGSize()
        scaling.width = scale * self.width
        scaling.height = scale * self.height
        sprite.size = scaling
        
        self.height = sprite.size.height
        self.width = sprite.size.width
        
        return
    }
    
    func setScale(scaleX: CGFloat, scaleY: CGFloat){
        var scaling = CGSize()
        scaling.width = scaleX * self.width
        scaling.height = scaleY * self.height
        sprite.size = scaling
        
        self.height = sprite.size.height
        self.width = sprite.size.width
        
        return
    }
    
    func strech(sX: CGFloat){
        sprite.size.width = sX
        self.width = sprite.size.width
        
        return
    }
    
    /*
    func setCameraTransY(){
        cameraTranslationY
        return
    }*/
    func checkCollision(){
        if(cooldownTimer > 0){
            cooldownTimer = cooldownTimer - 1;
        }
    }
    
    func update(){
        //sprite.position.x = mod(posX + Entity.cameraTranslationX, 750)
        if(falls){
            posX = remainder(posX, 750)
        }
        sprite.position.x = posX + Entity.cameraTranslationX
        sprite.position.y = posY + Entity.cameraTranslationY
        
        self.xBound[0] = (posX - width/2)
        self.xBound[1] = (posX + width/2)
        
        self.yBound[0] = (posY - height/2)
        self.yBound[1] = (posY + height/2)
        

        
        falling()
        
        return
    }
}
