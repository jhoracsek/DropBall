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
    
    
    var hitbox: SKSpriteNode
    var hitboxColor = SKColor.init(red: 0.0, green: 1, blue: 0, alpha: 0.5)
    
    
    var xBound : [CGFloat] = []
    var yBound : [CGFloat] = []
    
    var height : CGFloat
    var width : CGFloat
    
    var falls : Bool
    var hitGround = false
    
    // Vertical speeds and accelerations are scaled so they cover the same fraction of the
    // screen on every aspect ratio. See GameViewController.vScale.
    var cAcc : CGFloat = -0.220 * GameViewController.vScale
    var yVel : CGFloat = 0
    
    var hitCooldown : Int = 10
    var cooldownTimer : Int = 0
    
    var reductionX: CGFloat = 1
    var reductionY: CGFloat = 1
    
    static var cameraTranslationX : CGFloat = 0
    static var cameraTranslationY : CGFloat = 0
    
    var hb : CGFloat = 7
    
    var secondarySprite: SKSpriteNode?
    var hasSecondarySprite = false
    var spriteName: String?
    
    var particles: SKEmitterNode?
    var hasParticles = false
    var fingerPosition: CGFloat =  0
    
    
    init(posX: CGFloat, posY: CGFloat, imageNamed: String, falls: Bool){
        self.posX = posX
        self.posY = posY
        
        self.truePosY = posY
        self.sprite = SKSpriteNode(imageNamed: imageNamed)
        
        self.sprite.position.x=posX
        self.sprite.position.y=posY
        
        self.spriteName = imageNamed
        
        self.height = sprite.size.height
        self.width = sprite.size.width
        
        self.xBound.append(posX - width/2)
        self.xBound.append(posX + width/2)
        
        self.yBound.append(posY - height/2)
        self.yBound.append(posY + height/2)
        
        self.falls = falls
        
        sprite.position.x = posX + Entity.cameraTranslationX
        sprite.position.y = posY + Entity.cameraTranslationY
        
        hitbox = SKSpriteNode(color: hitboxColor, size: CGSizeMake(width*reductionX, height*reductionY))
        hitbox.position.x = posX + Entity.cameraTranslationX
        hitbox.position.y = posY + Entity.cameraTranslationY
        hitbox.zPosition = 5
    }
    /*
     
     func setScale(scale: CGFloat){
         var scaling = CGSize()
         scaling.width = scale * self.width
         scaling.height = scale * self.height
         sprite.size = scaling
         
         self.height = sprite.size.height
         self.width = sprite.size.width
         
         return
     }
     */
    func initParticles() -> SKEmitterNode{
        hasParticles = true
        
        let mainBundle = Bundle.main
        let sparkEmitterPath = mainBundle.path(forResource: "Particle", ofType: "sks")
        particles = NSKeyedUnarchiver.unarchiveObject(withFile: sparkEmitterPath!) as! SKEmitterNode
        
        particles!.position = self.sprite.position
        particles!.name = "sparkEmitter"
        //particles!.targetNode = self.sprite
        particles!.particleZPosition = -1
        //particles!.zPosition = -100
        
        self.sprite.addChild(particles!)
        //self.secondarySprite!.addChild(particles!)
        return particles!
    }
    
    
    func initSecondarySprite() -> SKSpriteNode{
        hasSecondarySprite = true
        
        
        secondarySprite = SKSpriteNode(imageNamed: spriteName ?? "ball")
        
        secondarySprite?.position.x = posX + 10
        secondarySprite?.position.y = posY
        secondarySprite?.zPosition = 2
        
        
        var scaling = CGSize()
        scaling.width = sprite.size.height
        scaling.height = sprite.size.width
        secondarySprite?.size = scaling
        
        return secondarySprite!
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
    
    func isColliding(obj: SinglePlatform) -> Bool{
    
        if(self.isColliding(obj : obj.leftPlatform)){
            return true
        }
        return false
    }
    
    func isColliding_endcap(obj: Platform) -> Bool{
        
        if(self.isColliding(obj : obj.leftEndCap) || self.isColliding(obj : obj.rightEndCap)){
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
                
                
                // You can add some value here that sets a cooldown for the pushDown function.
                yVel = 11 * GameViewController.vScale
            }
        }
    }
    
    func pushDown(){
        if(yVel > 0){
            yVel = -yVel
        }
    }
    
    func speedAcc(){
        // Dependent on the velocity!
        // When falling: Velocity is negative. When rising (moving up): Velocity is positive.
        if(yVel < 0){
            //cAcc = -0.420
            cAcc = -0.490 * GameViewController.vScale
            particles!.particleBirthRate = 100//abs(yVel)*10
        }else{
            cAcc = -0.220 * GameViewController.vScale
            particles!.particleBirthRate = 0
        }
    }
    
    func slowAcc(){
        cAcc = -0.220 * GameViewController.vScale
        particles!.particleBirthRate = 0
    }
    
    func setHitGroud(val: Bool){
        if(val == true){
            if( (cooldownTimer > 0) ) {
                hitGround = false
            }
            else{
                cooldownTimer = 50
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
    
    let moveSize:CGFloat = 770
    var prevX = Entity.cameraTranslationX
    func update(){
        //sprite.position.x = mod(posX + Entity.cameraTranslationX, 750)
        if(falls){
            posX = remainder(posX, moveSize)
        }
        
        //sprite.position.x = posX + Entity.cameraTranslationX
        sprite.position.x = posX + Entity.cameraTranslationX
        sprite.position.y = posY + Entity.cameraTranslationY
        
        if(hasSecondarySprite){
            //posX = remainder(posX, 750)
            if(posX > 0){
                secondarySprite?.position.x = posX - moveSize + Entity.cameraTranslationX
                secondarySprite?.position.y = posY + Entity.cameraTranslationY
            }else{
                secondarySprite?.position.x = posX + moveSize + Entity.cameraTranslationX
                secondarySprite?.position.y = posY + Entity.cameraTranslationY
            }
        }
        
        if(hasParticles){
            //particles?.position.x = posX + Entity.cameraTranslationX
            //particles?.position.y = posY + Entity.cameraTranslationY
            // Make the particles trail slightly.
            //particles?.position.x = posX + Entity.cameraTranslationX//prevX
            //particles?.position.y = posY + Entity.cameraTranslationY
        }
        prevX = posX + Entity.cameraTranslationX
        //self.xBound[0] = (posX - width/2) + reduction
        //self.xBound[1] = (posX + width/2) - reduction
        
        //self.yBound[0] = (posY - height/2) + reduction
        //self.yBound[1] = (posY + height/2) - reduction
        
        self.xBound[0] = (posX - (width/2)*reductionX)
        self.xBound[1] = (posX + (width/2)*reductionX)
        
        self.yBound[0] = (posY - (height/2)*reductionY)
        self.yBound[1] = (posY + (height/2)*reductionY)
        
        hitbox.position.x = posX + Entity.cameraTranslationX
        hitbox.position.y = posY + Entity.cameraTranslationY

        hitbox.size.width = width*reductionX
        hitbox.size.height = height*reductionY
        
        
        falling()
        
        return
    }
}
