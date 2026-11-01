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
        #if DEBUG
        renderer.showsNodeCount = true
        #endif

        view.metalLayer.device = device
        view.metalLayer.pixelFormat = .bgra8Unorm
        view.metalLayer.framebufferOnly = true

        #if DEBUG
        // Added before the FPS label so the label stays on top of the guides.
        if Self.showsLayoutGuides {
            let guides = LayoutGuideOverlay(frame: view.bounds)
            guides.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(guides)
            layoutGuides = guides
        }
        setUpFPSLabel()
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
                        renderPassDescriptor: renderPass(into: texture, clearingTo: scene))
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

    /// Converts a touch into scene coordinates with the same aspect-fill mapping used to
    /// draw, so a point lands on whatever is drawn under it.
    func location(of touch: UITouch, in scene: SKScene) -> CGPoint {
        let point = touch.location(in: view)
        let bounds = view.bounds.size
        let scale = max(bounds.width / scene.size.width, bounds.height / scene.size.height)
        return CGPoint(x: (point.x - bounds.width / 2) / scale + scene.size.width * (0.5 - scene.anchorPoint.x),
                       y: (bounds.height / 2 - point.y) / scale + scene.size.height * (0.5 - scene.anchorPoint.y))
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

        let drawableSize = CGSize(width: drawable.texture.width, height: drawable.texture.height)
        renderer.render(withViewport: viewport(for: scene, drawableSize: drawableSize),
                        commandBuffer: commandBuffer,
                        renderPassDescriptor: renderPass(into: drawable.texture, clearingTo: scene))

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

    /// The scene keeps its aspect ratio and fills the screen — .aspectFill, which every
    /// scene used — with any overflow cropped equally from both sides.
    private func viewport(for scene: SKScene, drawableSize: CGSize) -> CGRect {
        let scale = max(drawableSize.width / scene.size.width,
                        drawableSize.height / scene.size.height)
        let width = scene.size.width * scale
        let height = scene.size.height * scale
        return CGRect(x: (drawableSize.width - width) / 2,
                      y: (drawableSize.height - height) / 2,
                      width: width,
                      height: height)
    }

    private func renderPass(into texture: MTLTexture, clearingTo scene: SKScene) -> MTLRenderPassDescriptor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        scene.backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

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
