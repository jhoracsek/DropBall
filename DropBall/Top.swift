//
//  Top.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-08.
//

import Foundation
import SpriteKit

class Top : Entity{
    
    var velocity : CGFloat = 0.5 * GameViewController.vScale
    var limit : CGFloat
    var increase : Bool = false
    var boostTimer : Int = 20
    
    init(posY: CGFloat){
        self.limit = posY
        super.init(posX:0, posY: posY, imageNamed: "line", falls: false)
    }

    /// Nudges the line back up briefly, as a reward for clearing a platform.
    func boost(){
        increase = true
    }

    /// Makes the line creep down faster, so the game speeds up as the score climbs.
    func increaseVel(){
        velocity = velocity + 0.01 * GameViewController.vScale
    }
    
    override func update(){
        if(boostTimer == 0 || posY >= limit){
            increase = false
            boostTimer = 20
        }
        if(increase == true){
            posY = posY + 3 * GameViewController.vScale
            boostTimer = boostTimer - 1
        }else{
            posY = posY - velocity
        }
        sprite.position.y = posY
    }
}
