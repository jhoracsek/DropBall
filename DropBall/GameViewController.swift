//
//  GameViewController.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {
    
    static var HEIGHT : CGFloat = 1624.0
    static var WIDTH : CGFloat = 750.0

    /// The scene height every vertical gameplay constant in the project was authored against.
    static let REFERENCE_HEIGHT : CGFloat = 1334.0

    /// Scene width is fixed at 750 on every device, but the scene height follows the screen's
    /// shape so nothing gets cropped. That means a vertical distance of 1 scene unit covers
    /// a different fraction of the screen on a tall phone than on a short one, so unscaled
    /// per-frame speeds and world spacing would make the game look slower and more tightly
    /// packed on tall screens and the reverse on short ones. Multiplying every vertical world
    /// distance and speed by this factor keeps motion and layout at a constant fraction of
    /// the screen on all aspect ratios. It is exactly 1.0 on a 16:9 screen and on anything
    /// squatter (see sizeScene), and above 1 on taller phones.
    static var vScale : CGFloat { HEIGHT / REFERENCE_HEIGHT }

    /// The menu's ground line — the platform the menu ball bounces on — before vScale.
    static let menuGroundY: CGFloat = -380

    /// Where the mountains' bottom edge sits, in every scene.
    ///
    /// The mountains are fixed-size art, but the ground line above them moves with vScale,
    /// so on a 16:9 screen their peaks rose slightly into it. They're lowered just enough to
    /// keep the peaks a little under the ground line, letting their base run off the bottom
    /// of the screen. On taller phones, where they already clear it, they stay on the bottom
    /// edge.
    ///
    /// Shared by every scene so the mountains don't jump between them.
    static var mountainsBaseY: CGFloat {
        // Height of the mountains' visible outline within the 750-wide scene. The art is
        // 344 tall, but its top 48 rows are transparent over the part that's on screen.
        let peakHeight: CGFloat = 296
        // Half the ground line's 64-point thickness, and the gap kept below it — the gap
        // the peaks already had on taller phones, where they looked right.
        let groundHalfThickness: CGFloat = 32
        let clearance: CGFloat = 20

        let groundUnderside = menuGroundY * vScale - groundHalfThickness
        return min(-HEIGHT/2, groundUnderside - clearance - peakHeight)
    }

    /// Sets the scene height so the 750-wide scene has the shape of `size` — but never
    /// squatter than 16:9, the shape the whole game was designed at.
    ///
    /// On every phone that's exactly the screen's shape, so the scene fills it. On a squatter
    /// screen like the folded iPhone Duo, shrinking the scene's height to match made the
    /// whole game feel cramped, so it keeps the 16:9 layout instead — the same 750 × 1334 a
    /// 16:9 phone gets — and SceneRenderer fits it to the screen's height, with bars down the
    /// sides.
    private static func sizeScene(toFit size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let shapedHeight = WIDTH * size.height / size.width
        HEIGHT = max(REFERENCE_HEIGHT, shapedHeight)

        // A hair of tolerance, so a 16:9 phone — exactly 1334 after rounding — never counts.
        ScreenFit.screenIsSquatterThanGame = shapedHeight < REFERENCE_HEIGHT - 1
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AppDelegate.sharedAppDelegate.coreDataStack.saveContext()

        // Started here rather than in the app delegate because signing in may need to put a
        // view controller on screen, and this is the first point at which there's a root
        // view controller for it to be presented from.
        GameCenter.authenticate()

        // Scenes are drawn by SceneRenderer into a plain Metal view rather than by an
        // SKView; see SceneRenderer for why. It also shows the debug FPS readout.
        if let view = self.view as? SceneView {
            sceneRenderer = SceneRenderer(view: view)
        }
    }

    /// The first scene waits until here because the scene's shape is taken from the view's
    /// size, and that isn't final in viewDidLoad — there the view still has the storyboard's
    /// placeholder size. By viewIsAppearing it has the window's real size and safe area.
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        guard !hasPresentedFirstScene else { return }
        hasPresentedFirstScene = true

        GameViewController.sizeScene(toFit: view.bounds.size)

        if let scene = SKScene(fileNamed: "StartScene") {
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            sceneRenderer?.present(scene)
        }
    }

    private var sceneRenderer: SceneRenderer?
    private var hasPresentedFirstScene = false

    override var shouldAutorotate: Bool {
        return false
    }

    // The scene is a fixed-width portrait layout, so every orientation other than portrait
    // crops the playfield. Keep this in sync with UISupportedInterfaceOrientations in Info.plist.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
