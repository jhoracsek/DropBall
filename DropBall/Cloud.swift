//
//  Cloud.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-07.
//

import Foundation
import SpriteKit
import GameplayKit

class Cloud {
    var cloud : Entity
    
    var posY : CGFloat
    var offset : CGFloat
    var speed : CGFloat
    
    var left : Bool
    
    var modVal : CGFloat
    
    var coolDownMax : Int
    var coolDown : Int
    var wobble: CGFloat = 0
    var baseY: CGFloat
    
    var moveUp: Bool = true
    
    var opacity: CGFloat = 0
    
    init(pY: CGFloat, cloudNum: Int, prob: CGFloat = 0.75){
        left = Bool.random()
        let speedOffset = CGFloat.random(in: -0.01...0.2)
        let wobbleOffset = CGFloat.random(in: 0.01...0.09)
        opacity = CGFloat.random(in: 0.25...0.55)
        switch(cloudNum){
            case 1:
                speed = 0.52+speedOffset
                coolDownMax = Int.random(in: 900...1800)
                wobble = 0.05

                break
            
            case 2:
                speed = 0.69+speedOffset
                coolDownMax = Int.random(in: 500...1500)
                wobble = 0.05
                break
                
            case 3:
                speed = 0.69+speedOffset
                coolDownMax = Int.random(in: 500...1500)
                wobble = 0.05
                break
                
            case 4:
                speed = 0.69+speedOffset
                coolDownMax = Int.random(in: 500...1500)
                wobble = 0.05
                break
                
            case 5:
                speed = 0.6+speedOffset
                coolDownMax = Int.random(in: 500...1000)
                wobble = 0.05
                break
                
            default:
                speed = 0.75+(speedOffset*2)
                coolDownMax = Int.random(in: 300...600)
                wobble = 0.1+wobbleOffset
                break
            
        }
        self.posY = pY
        let verticleOffset = CGFloat(Int.random(in: -100...125)) * GameViewController.vScale

        offset = CGFloat(Int.random(in:0...200))

        // `prob` is the chance of starting offscreen and drifting in after a cooldown.
        // The menu passes the default so some clouds are already visible on arrival; the
        // game passes 0 so every cloud drifts in.
        let randomNum = CGFloat.random(in: 0...1)
        var onScreen = false

        if(randomNum >= prob){
            onScreen = true
        }

        if(left){
            if(onScreen){
                coolDown = 0
                let addOffset = CGFloat.random(in: -100...300)
                self.cloud = Entity(posX:offset+addOffset, posY:self.posY+verticleOffset, imageNamed:"cloud"+String(cloudNum), falls:false)
            }else{
                coolDown = coolDownMax
                self.cloud = Entity(posX:700+offset, posY:self.posY+verticleOffset, imageNamed:"cloud"+String(cloudNum), falls:false)
            }
            modVal = -1*(700 + offset)
        }else{
            if(onScreen){
                coolDown = 0
                let addOffset = CGFloat.random(in: -100...300)
                self.cloud = Entity(posX:-offset-addOffset, posY:self.posY+verticleOffset, imageNamed:"cloud"+String(cloudNum), falls:false)
            }else{
                coolDown = coolDownMax
                self.cloud = Entity(posX:-700-offset, posY:self.posY+verticleOffset, imageNamed:"cloud"+String(cloudNum), falls:false)
            }
            modVal = -1*(-700 - offset)
        }

        cloud.getSpriteNode().alpha = opacity
        baseY = pY + verticleOffset
    }

    func getSpriteNode() -> SKSpriteNode{
        return cloud.getSpriteNode()
    }

    func update(){
        // Clouds drift across the screen in the direction opposite the side they spawned on,
        // then wrap back and wait out a cooldown before crossing again.
        if(coolDown == 0){
            if (left){
                if (self.cloud.posX < modVal){
                    self.cloud.posX = -1*modVal
                    coolDown = coolDownMax/2
                }else{
                    self.cloud.posX -= speed
                }
                
            }else{
                if (self.cloud.posX > modVal){
                    self.cloud.posX = -1*modVal
                    coolDown = coolDownMax/2
                }else{
                    self.cloud.posX += speed
                }
            }
        }else{
            coolDown-=1
        }
        
        // Both the wobble amplitude and its per-frame speed are scaled, which keeps the
        // drift looking identical on every aspect ratio and leaves its period unchanged.
        let wobbleAmplitude = 7 * GameViewController.vScale
        let wobbleStep = wobble * GameViewController.vScale

        if (cloud.posY > baseY + wobbleAmplitude){
            moveUp = false
        }
        
        if (cloud.posY < baseY - wobbleAmplitude){
            moveUp = true
        }

        if (moveUp){
            cloud.posY+=wobbleStep
        }else{
            cloud.posY-=wobbleStep
        }
        
        // Clouds follow the camera at 95% so they parallax slightly against the playfield.
        cloud.sprite.position.x = cloud.posX + Entity.cameraTranslationX
        cloud.sprite.position.y = cloud.posY +  0.95*Entity.cameraTranslationY
    }
}
