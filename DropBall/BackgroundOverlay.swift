//
//  BackgroundOverlay.swift
//  DropBall
//

import Foundation
import SpriteKit
import QuartzCore

/// The texture layer that sits over the sky gradient and behind the mountains.
///
/// Two bands that drift in opposite directions: the dots on top move left, the clouds
/// beneath move right and slower, so the two shear against each other and the background
/// never quite repeats itself.
///
/// Shared because four scenes draw the same background stack, and the scrolling is worth
/// getting right in one place rather than copying it around.
enum BackgroundOverlay {

    /// Where the layer sits for scenes using the default background arrangement.
    /// StartScene orders its layers differently and passes its own.
    static let defaultZ: CGFloat = -0.95

    /// How strongly the texture reads over the gradient. Applied on top of whatever alpha
    /// is already baked into the art, so the two multiply.
    static let opacity: CGFloat = 0.25

    /// Drift speeds in points per second. Slow on purpose — this should register as
    /// movement without drawing the eye. The bottom is slower still, so the parallax reads
    /// as the clouds being further away than the specks.
    static let topSpeed: CGFloat = 15
    static let bottomSpeed: CGFloat = 9

    /// Width of the single-piece overlay these two bands were cut from. Both are scaled by
    /// the factor that mapped *that* width to the screen, which keeps the texture exactly
    /// the size it was before the split — just wider, and in two moving pieces.
    private static let sourceArtWidth: CGFloat = 1179

    /// Where the cloud bank should sit on screen, matching the single-piece overlay this
    /// replaced.
    ///
    /// The layout is anchored on this rather than on the top of the stack, which is what
    /// lets the top band be redrawn at any height without dragging the clouds with it.
    private static let cloudBankY: CGFloat = -355

    /// How far down the bottom band the cloud bank sits — measured from the art, whose
    /// brightness midpoint falls 25.8% of the way down.
    ///
    /// Only needs revisiting if the *bottom* band is redrawn with the clouds at a different
    /// height within it.
    private static let cloudBankFraction: CGFloat = 0.258

    /// The flat colour the top band is painted in — measured from the art, which is a
    /// uniform RGB(46, 90, 137) with specks on it and no gradient at all.
    ///
    /// Needed because the art is opaque with no alpha channel, so shifting it down would
    /// leave a hard edge where the overlay stops and the bare gradient resumes. Filling
    /// that strip with the band's own colour is indistinguishable from more band.
    private static let bandFillColor = SKColor(red: 46/255, green: 90/255, blue: 137/255, alpha: 1)

    /// When the drift began, fixed for the lifetime of the process.
    ///
    /// This is what keeps the position continuous across scene changes. Each scene builds
    /// its own nodes, so there is nothing to hand over — but because every band derives its
    /// starting offset from the same clock and moves at the same speed, a freshly built
    /// overlay lands exactly where the previous scene's had got to. Monotonic rather than
    /// wall-clock, so a clock change can't make it jump.
    private static let epoch = CACurrentMediaTime()

    static func make(z: CGFloat = defaultZ) -> SKNode {
        let root = SKNode()
        root.zPosition = z
        root.alpha = opacity

        let scale = GameViewController.WIDTH / sourceArtWidth

        // Read once and shared by both bands, so they're guaranteed to be in phase with
        // each other. Clamped at zero because `epoch` initialises lazily: on the very first
        // call Swift evaluates CACurrentMediaTime() before initialising it, which would
        // otherwise give a small negative elapsed time and invert the starting offset.
        let elapsed = max(0, CGFloat(CACurrentMediaTime() - epoch))

        let topTexture = SKTexture(imageNamed: "bg_overlay_top")
        let bottomTexture = SKTexture(imageNamed: "bg_overlay_bottom")

        let topHeight = topTexture.size().height * scale
        let bottomHeight = bottomTexture.size().height * scale

        // Pin the bottom band so its cloud bank lands on cloudBankY, then hang the top band
        // directly above it. Anchoring this way round — rather than from the top of the
        // stack — is what keeps the clouds still when the top art is redrawn taller or
        // shorter. Its height only changes how far up the specks reach.
        let bottomTop = cloudBankY + cloudBankFraction * bottomHeight

        // Repeat the top band upward until it clears the top of the screen, so the specks
        // reach the edge on every device rather than petering out into flat colour on the
        // taller ones. The art tiles vertically without a seam — its top and bottom rows are
        // identical and it carries no gradient — so stacking copies is invisible.
        //
        // Derived from the scene height, so a shorter screen simply uses fewer copies and
        // both end up covered.
        let neededAbove = GameViewController.HEIGHT/2 - bottomTop
        let topCopies = max(1, Int((neededAbove / topHeight).rounded(.up)))

        let stackTop = bottomTop + topHeight * CGFloat(topCopies)

        // Belt and braces above the stack. With the repeat count above there should be
        // nothing left to cover, but this costs one sprite and means no future change to
        // the art or to a device's aspect ratio can open a visible gap. Drawn behind the
        // bands so the ordering is deterministic — the view has ignoresSiblingOrder set,
        // which leaves equal-z siblings in an undefined order.
        let fill = SKSpriteNode(color: bandFillColor,
                                size: CGSize(width: GameViewController.WIDTH,
                                             height: GameViewController.HEIGHT))
        fill.position.y = stackTop + GameViewController.HEIGHT/2
        fill.zPosition = -1
        root.addChild(fill)

        let top = band(texture: topTexture, scale: scale,
                       speed: topSpeed, movingLeft: true, elapsed: elapsed,
                       verticalCopies: topCopies)
        top.position.y = bottomTop + topHeight/2
        root.addChild(top)

        let bottom = band(texture: bottomTexture, scale: scale,
                          speed: bottomSpeed, movingLeft: false, elapsed: elapsed,
                          verticalCopies: 1)
        bottom.position.y = bottomTop - bottomHeight/2
        root.addChild(bottom)

        return root
    }

    /// One scrolling band: two copies of the strip and an action that loops them.
    private static func band(texture: SKTexture,
                             scale: CGFloat,
                             speed: CGFloat,
                             movingLeft: Bool,
                             elapsed: CGFloat,
                             verticalCopies: Int) -> SKNode {
        let container = SKNode()

        let width = texture.size().width * scale
        let height = texture.size().height * scale

        // Two copies are enough because a strip is wider than the screen — whatever the
        // scroll offset, the pair always spans the visible area. The spare copy goes on the
        // side being scrolled away from, so the gap it fills is the one that opens up.
        let secondCopyX = movingLeft ? width : -width

        // Horizontally two copies for the scroll, and vertically however many were asked
        // for. Copy zero's bottom edge sits at the container's origin, with the rest
        // stacking upward from there.
        for x in [0, secondCopyX] {
            for row in 0..<verticalCopies {
                let sprite = SKSpriteNode(texture: texture)
                sprite.size = CGSize(width: width, height: height)
                sprite.position = CGPoint(x: x, y: CGFloat(row) * height)
                container.addChild(sprite)
            }
        }

        // Pick up where the last scene left off. The texture repeats every `width`, so only
        // the remainder matters.
        let phase = (elapsed * speed).truncatingRemainder(dividingBy: width)
        container.position.x = movingLeft ? -phase : phase

        let distance = movingLeft ? -width : width

        // Finish the cycle already in progress, then loop from the top.
        //
        // This first leg matters. The repeating cycle below is a *relative* move, so running
        // it straight from a phase-shifted start would carry the container a full width
        // beyond that offset — up to two widths from the origin, which is outside the range
        // two copies can span. The band then scrolls clear of the screen and nothing is drawn
        // until the trailing copy arrives. A large phase broke it and a small one didn't,
        // which is why it looked intermittent and differed from scene to scene.
        //
        // Covering the remainder first lands the container exactly on the origin, so the
        // loop runs canonically from there and never leaves bounds.
        let remaining = width - phase
        let catchUp = SKAction.sequence([
            .moveBy(x: movingLeft ? -remaining : remaining, y: 0,
                    duration: TimeInterval(remaining / speed)),
            .moveBy(x: -distance, y: 0, duration: 0)
        ])

        // Slide exactly one strip width, then snap back instantly. Because the second copy
        // sits exactly one width along, the snap lands it precisely where the first was,
        // making the restart invisible.
        //
        // Actions rather than per-frame work, so this needs no update() wiring and runs
        // identically in all four scenes — including AttributionsScene, which has none.
        let cycle = SKAction.sequence([
            .moveBy(x: distance, y: 0, duration: TimeInterval(width / speed)),
            .moveBy(x: -distance, y: 0, duration: 0)
        ])

        container.run(.sequence([catchUp, .repeatForever(cycle)]))

        return container
    }
}
