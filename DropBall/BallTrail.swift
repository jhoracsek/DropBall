//
//  BallTrail.swift
//  DropBall
//

import Foundation
import SpriteKit

/// The speed-boost trail, as a hand-rolled sprite pool.
///
/// This replaces an SKEmitterNode. That emitter crashed twice inside
/// `SKCEmitterNode::runBirthSimulation` with a null dereference on the main thread, at an
/// identical address and register state both times. Three separate mitigations — holding a
/// strong reference to the target node, clamping the values fed in, and tearing the emitter
/// down before its target — made no difference, and the mechanism inside SpriteKit was
/// never pinned down.
///
/// Rather than keep guessing at someone else's internals, this does the same job with
/// explicit arithmetic: a fixed pool of sprites whose positions are advanced by hand. It
/// cannot fault in the same way because nothing about the emitter is involved, and it uses
/// the same approach as WindStreaks, which has been stable.
final class BallTrail {

    /// Pool size. At the full birth rate with the lifetime below, around 117 are alive at
    /// once, so this leaves headroom without over-allocating.
    private static let capacity = 160

    /// Particles per second at full speed.
    private static let birthRate: CGFloat = 260

    private static let lifetime: CGFloat = 0.45
    private static let lifetimeRange: CGFloat = 0.20

    private static let startScale: CGFloat = 0.28
    private static let scaleRange: CGFloat = 0.14
    private static let scaleDecayPerSecond: CGFloat = 0.55

    private static let startAlpha: CGFloat = 0.60
    private static let alphaDecayPerSecond: CGFloat = 1.40

    /// Straight up, with a little spread.
    private static let emissionAngle: CGFloat = .pi / 2
    private static let emissionSpread: CGFloat = 0.22

    /// Warm orange, taken from the original Particle.sks so the look is unchanged.
    private static let tint = SKColor(red: 0.305, green: 0.130, blue: 0.023, alpha: 1.0)

    /// The whole simulation is frame-based elsewhere in this game, so a fixed step keeps it
    /// consistent with everything else rather than introducing delta timing in one place.
    private static let step: CGFloat = 1.0 / 60.0

    private struct Particle {
        let sprite: SKSpriteNode
        var velocity: CGVector = .zero
        var age: CGFloat = 0
        var lifetime: CGFloat = 0
        var baseScale: CGFloat = 0
        var alive = false
    }

    private let container = SKNode()
    private var particles: [Particle] = []
    private var cursor = 0
    private var spawnAccumulator: CGFloat = 0

    /// Horizontal spread of the spawn point, set from the ball's width.
    private var spawnSpread: CGFloat = 0

    init(in target: SKNode, spawnSpread: CGFloat) {
        self.spawnSpread = spawnSpread

        // Above the platforms, below the ball — matching where the emitter sat.
        container.zPosition = 1.5
        target.addChild(container)

        let texture = SKTexture(imageNamed: "spark")
        particles.reserveCapacity(Self.capacity)

        for _ in 0..<Self.capacity {
            let sprite = SKSpriteNode(texture: texture)
            sprite.color = Self.tint
            sprite.colorBlendFactor = 1.0
            sprite.blendMode = .add
            sprite.alpha = 0
            sprite.isHidden = true
            container.addChild(sprite)

            particles.append(Particle(sprite: sprite))
        }
    }

    /// Call once per frame.
    ///
    /// - Parameters:
    ///   - center: where to emit from, in the coordinate space this was created in.
    ///   - emitting: whether new particles should be born this frame.
    ///   - speed: upward speed in points per second, matched to the world's scroll rate so
    ///     the trail appears to hang still while the ball falls past it.
    ///   - intensity: 0 to 1, scaling how many particles are born.
    func update(center: CGPoint, emitting: Bool, speed: CGFloat, intensity: CGFloat) {
        advance()

        guard emitting, speed.isFinite, intensity > 0 else { return }

        spawnAccumulator += Self.birthRate * min(max(intensity, 0), 1) * Self.step
        while spawnAccumulator >= 1 {
            spawnAccumulator -= 1
            spawn(at: center, speed: speed)
        }
    }

    /// Advances every live particle and retires the ones that have expired.
    private func advance() {
        for i in particles.indices where particles[i].alive {
            particles[i].age += Self.step

            let age = particles[i].age
            guard age < particles[i].lifetime else {
                particles[i].alive = false
                particles[i].sprite.isHidden = true
                particles[i].sprite.alpha = 0
                continue
            }

            let sprite = particles[i].sprite
            let velocity = particles[i].velocity

            sprite.position.x += velocity.dx * Self.step
            sprite.position.y += velocity.dy * Self.step

            // Linear decay, matching how the emitter's scaleSpeed and alphaSpeed behaved.
            let scale = particles[i].baseScale - Self.scaleDecayPerSecond * age
            sprite.setScale(max(scale, 0.01))
            sprite.alpha = max(Self.startAlpha - Self.alphaDecayPerSecond * age, 0)
        }
    }

    private func spawn(at center: CGPoint, speed: CGFloat) {
        // Round-robin rather than searching for a free slot: at this pool size the oldest
        // particle is always the best one to reuse, and it keeps the cost constant.
        let index = cursor
        cursor = (cursor + 1) % particles.count

        let angle = Self.emissionAngle + CGFloat.random(in: -Self.emissionSpread...Self.emissionSpread)
        let jitter = CGFloat.random(in: -spawnSpread/2...spawnSpread/2)

        let sprite = particles[index].sprite
        sprite.position = CGPoint(x: center.x + jitter, y: center.y)
        sprite.isHidden = false
        sprite.alpha = Self.startAlpha

        let baseScale = Self.startScale + CGFloat.random(in: -Self.scaleRange/2...Self.scaleRange/2)
        sprite.setScale(baseScale)

        particles[index].velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        particles[index].age = 0
        particles[index].lifetime = Self.lifetime + CGFloat.random(in: -Self.lifetimeRange/2...Self.lifetimeRange/2)
        particles[index].baseScale = baseScale
        particles[index].alive = true
    }

    /// Hides everything immediately, for pausing and for the end of a run.
    func clear() {
        for i in particles.indices {
            particles[i].alive = false
            particles[i].sprite.isHidden = true
            particles[i].sprite.alpha = 0
        }
        spawnAccumulator = 0
    }

    var isPaused: Bool {
        get { container.isPaused }
        set { container.isPaused = newValue }
    }

    func removeFromScene() {
        container.removeFromParent()
    }
}
