//
//  Settings.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2025-11-07.
//

import Foundation

/// How the game is framed on a screen squatter than the 16:9 it was designed for, such as
/// the folded iPhone Duo.
///
/// By default the game zooms in to fill the screen, cropping a little of the top and bottom.
/// Turning zoom off shows the whole 16:9 game instead, fitted to the screen's height, with
/// bars down the sides — so the game itself looks exactly as it does on any phone.
///
/// Phones are 16:9 or taller, so they show the game edge to edge either way, and the option
/// is only offered where it makes a difference.
enum ScreenFit {

    /// An *off* flag, like every option in the settings menu, so a missing value means zoom
    /// is on.
    static let zoomOffKey = "ZoomToFillOff"

    /// Call once at launch, before anything reads the setting. Zoom is on by default, which
    /// an unset off flag already gives; registered explicitly so the default is stated here.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [zoomOffKey: false])
    }

    /// Whether to fill the screen and crop, rather than fit it and show bars.
    static var zoomsToFill: Bool {
        !UserDefaults.standard.bool(forKey: zoomOffKey)
    }

    /// Whether this screen is squatter than 16:9, and so has bars to zoom away. Set by
    /// GameViewController when it sizes the scene to the screen.
    static var screenIsSquatterThanGame = false

    /// Whether to offer Zoom to Fill. The setting only ever takes effect in a portrait
    /// window — in a landscape one, such as the unfolded iPhone Duo turned sideways, the bars
    /// stay regardless (see SceneRenderer.displayScale) — but the option itself stays on offer,
    /// since the settings panel is built once and the window can rotate after that.
    static var isZoomAvailable: Bool {
        screenIsSquatterThanGame
    }
}
