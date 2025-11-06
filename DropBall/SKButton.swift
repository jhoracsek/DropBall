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
    
    func toggleDisable(){
        //ZPosition adjustment...
        disabled = !disabled
        if(disabled){
            self.unclickedSprite.alpha = 0
            self.clickedSprite.alpha = 0
            //self.unclickedSprite.zPosition = -30
            //self.clickedSprite.zPosition = -29
        }else{
            self.unclickedSprite.alpha = 1
            self.clickedSprite.alpha = 1
            //self.unclickedSprite.zPosition = 30
            //self.clickedSprite.zPosition = 29
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
    
    func update(){
        
    }
    
    
}
