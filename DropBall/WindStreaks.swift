//
//  WindStreaks.swift
//  DropBall
//

import Foundation
import SpriteKit

/// Pale arcs that sweep around the ball while it is falling fast, to suggest air rushing
/// past it.
///
/// Deliberately separate from the particle trail. The trail is material shed from the ball
/// and left behind in the world; wind is the medium flowing *around* it, so it stays locked
/// to the ball and has to curve. An SKEmitterNode can only send particles in straight
/// lines, which is why this is hand-animated with shape nodes instead.
///
/// Each arc is a fixed, pre-built stroke sitting at some radius from the origin. Sweeping it
/// around the ball is then just a change of `zRotation`, so nothing is re-tessellated while
/// the game is running.
final class WindStreaks {

    /// Size of the reuse pool. Arcs are recycled rather than allocated mid-fall. Concurrency
    /// actually peaks at *low* speed, where arcs are spawned slower but live longer, so this
    /// is sized against that case rather than the full-speed one.
    private static let streakCount = 14

    /// Angular length of each arc, in radians. Short on purpose: a long arc hugging the
    /// circumference reads as a ring drawn around the ball rather than as air going past it.
    private static let arcSpan: CGFloat = 0.45

    /// How far around the ball an arc travels, in radians, before fading out. Deliberately
    /// well under pi — a half-circle sweep runs from directly below the ball to directly
    /// above it, which closes the loop visually and again reads as a circle. Keeping it to
    /// roughly two thirds of that confines each arc to one flank, where the flow is fastest.
    private static let sweepArc: CGFloat = 0.62 * .pi

    /// Seconds for an arc to complete its sweep, at full speed.
    private static let sweepDuration: CGFloat = 0.5

    /// Arcs started per frame at full speed.
    private static let spawnRate: CGFloat = 0.3

    /// Opacity an arc reaches at its brightest, before being scaled by the ball's speed.
    private static let peakAlpha: CGFloat = 0.45

    /// Floors for the two speed-driven values, as fractions of their full-speed amount.
    ///
    /// Scaling density and brightness straight from zero meant that at the moment a boost
    /// begins — when the ball may still be slow — the wind was both sparse and nearly
    /// transparent, so it appeared to lag behind the particle trail. Starting from a floor
    /// instead means it's present immediately and then intensifies.
    private static let minSpawnFraction: CGFloat = 0.45
    private static let minAlphaFraction: CGFloat = 0.5

    /// Clamps how much an arc is slowed at low speed, so the wind never looks sluggish.
    private static let minSpeedForDuration: CGFloat = 0.5

    private let container = SKNode()
    private var streaks: [SKShapeNode] = []
    private var spawnAccumulator: CGFloat = 0
    private var wasActive = false

    init(ballRadius: CGFloat, in target: SKNode) {
        // Above the platforms (1) and behind the ball (2), tucked just under the particle
        // trail (1.5) so the trail still reads as the foreground effect.
        container.zPosition = 1.3
        target.addChild(container)

        for i in 0..<Self.streakCount {
            // Spread the pool over a band of radii and line widths so that recycled arcs
            // don't visibly retrace the same stroke. The innermost just clears the ball.
            let t = CGFloat(i) / CGFloat(Self.streakCount - 1)
            let radius = ballRadius * (1.02 + 0.43 * t)

            let path = CGMutablePath()
            path.addArc(center: .zero,
                        radius: radius,
                        startAngle: -Self.arcSpan / 2,
                        endAngle: Self.arcSpan / 2,
                        clockwise: false)

            let streak = SKShapeNode(path: path)
            streak.strokeColor = .white
            streak.lineWidth = 2.5 - 1.0 * t
            streak.lineCap = .round
            streak.fillColor = .clear
            streak.alpha = 0

            container.addChild(streak)
            streaks.append(streak)
        }
    }

    /// Freezes the arcs mid-sweep. Their motion is driven by SKActions, which keep running
    /// unless the node they belong to is paused.
    var isPaused: Bool {
        get { container.isPaused }
        set { container.isPaused = newValue }
    }

    /// Call once per frame.
    ///
    /// - Parameters:
    ///   - center: the ball's drawn position, in the coordinate space of the node this was
    ///     created in.
    ///   - speedRatio: 0 when the ball is barely moving, 1 at full fall speed. Drives how
    ///     many arcs appear, how fast they travel and how bright they get.
    ///   - active: whether the player is currently boosting. Arcs already in flight always
    ///     finish their sweep, so releasing the screen tails off rather than cutting out.
    func update(center: CGPoint, speedRatio: CGFloat, active: Bool) {
        container.position = center

        guard active else {
            wasActive = false
            return
        }

        // Fire one arc on the very first active frame instead of waiting for the accumulator
        // to fill, which is what made the wind arrive noticeably after the particles.
        if !wasActive {
            wasActive = true
            spawnAccumulator = 1
        }

        let density = Self.minSpawnFraction + (1 - Self.minSpawnFraction) * speedRatio
        spawnAccumulator += density * Self.spawnRate

        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            spawn(speedRatio: speedRatio)
        }
    }

    private func spawn(speedRatio: CGFloat) {
        // Any arc that isn't mid-sweep is free to reuse.
        guard let streak = streaks.first(where: { !$0.hasActions() }) else { return }

        // Vary the sweep per arc so they don't all trace an identical path.
        let sweepMagnitude = Self.sweepArc * CGFloat.random(in: 0.82...1.18)
        let jitter = CGFloat.random(in: -0.18...0.18)

        // The ball is falling, so relative to it the air arrives low and leaves high. Each
        // arc is centred on one flank: starting half a sweep below that flank and ending
        // half a sweep above it, so it never crosses the ball's top or bottom.
        //
        //   right flank — travel anticlockwise through angle 0
        //   left flank  — travel clockwise through angle pi
        let goesRight = Bool.random()
        let sweep = goesRight ? sweepMagnitude : -sweepMagnitude
        let start = goesRight ? -sweepMagnitude / 2 : .pi + sweepMagnitude / 2

        streak.zRotation = start + jitter
        streak.alpha = 0

        let speedForDuration = max(speedRatio, Self.minSpeedForDuration)
        let duration = Double(Self.sweepDuration / speedForDuration)

        // Ease in and out so each arc is slowest at the ends of its sweep and quickest as it
        // passes the side — which is how air actually moves around a body.
        let travel = SKAction.rotate(byAngle: sweep, duration: duration)
        travel.timingMode = .easeInEaseOut

        let brightness = Self.minAlphaFraction + (1 - Self.minAlphaFraction) * speedRatio
        let fade = SKAction.sequence([
            SKAction.fadeAlpha(to: Self.peakAlpha * brightness, duration: duration * 0.3),
            SKAction.fadeAlpha(to: 0, duration: duration * 0.7)
        ])

        streak.run(SKAction.group([travel, fade]))
    }
}
