//
//  BackgroundOverlay.swift
//  DropBall
//

import Foundation
import SpriteKit

/// The texture layer that sits over the sky gradient and behind the mountains.
///
/// Shared because four scenes draw the same background stack, and the sizing is worth
/// getting right in one place rather than copying it around.
enum BackgroundOverlay {

    /// Z positions for the three background layers, for the scenes that use the default
    /// arrangement. StartScene orders its layers differently and passes its own.
    static let defaultZ: CGFloat = -0.95

    /// Builds the overlay, scaled to the scene's width with its aspect ratio preserved.
    ///
    /// The art is 1179x2556 — an iPhone 15 screen — which at 750 wide comes out 1626 tall
    /// against a 1624-tall scene, so it's a near-exact fit on the taller layout. On the
    /// shorter 1334 layout it simply overhangs top and bottom, which is harmless for a
    /// texture and better than squashing it to fit.
    static func make(z: CGFloat = defaultZ) -> SKSpriteNode {
        let node = SKSpriteNode(imageNamed: "bg_overlay")

        let targetWidth = GameViewController.WIDTH
        let scale = targetWidth / node.size.width
        node.size = CGSize(width: targetWidth, height: node.size.height * scale)

        // Centred and screen-fixed, so it reads as a texture over the whole view rather
        // than something in the world. Give it the gradient's parallax instead if it should
        // feel attached to the sky.
        node.position = .zero
        node.zPosition = z

        return node
    }
}
