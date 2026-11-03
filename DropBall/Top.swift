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

    /// Puts the line `designGap` above `ball`, centre to centre, at reference height — and
    /// sets that as the highest a boost can push it back up to.
    ///
    /// What ends a run is the distance from the line's lower edge to the top of the ball,
    /// so that's what has to scale with vScale for the line to take the same time to arrive
    /// on every screen. The ball's radius and the line's thickness are fixed sizes, so
    /// scaling the centre-to-centre distance instead gave taller screens a few more points of
    /// headroom: about a quarter of a second's extra survival on an iPhone 15 over an 8 Plus.
    func place(above ball: Entity, by designGap: CGFloat){
        let contactDistance = ball.collisionRadius + height/2
        posY = (designGap - contactDistance) * GameViewController.vScale + contactDistance
        limit = posY
        sprite.position.y = posY
    }

    /// Nudges the line back up briefly, as a reward for clearing a platform.
    func boost(){
        increase = true
    }

    /// Makes the line creep down faster, so the game speeds up as the score climbs.
    func increaseVel(){
        velocity = velocity + 0.01 * GameViewController.vScale
    }
    
    /// Whether the descending line has reached the ball.
    ///
    /// Unlike every other entity, the line lives in screen space: its update() writes
    /// straight to `sprite.position` instead of going through the camera offset, so it
    /// stays put on screen while the world scrolls behind it. The ball has to be converted
    /// into that same space to compare them.
    ///
    /// Only the vertical axis is tested. The line spans the full width of the scene, so
    /// there is no horizontal case where the ball could slip past it.
    func hasCaught(ball: Entity) -> Bool {
        let ballScreenY = ball.posY + Entity.cameraTranslationY
        return ballScreenY + ball.collisionRadius >= posY - height/2
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
