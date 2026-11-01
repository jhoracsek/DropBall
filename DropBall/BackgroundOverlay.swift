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

    /// Where each band begins, as a fraction of its width, drawn once per launch so the
    /// background doesn't open on the same stretch of texture every time.
    ///
    /// Deliberately `static let` and therefore resolved once per process, not per scene —
    /// drawing a fresh number for each scene would undo the continuity above and make the
    /// background jump on every transition. The two bands get independent values so they
    /// don't start aligned with each other.
    private static let topStartFraction = CGFloat.random(in: 0..<1)
    private static let bottomStartFraction = CGFloat.random(in: 0..<1)

    /// Why the drift is currently stopped. More than one thing can stop it at once — the
    /// game being paused and the app being sent to the background, in particular — and the
    /// clock should only resume once *every* reason has gone away.
    ///
    /// Tracking reasons by name rather than counting makes each caller idempotent: repeating
    /// `setPaused(true, reason: .game)` is harmless, and clearing a reason that was never
    /// set can't unbalance anything.
    enum PauseReason {
        case game
        case appInactive
    }

    private static var pauseReasons: Set<PauseReason> = []

    /// When the current pause began, and how long has been spent paused in total.
    ///
    /// Both are needed because the drift is derived from the clock. Freezing the nodes stops
    /// them moving, but the clock keeps running — so without discounting that time, a scene
    /// built after the pause would compute a position as though the background had carried
    /// on, and jump forward on the transition.
    private static var pauseBegan: CFTimeInterval?
    private static var pausedTotal: CFTimeInterval = 0

    /// Seconds of drift so far, excluding any time spent paused.
    private static var driftTime: CGFloat {
        // Clamped at zero because `epoch` initialises lazily: on the very first call Swift
        // evaluates CACurrentMediaTime() before initialising it, which would otherwise give
        // a small negative elapsed time and invert the starting offset.
        let now = CACurrentMediaTime()
        let paused = pausedTotal + (pauseBegan.map { now - $0 } ?? 0)
        return max(0, CGFloat(now - epoch - paused))
    }

    /// Stops or resumes the drift for one reason, and keeps the clock honest while stopped.
    ///
    /// The bands read their position straight from this clock, so stopping it is enough to
    /// stop them — and resuming carries on from exactly where they were.
    static func setPaused(_ paused: Bool, reason: PauseReason) {
        let wasStopped = !pauseReasons.isEmpty

        if paused {
            pauseReasons.insert(reason)
        } else {
            pauseReasons.remove(reason)
        }

        let isStopped = !pauseReasons.isEmpty
        guard wasStopped != isStopped else { return }

        if isStopped {
            pauseBegan = CACurrentMediaTime()
        } else if let began = pauseBegan {
            pausedTotal += CACurrentMediaTime() - began
            pauseBegan = nil
        }
    }

    static func make(z: CGFloat = defaultZ) -> SKNode {
        let root = SKNode()
        root.zPosition = z
        root.alpha = opacity

        let scale = GameViewController.WIDTH / sourceArtWidth

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
                       speed: topSpeed, movingLeft: true,
                       startFraction: topStartFraction,
                       verticalCopies: topCopies)
        top.position.y = bottomTop + topHeight/2
        root.addChild(top)

        let bottom = band(texture: bottomTexture, scale: scale,
                          speed: bottomSpeed, movingLeft: false,
                          startFraction: bottomStartFraction,
                          verticalCopies: 1)
        bottom.position.y = bottomTop - bottomHeight/2
        root.addChild(bottom)

        return root
    }

    /// One scrolling band: two copies of the strip, positioned from the drift clock.
    private static func band(texture: SKTexture,
                             scale: CGFloat,
                             speed: CGFloat,
                             movingLeft: Bool,
                             startFraction: CGFloat,
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

        // Offset by this launch's random start. The texture repeats every `width`, so only
        // the remainder matters, which also keeps the result inside [0, width).
        func position() -> CGFloat {
            let travelled = driftTime * speed + startFraction * width
            let phase = travelled.truncatingRemainder(dividingBy: width)
            return movingLeft ? -phase : phase
        }

        container.position.x = position()

        // Set from the clock every frame, rather than moved by actions. Under SKRenderer a
        // paused move action leaps ahead on resume to make up the time, and the band then
        // disagrees with the clock the next scene starts from. Read from the clock, the
        // band stops and resumes exactly with it, and every scene that builds one agrees
        // on where it is — so there's nothing to hand over between scenes either.
        //
        // An action rather than per-frame code in each scene, so this needs no update()
        // wiring and runs in all four scenes, including AttributionsScene, which has none.
        let follow = SKAction.customAction(withDuration: 1) { node, _ in
            node.position.x = position()
        }
        container.run(.repeatForever(follow))

        return container
    }
}
