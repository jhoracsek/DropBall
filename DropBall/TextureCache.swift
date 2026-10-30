//
//  TextureCache.swift
//  DropBall
//

import Foundation
import SpriteKit

/// Hands out one shared SKTexture per image name, so sprites created mid-game
/// (new platforms, clouds, score digits) reuse an already-loaded texture instead
/// of loading the image from the asset catalog on the main thread during `update()`.
enum TextureCache {
    private static var textures: [String: SKTexture] = [:]

    /// Every image the game scene can create while it's running.
    static let gameTextureNames: [String] =
        ["ball", "platform", "end", "line",
         "background", "mountains", "pausetext", "loseoverlay",
         "pause", "resume", "play", "playclick", "homebutton"]
        + (1...14).map { "cloud\($0)" }
        + (0...9).map { String($0) }

    static func texture(named name: String) -> SKTexture {
        if let texture = textures[name] {
            return texture
        }
        let texture = SKTexture(imageNamed: name)
        textures[name] = texture
        return texture
    }

    /// Loads all game textures into memory ahead of time. Call once at launch.
    static func preloadGameTextures() {
        let all = gameTextureNames.map { texture(named: $0) }
        SKTexture.preload(all) {}
    }
}
