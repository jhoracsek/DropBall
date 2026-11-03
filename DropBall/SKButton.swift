//
//  SKButton.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-08-28.
//

import Foundation
import SpriteKit

class SKButton {
    var x : CGFloat
    var y : CGFloat

    /// Where the button was laid out to sit, before any move to keep it inside the safe
    /// frame. keep(inside:) always works from here, so repeated relayouts — a window rotating
    /// back and forth — land in the same place each time rather than drifting.
    private let designPosition: CGPoint
    
    var unclickedSprite : SKSpriteNode
    var clickedSprite : SKSpriteNode
    
    var boundX1 : CGFloat
    var boundX2 : CGFloat
    var boundY1 : CGFloat
    var boundY2 : CGFloat
    
    var isPressed : Bool
    
    var test_function: ()->()
    
    var disabled = false
    
    init(x: CGFloat, y: CGFloat, unclick: String, click: String, test_function : @escaping ()->() ){
        self.x = x
        self.y = y
        self.designPosition = CGPoint(x: x, y: y)
        
        self.unclickedSprite = SKSpriteNode(imageNamed: unclick)
        self.clickedSprite = SKSpriteNode(imageNamed: click)
        
        self.unclickedSprite.position.x = x
        self.unclickedSprite.position.y = y
        self.unclickedSprite.zPosition = 30
        self.clickedSprite.position.x = x
        self.clickedSprite.position.y = y
        self.clickedSprite.zPosition = 29
        
        let halfWidth = unclickedSprite.size.width/2
        let halfHeight = unclickedSprite.size.height/2
    
        boundX1 = self.x - halfWidth
        boundX2 = self.x + halfWidth
        
        boundY1 = self.y - halfHeight
        boundY2 = self.y + halfHeight
        
        self.test_function = test_function
        
        isPressed = false
    }
    
    func within(pos:CGPoint) -> Bool{
        if pos.x < boundX1 || pos.x > boundX2 || pos.y < boundY1 || pos.y > boundY2{
            return false
        }
        return true
    }
    
    func pressed(){
        isPressed = true
        self.unclickedSprite.zPosition = 29
        self.clickedSprite.zPosition = 30
    }
    
    func unpressed(){
        if (isPressed && !disabled){
            test_function()
        }
        isPressed = false
        self.unclickedSprite.zPosition = 30
        self.clickedSprite.zPosition = 29
    }

    /// Returns whether the press landed on this button. Most callers just want the side
    /// effect, so the result is discardable.
    @discardableResult
    func checkPressed(pos:CGPoint)->Bool{
        if within(pos:pos){
            pressed()
            return true
        }
        else{
            unpressed()
            return false
        }
    }
    
    func scale(scale:CGFloat){
        var scaling = CGSize()
        scaling.width = scale * unclickedSprite.size.width
        scaling.height = scale * unclickedSprite.size.height
        unclickedSprite.size = scaling
        clickedSprite.size = scaling
    }
    
    /// Moves the button, carrying its touch area along unchanged.
    func move(to point: CGPoint){
        let dx = point.x - x
        let dy = point.y - y
        x = point.x
        y = point.y

        unclickedSprite.position = point
        clickedSprite.position = point

        boundX1 += dx
        boundX2 += dx
        boundY1 += dy
        boundY2 += dy
    }

    /// Places the button at its designed position, moved the least distance needed to sit
    /// wholly inside `frame`, `margin` clear of its edges. A button whose designed position
    /// already fits stays exactly there, so a layout that fits a screen is left alone and only
    /// screens where it doesn't change.
    func keep(inside frame: CGRect, margin: CGFloat = 12){
        let halfWidth = unclickedSprite.size.width/2 + margin
        let halfHeight = unclickedSprite.size.height/2 + margin
        move(to: CGPoint(x: min(max(designPosition.x, frame.minX + halfWidth), frame.maxX - halfWidth),
                         y: min(max(designPosition.y, frame.minY + halfHeight), frame.maxY - halfHeight)))
    }

    func toggleDisable(){
        disabled = !disabled
        if(disabled){
            self.unclickedSprite.alpha = 0
            self.clickedSprite.alpha = 0
        }else{
            self.unclickedSprite.alpha = 1
            self.clickedSprite.alpha = 1
        }
    }
    
    func disable(){
        disabled=true
        self.unclickedSprite.alpha = 0
        self.clickedSprite.alpha = 0
    }
    
    func getSpriteNode() -> [SKSpriteNode]{
        return [unclickedSprite, clickedSprite]
    }
}
