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
    
    var falls : Bool {
        didSet {
            // Losing stops the ball falling, which would otherwise leave it frozen at
            // whatever stretch it had at the moment of impact. Settle it back to round.
            if !falls && oldValue {
                sprite.yScale = 1
                sprite.xScale = 1
                secondarySprite?.yScale = 1
                secondarySprite?.xScale = 1
            }
        }
    }
    var hitGround = false
    
    // Vertical speeds and accelerations are scaled so they cover the same fraction of the
    // screen on every aspect ratio. See GameViewController.vScale.
    var cAcc : CGFloat = -0.220 * GameViewController.vScale
    var yVel : CGFloat = 0

    /// Horizontal speed in points per frame, derived in update(). Unlike yVel this isn't
    /// integrated here — GameScene drives posX directly — so it's measured rather than set.
    private(set) var xVel : CGFloat = 0
    private var previousPosX : CGFloat = 0
    
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
    private var wind: WindStreaks?
    var fingerPosition: CGFloat =  0

    // MARK: - Trail and squash tuning

    /// Master switch for the wind arcs that sweep around the ball at speed. Off for now:
    /// the effect works but still wants tuning, so it stays parked rather than deleted.
    /// Flip to true to bring it back — see WindStreaks.swift for its own constants.
    let windEnabled = false

    /// Fall speed, in points per frame, at which the trail and the stretch reach full
    /// strength. Roughly the fastest the ball travels between two platforms while boosting.
    let referenceSpeed : CGFloat = 18 * GameViewController.vScale

    /// How far the ball stretches at full speed. 0.16 means 16% taller and correspondingly
    /// narrower. Raise for a more cartoonish feel, lower for a subtler one. Also sets the
    /// depth of the landing squash, so the two stay in proportion.
    let maxStretch : CGFloat = 0.16

    /// Sideways speed, in points per frame, at which the horizontal squish reaches full
    /// strength. Not scaled by vScale: the scene is 750 wide on every device, so horizontal
    /// speeds are already device-independent.
    let horizontalReferenceSpeed : CGFloat = 20

    /// How far the ball flattens when travelling sideways at full tilt. Kept below
    /// maxStretch because sideways motion is a drift rather than a plunge.
    let maxHorizontalStretch : CGFloat = 0.11

    /// How far below the ball's centre the trail is emitted from, as a fraction of its
    /// height. 0 emits from the centre; 0.5 would be exactly the bottom edge.
    let trailOriginDepth : CGFloat = 0

    /// Width of the band particles spawn across, as a fraction of the ball's width. Low
    /// values keep it a narrow column; raising it spreads the particles out to the flanks.
    let trailSpread : CGFloat = 0.3

    /// Particles emitted per second at full speed. The single biggest lever on how heavy
    /// the trail reads.
    let trailBirthRate : CGFloat = 260

    /// Length of the landing squash, in frames.
    let squashDuration : CGFloat = 9

    /// Counts down from squashDuration after each bounce.
    private var squashFrames : CGFloat = 0

    /// True while the player is holding to accelerate the ball.
    private var boosting = false

    
    
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

        previousPosX = posX
    }
    /// Attaches the speed-boost trail to this entity.
    ///
    /// `target` should be the scene, and becomes both the emitter's parent and its target
    /// node. Being the target is what leaves the particles behind in the world instead of
    /// dragging them along with the ball. Being the parent keeps the emitter outside the
    /// ball's transform, so the squash and stretch doesn't deform the particles too —
    /// updateTrail() moves it to follow the ball by hand instead.
    @discardableResult
    func initParticles(in target: SKNode) -> SKEmitterNode?{
        // SKEmitterNode(fileNamed:) replaces the deprecated NSKeyedUnarchiver path, and
        // returns nil rather than trapping if the .sks is ever missing from the bundle.
        guard let emitter = SKEmitterNode(fileNamed: "Particle") else {
            return nil
        }

        particles = emitter

        emitter.name = "sparkEmitter"
        emitter.targetNode = target

        // In scene space the trail needs to sit above the platforms (1) but still behind
        // the ball itself (2).
        emitter.particleZPosition = 1.5

        // A trail should read as a short streak rather than a long-lived plume, so the
        // particles are small, die quickly, and shrink and fade as they go.
        emitter.particleLifetime = 0.45
        emitter.particleLifetimeRange = 0.2
        emitter.particleScale = 0.28
        emitter.particleScaleRange = 0.14
        emitter.particleScaleSpeed = -0.55

        // alphaSpeed is paired with particleLifetime: at -1.4 over 0.45s a particle loses
        // just about all of its 0.6 starting alpha, so it fades out right as it dies rather
        // than vanishing early or being cut off still visible.
        emitter.particleAlpha = 0.6
        emitter.particleAlphaSpeed = -1.4

        emitter.particlePositionRange = CGVector(dx: width * trailSpread, dy: height * 0.1)

        emitter.emissionAngle = .pi / 2
        emitter.emissionAngleRange = 0.22

        // Off until the player actually boosts; updateTrail() drives it from there.
        emitter.particleBirthRate = 0

        target.addChild(emitter)
        return emitter
    }

    /// Adds the arcs of wind that sweep around the ball at speed. Like the trail, `target`
    /// should be the scene, so the effect is unaffected by the ball's squash and stretch.
    func initWind(in target: SKNode){
        guard windEnabled else { return }
        wind = WindStreaks(ballRadius: width / 2, in: target)
    }

    /// Freezes or resumes the cosmetic effects, including particles already in flight.
    ///
    /// Needed because pausing returns early from GameScene.update() before Entity.update()
    /// runs, so the trail has no other opportunity to notice it should stop.
    func setEffectsPaused(_ paused: Bool){
        particles?.isPaused = paused
        wind?.isPaused = paused
    }

    /// Stops the trail emitting for good, letting whatever is already in flight die out.
    ///
    /// Losing clears `falls`, which gates updateTrail() out of the update loop entirely, so
    /// the birth rate has to be cleared here rather than left for the next frame.
    func stopEffects(){
        boosting = false
        particles?.particleBirthRate = 0
    }

    /// 0 when the ball is barely moving, 1 once it reaches referenceSpeed. Drives the
    /// trail, the wind and the stretch so all three stay in step with each other.
    private var fallSpeedRatio : CGFloat {
        min(abs(yVel) / referenceSpeed, 1)
    }

    /// The world wraps horizontally, so the ball is drawn a second time one screen width
    /// away. That way it is already visible on the far edge as it crosses the seam.
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
    
    func getSpriteNode() -> SKSpriteNode{
        return sprite
    }

    func falling(){
        if(falls){
            if(hitGround == false){
                yVel = yVel + cAcc
                posY = posY + yVel
                truePosY = truePosY + yVel
            }else{
                // Landing always sets the same upward velocity rather than reflecting the
                // impact speed, so every bounce reaches the same height.
                yVel = 11 * GameViewController.vScale
            }
        }
    }
    
    func pushDown(){
        if(yVel > 0){
            yVel = -yVel
        }
    }
    
    /// Steepens gravity while the player holds the screen, but only on the way down —
    /// velocity is negative when falling and positive when rising.
    func speedAcc(){
        if(yVel < 0){
            cAcc = -0.490 * GameViewController.vScale
            boosting = true
        }else{
            cAcc = -0.220 * GameViewController.vScale
            boosting = false
        }
    }
    
    func slowAcc(){
        cAcc = -0.220 * GameViewController.vScale
        boosting = false
    }

    /// Ramps the trail with the ball's actual speed.
    ///
    /// The camera keeps the ball at a fixed point on screen and scrolls the world past it,
    /// so a particle has to travel upward at exactly the world's scroll speed to look like
    /// it is hanging still in the air. That speed is the ball's fall speed. The .sks used a
    /// fixed 100 pt/s, which at full boost is a small fraction of the real scroll rate —
    /// which is why the old trail looked like it was being dragged along.
    private func updateTrail(){
        guard let particles = particles else { return }

        // The emitter is parented to the scene rather than the ball, so it has to be moved
        // onto the ball by hand each frame. Sitting low on the ball is what lets the stream
        // climb past its sides. Done before the early return so the emitter is already in
        // position the instant a boost starts.
        particles.position = CGPoint(x: sprite.position.x,
                                     y: sprite.position.y - height * trailOriginDepth)

        guard boosting && yVel < 0 else {
            particles.particleBirthRate = 0
            return
        }

        // Easing in with speed keeps the trail from popping on the instant a hold registers.
        particles.particleBirthRate = trailBirthRate * fallSpeedRatio

        // yVel is per frame; the emitter wants points per second.
        particles.particleSpeed = abs(yVel) * 60
        particles.particleSpeedRange = abs(yVel) * 12
    }

    /// Stretches the ball along its direction of travel and squashes it on impact.
    ///
    /// This only touches xScale/yScale, which multiply the sprite's size purely for
    /// drawing. `width` and `height` — and so the collision bounds — are left alone, so the
    /// effect can't change how the game actually plays.
    private func updateSquashStretch(){
        let isLanding = squashFrames > 0
        let rawFactor: CGFloat

        if isLanding {
            // Landing: flatten and spread, easing back to round over squashDuration frames.
            rawFactor = 1 - maxStretch * (squashFrames / squashDuration)
            squashFrames -= 1
        } else {
            // In flight the two axes pull against each other: falling fast makes the ball
            // taller and narrower, travelling fast sideways makes it wider and flatter. A
            // mostly-vertical drop still stretches; a hard sideways swipe flattens it; doing
            // both at once partly cancels, which is what you'd expect.
            let vertical = maxStretch * fallSpeedRatio
            let horizontal = maxHorizontalStretch * min(abs(xVel) / horizontalReferenceSpeed, 1)
            rawFactor = 1 + vertical - horizontal
        }

        // Guards against the ball inverting if the tuning constants are pushed far up.
        let yFactor = max(0.4, rawFactor)

        // Scaling one axis by the reciprocal of the other preserves the ball's apparent
        // volume, so it reads as deforming rather than just growing.
        let xFactor = 1 / yFactor

        // The sprite is anchored at its centre, so a squash would otherwise lift the ball's
        // bottom edge off the platform it just landed on. Dropping the centre by half the
        // lost height keeps it planted. This only applies on landing — a mid-air flatten
        // from sideways motion should stay centred on the ball.
        let groundingOffset = isLanding ? -(height / 2) * (1 - yFactor) : 0

        sprite.yScale = yFactor
        sprite.xScale = xFactor
        sprite.position.y += groundingOffset

        secondarySprite?.yScale = yFactor
        secondarySprite?.xScale = xFactor
        secondarySprite?.position.y += groundingOffset
    }

    func setHitGroud(val: Bool){
        if(val == true){
            if( (cooldownTimer > 0) ) {
                hitGround = false
            }
            else{
                cooldownTimer = 50
                hitGround = true

                // A real bounce, as opposed to a collision still inside its cooldown.
                squashFrames = squashDuration
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
    
    func checkCollision(){
        if(cooldownTimer > 0){
            cooldownTimer = cooldownTimer - 1;
        }
    }
    
    /// Width of the wrap-around world, in scene units.
    let moveSize:CGFloat = 770

    func update(){
        // Only the ball wraps; platforms and clouds hold a fixed world position.
        if(falls){
            posX = remainder(posX, moveSize)
        }

        // Measure sideways speed from the change in position. Crossing the wrap seam moves
        // posX by a full world width in one frame, so fold that back in rather than letting
        // it register as an enormous spike.
        var xDelta = posX - previousPosX
        if(xDelta > moveSize/2){
            xDelta -= moveSize
        } else if(xDelta < -moveSize/2){
            xDelta += moveSize
        }
        xVel = xDelta
        previousPosX = posX

        sprite.position.x = posX + Entity.cameraTranslationX
        sprite.position.y = posY + Entity.cameraTranslationY

        // Draw the wrap-around copy on whichever side the ball is heading towards.
        if(hasSecondarySprite){
            if(posX > 0){
                secondarySprite?.position.x = posX - moveSize + Entity.cameraTranslationX
                secondarySprite?.position.y = posY + Entity.cameraTranslationY
            }else{
                secondarySprite?.position.x = posX + moveSize + Entity.cameraTranslationX
                secondarySprite?.position.y = posY + Entity.cameraTranslationY
            }
        }

        self.xBound[0] = (posX - (width/2)*reductionX)
        self.xBound[1] = (posX + (width/2)*reductionX)
        
        self.yBound[0] = (posY - (height/2)*reductionY)
        self.yBound[1] = (posY + (height/2)*reductionY)
        
        hitbox.position.x = posX + Entity.cameraTranslationX
        hitbox.position.y = posY + Entity.cameraTranslationY

        hitbox.size.width = width*reductionX
        hitbox.size.height = height*reductionY

        // These are purely cosmetic and only meaningful for the ball, which is the only
        // entity that falls.
        if(falls){
            updateTrail()
            wind?.update(center: sprite.position,
                         speedRatio: fallSpeedRatio,
                         active: boosting && yVel < 0)
            updateSquashStretch()
        }

        falling()
    }
}
