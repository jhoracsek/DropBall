//
//  SceneRenderer.swift
//  DropBall
//

import UIKit
import SpriteKit
import Metal
import QuartzCore

/// Lifecycle hooks for scenes shown by SceneRenderer, in place of SKScene's didMove(to:) and
/// willMove(from:) — those are only ever called by an SKView, and there isn't one.
protocol PresentedScene: SKScene {
    /// Called once the scene has been sized and is about to be shown. Build content here.
    func didPresent()

    /// Called just before the scene is replaced by another.
    func willDismiss()
}

extension PresentedScene {
    func willDismiss() {}
}

extension SKScene {
    /// Moves to another scene with the game's half-second cross-fade. Replaces
    /// SKView.presentScene(_:transition:).
    func transition(to scene: SKScene) {
        SceneRenderer.shared?.present(scene)
    }

    /// Where a touch landed, in this scene's coordinates. Replaces UITouch.location(in:),
    /// which converts through the scene's SKView and so has nothing to work with here.
    func location(of touch: UITouch) -> CGPoint {
        SceneRenderer.shared?.location(of: touch, in: self) ?? .zero
    }

    /// The part of the scene that's on screen and clear of the camera, the rounded corners
    /// and the home indicator, in scene coordinates. Anything that has to be seen or tapped
    /// belongs inside it. Falls back to the whole scene if nothing is drawing it yet.
    var safeFrame: CGRect {
        SceneRenderer.shared?.safeFrame(in: self)
            ?? CGRect(x: -size.width * anchorPoint.x, y: -size.height * anchorPoint.y,
                      width: size.width, height: size.height)
    }
}

extension UIView {
    /// The safe-area insets the game lays out against: the full width of the screen, with
    /// any side cutout treated as an obstruction along the top instead.
    ///
    /// The folded iPhone Duo's camera is a small circle in the top-right corner, but iOS
    /// reports it as an 84-point strip down the whole right-hand side, which would narrow
    /// every screen just to clear the top of it. In a portrait window a side inset on an
    /// iPhone can only be a cutout like that one, so it's moved to the top: the safe area
    /// keeps the full width and starts the same distance down instead, which clears the
    /// camera. On phones without a side inset nothing changes.
    ///
    /// Only in portrait. The game is portrait-only, but the unfolded Duo can still give it a
    /// landscape window, and there a side inset really is down the side — and falls in the
    /// bars beside the game anyway.
    ///
    /// Rounded screen corners are adapted the same way where the system supports it,
    /// shortening the top or bottom rather than the sides.
    var gameSafeAreaInsets: UIEdgeInsets {
        var insets = safeAreaInsets
        if #available(iOS 26.0, *) {
            insets = edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
        }

        let sideInset = max(insets.left, insets.right)
        let isPortrait = bounds.height >= bounds.width
        if isPortrait && sideInset > 0 {
            insets.top = max(insets.top, sideInset)
            insets.left = 0
            insets.right = 0
        }
        return insets
    }
}

/// The app's root view: a Metal layer the scenes are drawn into, which passes touches on to
/// whichever scene is showing.
final class SceneView: UIView {

    override class var layerClass: AnyClass { CAMetalLayer.self }

    var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

    weak var renderer: SceneRenderer?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // A custom layer-backed view defaults to a scale of 1, which would draw at a third
        // of the iPhone's resolution and upscale it.
        contentScaleFactor = traitCollection.displayScale
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        metalLayer.drawableSize = CGSize(width: bounds.width * contentScaleFactor,
                                         height: bounds.height * contentScaleFactor)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.forward(.began, touches, event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.forward(.moved, touches, event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.forward(.ended, touches, event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        renderer?.forward(.cancelled, touches, event)
    }
}

/// Owns the current scene: updates it, draws it with SKRenderer, delivers its touches and
/// cross-fades between scenes.
///
/// Why there's no SKView: on iOS 17 and later SKView draws inside UIKit's per-frame update,
/// after touch handling, and must hand each frame over within a few milliseconds of the
/// refresh. A finger landing costs UIKit around 3ms in that same window, which Instruments
/// showed was enough to miss it — the hitches seen on an iPhone 15 but never on iOS 16.
/// CAMetalDisplayLink lets the app ask for an extra frame of latency so that can't happen.
///
/// An SKView can't simply be kept around to host the scene while this draws it, either: a
/// scene's actions only run while its view is unpaused, and an unpaused view also runs its
/// own updates on its own clock. The two fought over the background drift, which is what
/// made it snap back and stall.
final class SceneRenderer: NSObject {

    /// The one renderer, for scenes to reach through transition(to:) and location(of:).
    private(set) static weak var shared: SceneRenderer?

    /// Matches the SKTransition.crossFade(withDuration: 0.5) the scenes used to request.
    private static let crossFadeDuration: CFTimeInterval = 0.5

    /// Frames of latency to allow on iOS 17+. One is what SKView did; two gives a full extra
    /// frame to finish in, at the cost of 1/60s more delay between input and the screen.
    private static let frameLatency: Float = 2

    private let view: SceneView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let renderer: SKRenderer

    /// CAMetalDisplayLink on iOS 17+, CADisplayLink before that.
    private var displayLink: AnyObject?

    /// The scene being shown, and the one waiting to replace it at the start of the next
    /// frame. Deferred so a scene that asks to leave from inside its own update() isn't
    /// swapped out from under itself mid-frame.
    private(set) var scene: SKScene?
    private var pendingScene: SKScene?

    /// The outgoing scene's last frame, fading out over the incoming scene.
    private var fadeOverlay: SKSpriteNode?
    private var fadeStart: CFTimeInterval?

    /// The scene that received the current touch's touchesBegan, so a touch that started
    /// before a scene change isn't finished on a scene that never saw it start.
    private weak var touchScene: SKScene?

    /// True while the app is inactive — Control Center, the notification shade, a system
    /// sheet. The scene is paused meanwhile, as SKView did, so a run can't carry on alone.
    private var isInactive = false

    #if DEBUG
    /// Turns the scene-fit guides on or off. See LayoutGuideOverlay.
    private static let showsLayoutGuides = true
    private var layoutGuides: LayoutGuideOverlay?

    private let fpsLabel = UILabel()
    private var lastPresentedTime: CFTimeInterval = 0
    private var presentedThisSecond = 0
    private var secondStart: CFTimeInterval = 0
    #endif

    /// Returns nil only if the device has no Metal support.
    init?(view: SceneView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else { return nil }

        self.view = view
        self.device = device
        self.commandQueue = commandQueue
        self.renderer = SKRenderer(device: device)
        super.init()

        SceneRenderer.shared = self
        view.renderer = self

        renderer.ignoresSiblingOrder = true
        renderer.shouldCullNonVisibleNodes = true

        view.metalLayer.device = device
        view.metalLayer.pixelFormat = .bgra8Unorm
        // False so a scene narrower than the screen can be copied into the middle of it.
        view.metalLayer.framebufferOnly = false

        #if DEBUG
        // Added before the FPS label so the label stays on top of the guides.
        if Self.showsLayoutGuides {
            let guides = LayoutGuideOverlay(frame: view.bounds)
            guides.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(guides)
            layoutGuides = guides
        }
        setUpFPSLabel()
        applyDebugVisibility()

        // The switch is flipped from the settings menu while these are on screen, so they
        // follow it live. Any UserDefaults change lands here; re-reading one flag is cheap.
        NotificationCenter.default.addObserver(self, selector: #selector(debugSettingsMayHaveChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        #endif

        startDisplayLink()

        // Submitting GPU work from the background isn't allowed, so stop with the app.
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground),
                                               name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillDeactivate),
                                               name: UIScene.willDeactivateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidActivate),
                                               name: UIScene.didActivateNotification, object: nil)
    }

    // MARK: - Scenes

    /// Shows a scene from the next frame, cross-fading if another was already showing.
    func present(_ scene: SKScene) {
        pendingScene = scene
    }

    /// True while a scene change is waiting or the cross-fade is still running. The
    /// incoming scene keeps being updated meanwhile, so a scene whose logic shouldn't start
    /// until it's fully visible can hold itself back by checking this.
    var isTransitioning: Bool {
        pendingScene != nil || fadeOverlay != nil
    }

    private func applyPendingScene(at time: CFTimeInterval) {
        guard let next = pendingScene else { return }
        pendingScene = nil

        // Captured before willDismiss(), which may tear down what's on screen.
        let snapshot = scene.flatMap(makeSnapshot(of:))

        (scene as? PresentedScene)?.willDismiss()

        scene = next
        renderer.scene = next
        (next as? PresentedScene)?.didPresent()

        // Scenes loaded from a .sks file arrive paused, and SKView.presentScene was what
        // unpaused them. One arriving while the app is inactive stays paused like the rest.
        next.isPaused = isInactive

        #if DEBUG
        layoutGuides?.sceneSize = next.size
        #endif

        if let snapshot {
            attach(snapshot, to: next, at: time)
        }
    }

    // MARK: - Cross-fade

    /// The outgoing scene's current frame as a texture, for fading out over its successor.
    ///
    /// Rendered offscreen at the scene's own aspect ratio, so it lines up exactly with the
    /// incoming scene's visible area whatever the screen's shape. A one-off GPU readback at
    /// each scene change; it costs a few milliseconds while the screen is changing anyway.
    private func makeSnapshot(of scene: SKScene) -> SKTexture? {
        let width = Int(view.metalLayer.drawableSize.width)
        let height = Int((CGFloat(width) * scene.size.height / scene.size.width).rounded())
        guard width > 0, height > 0 else { return nil }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                  width: width, height: height,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor),
              let commandBuffer = commandQueue.makeCommandBuffer() else { return nil }

        renderer.render(withViewport: CGRect(x: 0, y: 0, width: width, height: height),
                        commandBuffer: commandBuffer,
                        renderPassDescriptor: renderPass(into: texture, clearingTo: scene.backgroundColor))
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)
        pixels.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            texture.getBytes(base, bytesPerRow: bytesPerRow,
                             from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }

        // BGRA in memory, which CoreGraphics calls little-endian ARGB.
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue
                                      | CGBitmapInfo.byteOrder32Little.rawValue)
        guard let provider = CGDataProvider(data: pixels as CFData),
              let image = CGImage(width: width, height: height,
                                  bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmapInfo,
                                  provider: provider, decode: nil, shouldInterpolate: true,
                                  intent: .defaultIntent) else { return nil }

        return SKTexture(cgImage: image)
    }

    /// Lays the outgoing scene's snapshot over the incoming scene and starts the fade.
    ///
    /// Unlike SKTransition, the incoming scene runs underneath rather than waiting. Holding
    /// it still doesn't work under SKRenderer: its actions leap ahead afterwards to make up
    /// the time, whether updates are skipped or the scene is paused.
    private func attach(_ snapshot: SKTexture, to scene: SKScene, at time: CFTimeInterval) {
        let overlay = SKSpriteNode(texture: snapshot, size: scene.size)
        overlay.position = CGPoint(x: scene.size.width * (0.5 - scene.anchorPoint.x),
                                   y: scene.size.height * (0.5 - scene.anchorPoint.y))
        // Above everything any scene draws; the highest in use is around 50.
        overlay.zPosition = 10_000
        scene.addChild(overlay)

        fadeOverlay = overlay
        fadeStart = time
    }

    private func advanceCrossFade(at time: CFTimeInterval) {
        guard let overlay = fadeOverlay, let start = fadeStart else { return }

        let progress = (time - start) / Self.crossFadeDuration
        if progress >= 1 {
            overlay.removeFromParent()
            fadeOverlay = nil
            fadeStart = nil
        } else {
            overlay.alpha = CGFloat(1 - progress)
        }
    }

    // MARK: - Touches

    /// Delivers a touch to the showing scene. New touches are ignored while a scene change
    /// is under way, as they were during an SKTransition, so a tap can't land on a scene
    /// that's still fading in — or on one that's about to be replaced.
    func forward(_ phase: UITouch.Phase, _ touches: Set<UITouch>, _ event: UIEvent?) {
        guard let scene else { return }

        switch phase {
        case .began:
            guard fadeOverlay == nil, pendingScene == nil else { return }
            touchScene = scene
            scene.touchesBegan(touches, with: event)
        case .moved:
            guard touchScene === scene else { return }
            scene.touchesMoved(touches, with: event)
        case .ended:
            guard touchScene === scene else { return }
            scene.touchesEnded(touches, with: event)
        case .cancelled:
            guard touchScene === scene else { return }
            scene.touchesCancelled(touches, with: event)
        default:
            break
        }
    }

    /// Screen points per scene point when a scene of `sceneSize` is drawn into an area of
    /// `areaSize`, keeping its shape.
    ///
    /// GameViewController shapes every scene to the screen, so on a phone it fills exactly
    /// and both choices below come to the same thing. They only differ where the screen is
    /// squatter than 16:9, such as the folded iPhone Duo. There the scene is fitted inside by
    /// default (.aspectFit), leaving bars down the sides; with the Zoom to Fill setting on it
    /// fills the screen instead (.aspectFill), cropping the top and bottom. See ScreenFit.
    ///
    /// Everything that maps between screen and scene — drawing, touches, the safe frame and
    /// the debug guides — goes through this, so they can never disagree.
    static func displayScale(_ sceneSize: CGSize, in areaSize: CGSize) -> CGFloat {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return 0 }
        let widthScale = areaSize.width / sceneSize.width
        let heightScale = areaSize.height / sceneSize.height

        // Zoom only ever applies to a portrait area. Filling a landscape window's width with
        // the portrait game would crop away more than half of it, so there the bars stay
        // whatever the setting says.
        let zooms = ScreenFit.zoomsToFill && areaSize.height >= areaSize.width
        return zooms ? max(widthScale, heightScale) : min(widthScale, heightScale)
    }

    /// Converts a touch into scene coordinates with the same mapping used to draw, so a
    /// point lands on whatever is drawn under it.
    func location(of touch: UITouch, in scene: SKScene) -> CGPoint {
        let point = touch.location(in: view)
        let bounds = view.bounds.size
        let scale = Self.displayScale(scene.size, in: bounds)
        return CGPoint(x: (point.x - bounds.width / 2) / scale + scene.size.width * (0.5 - scene.anchorPoint.x),
                       y: (bounds.height / 2 - point.y) / scale + scene.size.height * (0.5 - scene.anchorPoint.y))
    }

    /// The view's safe area, in scene coordinates, using the same mapping as drawing, and
    /// limited to the scene itself — where the scene doesn't reach the screen's edges, the
    /// bars beside it aren't somewhere content can go. Each side is converted on its own,
    /// since the insets needn't be symmetrical. Uses gameSafeAreaInsets, so the folded Duo's
    /// camera shortens the top rather than the side.
    func safeFrame(in scene: SKScene) -> CGRect {
        let bounds = view.bounds.size
        let insets = view.gameSafeAreaInsets
        let scale = Self.displayScale(scene.size, in: bounds)
        guard scale > 0 else { return .zero }

        let centre = CGPoint(x: scene.size.width * (0.5 - scene.anchorPoint.x),
                             y: scene.size.height * (0.5 - scene.anchorPoint.y))
        let minX = centre.x + (-bounds.width / 2 + insets.left) / scale
        let maxX = centre.x + (bounds.width / 2 - insets.right) / scale
        let minY = centre.y + (-bounds.height / 2 + insets.bottom) / scale
        let maxY = centre.y + (bounds.height / 2 - insets.top) / scale
        let safe = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        let sceneRect = CGRect(x: -scene.size.width * scene.anchorPoint.x,
                               y: -scene.size.height * scene.anchorPoint.y,
                               width: scene.size.width, height: scene.size.height)
        return safe.intersection(sceneRect)
    }

    // MARK: - App state

    @objc private func appDidEnterBackground() {
        setDisplayLinkPaused(true)
    }

    @objc private func appWillEnterForeground() {
        setDisplayLinkPaused(false)
    }

    @objc private func sceneWillDeactivate() {
        isInactive = true
        scene?.isPaused = true
    }

    @objc private func sceneDidActivate() {
        isInactive = false
        scene?.isPaused = false
    }

    // MARK: - Frame loop

    private func startDisplayLink() {
        // The simulator's CAMetalDisplayLink only fires when something else on screen
        // changes — about once a second here — so it uses the ordinary link there.
        #if targetEnvironment(simulator)
        let useMetalLink = false
        #else
        let useMetalLink = true
        #endif

        if #available(iOS 17.0, *), useMetalLink {
            let link = CAMetalDisplayLink(metalLayer: view.metalLayer)
            link.delegate = self
            link.preferredFrameLatency = Self.frameLatency
            // Pinned to 60: GameScene's update runs in 1/60s steps, and without this a
            // ProMotion phone is free to pick a varying rate below that.
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
            // .common rather than .default so frames keep coming while a touch is tracked.
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            // iOS 16 has no CAMetalDisplayLink, but never had the touch-induced hitches
            // either, so the ordinary display link is all it needs. It retains its target,
            // which is fine for an object that lives as long as the app.
            let link = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    private func setDisplayLinkPaused(_ paused: Bool) {
        if #available(iOS 17.0, *), let link = displayLink as? CAMetalDisplayLink {
            link.isPaused = paused
        } else if let link = displayLink as? CADisplayLink {
            link.isPaused = paused
        }
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        guard let drawable = view.metalLayer.nextDrawable() else { return }
        drawFrame(into: drawable, at: link.targetTimestamp)
    }

    /// One frame: swap scenes if one is waiting, advance the fade, update, draw, present.
    ///
    /// `time` is when the frame will reach the screen. It advances by exactly one refresh
    /// per frame, so GameScene's fixed-step update sees perfectly even gaps.
    private func drawFrame(into drawable: CAMetalDrawable, at time: CFTimeInterval) {
        applyPendingScene(at: time)

        guard let scene,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        advanceCrossFade(at: time)
        renderer.update(atTime: time)

        draw(scene, into: drawable.texture, commandBuffer: commandBuffer)

        #if DEBUG
        #if targetEnvironment(simulator)
        // The simulator has no presented handler, so count frames as they're submitted.
        recordPresentation(at: time)
        #else
        drawable.addPresentedHandler { [weak self] presented in
            let presentedTime = presented.presentedTime
            DispatchQueue.main.async {
                self?.recordPresentation(at: presentedTime)
            }
        }
        #endif
        #endif

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    /// Offscreen target for a scene that doesn't fill the screen. Kept between frames and
    /// only remade when the size it needs changes.
    private var sceneTexture: MTLTexture?

    /// Draws the scene fitted and centred in `target`, with the bar colour either side.
    ///
    /// SKRenderer scales the scene to fill whatever it's rendering into and ignores the size
    /// of the viewport it's given, so drawing straight into the screen would spread a narrower
    /// scene across the bars. Where the scene fills the screen — every phone — it's drawn
    /// directly. Otherwise it's drawn into a texture of exactly its own size, the screen is
    /// cleared to the bar colour, and the texture is copied into the middle.
    private func draw(_ scene: SKScene, into target: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let area = viewport(for: scene, drawableSize: CGSize(width: target.width, height: target.height))
        let x = max(0, Int(area.minX.rounded()))
        let y = max(0, Int(area.minY.rounded()))
        let width = min(target.width - x, Int(area.width.rounded()))
        let height = min(target.height - y, Int(area.height.rounded()))
        guard width > 0, height > 0 else { return }

        if x == 0, y == 0, width == target.width, height == target.height {
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: width, height: height),
                            commandBuffer: commandBuffer,
                            renderPassDescriptor: renderPass(into: target, clearingTo: scene.backgroundColor))
            return
        }

        guard let offscreen = sceneTexture(width: width, height: height) else { return }

        renderer.render(withViewport: CGRect(x: 0, y: 0, width: width, height: height),
                        commandBuffer: commandBuffer,
                        renderPassDescriptor: renderPass(into: offscreen, clearingTo: scene.backgroundColor))

        // A pass with nothing drawn in it, just to clear the screen to the bar colour.
        commandBuffer.makeRenderCommandEncoder(descriptor: renderPass(into: target, clearingTo: Self.barColor))?
            .endEncoding()

        guard let blit = commandBuffer.makeBlitCommandEncoder() else { return }
        blit.copy(from: offscreen, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: width, height: height, depth: 1),
                  to: target, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: x, y: y, z: 0))
        blit.endEncoding()
    }

    private func sceneTexture(width: Int, height: Int) -> MTLTexture? {
        if let texture = sceneTexture, texture.width == width, texture.height == height {
            return texture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: view.metalLayer.pixelFormat,
                                                                  width: width, height: height,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .private
        sceneTexture = device.makeTexture(descriptor: descriptor)
        return sceneTexture
    }

    /// Where the scene goes in the drawable: keeping its shape, centred, at displayScale.
    /// When zoomed to fill, it overhangs the drawable and draw(_:into:) renders it straight
    /// to the screen, where SKRenderer's own fill crops the overhang.
    private func viewport(for scene: SKScene, drawableSize: CGSize) -> CGRect {
        let scale = Self.displayScale(scene.size, in: drawableSize)
        let width = scene.size.width * scale
        let height = scene.size.height * scale
        return CGRect(x: (drawableSize.width - width) / 2,
                      y: (drawableSize.height - height) / 2,
                      width: width,
                      height: height)
    }

    /// Fills whatever the scene doesn't cover — the bars down the sides on a screen squatter
    /// than 16:9. The same deep blue GameScene uses as its background colour.
    private static let barColor = SKColor(red: 18/256, green: 45/256, blue: 110/256, alpha: 1)

    private func renderPass(into texture: MTLTexture, clearingTo color: SKColor) -> MTLRenderPassDescriptor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColor(red: Double(red), green: Double(green),
                                                            blue: Double(blue), alpha: Double(alpha))
        return pass
    }

    // MARK: - Debug readout

    #if DEBUG
    /// Shows or hides the FPS label, node count and layout guides together, following the
    /// "Debug UI" setting.
    private func applyDebugVisibility() {
        let visible = DebugSettings.showsOverlays
        fpsLabel.isHidden = !visible
        layoutGuides?.isHidden = !visible
        renderer.showsNodeCount = visible

        // Zoom to Fill changes the mapping without changing any size the guides watch.
        layoutGuides?.refresh()
    }

    /// UserDefaults posts this from whichever thread wrote the change, so hop to main
    /// before touching views.
    @objc private func debugSettingsMayHaveChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.applyDebugVisibility()
        }
    }

    /// Stands in for SKView.showsFPS.
    private func setUpFPSLabel() {
        fpsLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        fpsLabel.textColor = .white
        fpsLabel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        fpsLabel.text = " -- fps "
        fpsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fpsLabel)
        NSLayoutConstraint.activate([
            fpsLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -8),
            fpsLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    /// Counts frames that actually reached the screen, and logs any gap longer than one
    /// and a half refreshes. Measured at the display rather than in update(), so it catches
    /// frames lost anywhere in the pipeline, not just ones the game was late with.
    private func recordPresentation(at presentedTime: CFTimeInterval) {
        // Zero means the frame was dropped without ever being shown.
        guard presentedTime > 0 else {
            print("[present] frame dropped before display")
            return
        }

        if lastPresentedTime > 0 {
            let gap = presentedTime - lastPresentedTime
            if gap > 1.5 / 60 {
                print(String(format: "[present] gap: %.1fms between frames on screen", gap * 1000))
            }
        }
        lastPresentedTime = presentedTime

        presentedThisSecond += 1
        if presentedTime - secondStart >= 1 {
            fpsLabel.text = " \(presentedThisSecond) fps "
            presentedThisSecond = 0
            secondStart = presentedTime
        }
    }
    #endif
}

@available(iOS 17.0, *)
extension SceneRenderer: CAMetalDisplayLinkDelegate {
    func metalDisplayLink(_ link: CAMetalDisplayLink, needsUpdate update: CAMetalDisplayLink.Update) {
        drawFrame(into: update.drawable, at: update.targetPresentationTimestamp)
    }
}
