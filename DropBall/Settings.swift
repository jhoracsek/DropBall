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
/// By default the whole 16:9 game is shown, fitted to the screen's height, with bars down
/// the sides — so the game itself looks and plays exactly as it does on any phone. Zooming
/// in fills the screen instead, at the cost of cropping some of the top and bottom, which is
/// where the descending line and the next platforms come into view.
///
/// Phones are 16:9 or taller, so they show the game edge to edge either way, and the option
/// is only offered where it makes a difference.
enum ScreenFit {

    /// An *off* flag, like every option in the settings menu. Registered as true at launch,
    /// so zooming starts off and the bars are the default.
    static let zoomOffKey = "ZoomToFillOff"

    /// Call once at launch, before anything reads the setting.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [zoomOffKey: true])
    }

    /// Whether to fill the screen and crop, rather than fit it and show bars.
    static var zoomsToFill: Bool {
        !UserDefaults.standard.bool(forKey: zoomOffKey)
    }

    /// Whether this screen is squatter than 16:9, and so has bars to zoom away. Set by
    /// GameViewController when it sizes the scene to the screen.
    static var screenIsSquatterThanGame = false

    /// Whether the window is currently wider than it is tall — possible on the unfolded
    /// iPhone Duo even though the game is portrait-only. Kept up to date by
    /// GameViewController.
    static var windowIsLandscape = false

    /// Whether to offer Zoom to Fill right now. Never in a landscape window: filling its
    /// width with the portrait game would crop away more than half of it.
    static var isZoomAvailable: Bool {
        screenIsSquatterThanGame && !windowIsLandscape
    }
}
