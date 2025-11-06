//
//  Top.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-08.
//

import Foundation
import SpriteKit

class Top : Entity{
    
    var velocity : CGFloat = 0.5
    var limit : CGFloat
    var increase : Bool = false
    var boostTimer : Int = 20
    
    init(posY: CGFloat){
        //init(posX: CGFloat, posY: CGFloat, imageNamed: String, falls: Bool)
        self.limit = posY
        super.init(posX:0, posY: posY, imageNamed: "line", falls: false)
    }
    func boost(){
        increase = true
    }
    func increaseVel(){
        //print(velocity)
        velocity = velocity + 0.01
    }
    
    override func update(){
        if(boostTimer == 0 || posY >= limit){
            increase = false
            boostTimer = 20
        }
        if(increase == true){
            posY = posY + 3
            boostTimer = boostTimer - 1
        }else{
            posY = posY - velocity
        }
        sprite.position.y = posY
        return
    }
    
}
