//
//  AttributionsScene.swift
//  DropBall
//

import SpriteKit
import UIKit

/// Credits screen. Lays itself out from `Attributions.all`, so adding an asset to that list
/// is the only step needed to credit it.
///
/// Built in code rather than from a .sks, so it's presented with `AttributionsScene(size:)`
/// rather than `SKScene(fileNamed:)` like the older scenes.
final class AttributionsScene: SKScene {

    // MARK: - Layout

    /// The clip region for scrolling. No longer tied to the panel art, so it's centred and
    /// wider than the highscore list — which also relieves the tight line-width budget the
    /// panel's interior imposed.
    private static let windowSize = CGSize(width: 660, height: 780)
    private static let windowOrigin = CGPoint(x: 0, y: -60)

    private static let entrySpacing: CGFloat = 30
    private static let lineSpacing: CGFloat = 26
    private static let titleSize: CGFloat = 24
    private static let bodySize: CGFloat = 16

    /// Licence boilerplate is set tighter than the list rows — it's there to be complete,
    /// not to be read at a glance, and 26pt leading over thirty-odd lines swamps the page.
    private static let licenceLineSpacing: CGFloat = 19

    /// Left inset applied to every row, and so the amount the usable width is reduced by on
    /// each side.
    private static let textInset: CGFloat = 20

    // Dark, because the sky behind this screen averages around 195 of 255 in luminance.
    // The white used before only worked against the panel; on the sky it comes out at
    // roughly 1.75:1 contrast, well under the 4.5:1 that's readable. These sit near 8:1.
    private static let headingColor = SKColor(red: 0.07, green: 0.14, blue: 0.32, alpha: 1.0)
    private static let bodyColor = SKColor(red: 0.07, green: 0.14, blue: 0.32, alpha: 0.78)
    private static let linkColor = SKColor(red: 0.06, green: 0.27, blue: 0.62, alpha: 1.0)

    /// Movement beyond this counts as a scroll rather than a tap on a link.
    private static let tapSlop: CGFloat = 12

    private let HEIGHT: CGFloat = GameViewController.HEIGHT
    private let WIDTH: CGFloat = GameViewController.WIDTH

    // MARK: - Nodes

    private let background = SKSpriteNode(imageNamed: "background")
    private let mountains = SKSpriteNode(imageNamed: "mountains")

    private var homeButton = SKButton(x: 0, y: 0, unclick: "homebuttonsmall", click: "homebuttonsmall", test_function: {})

    private let content = SKNode()
    private var contentHeight: CGFloat = 0

    // MARK: - Scrolling

    private var scrollY: CGFloat = 0
    private var dragStartY: CGFloat = 0
    private var dragStartScroll: CGFloat = 0
    private var dragDistance: CGFloat = 0

    /// Tappable regions, in content-local coordinates, paired with what they open.
    private var links: [(range: ClosedRange<CGFloat>, url: URL)] = []

    /// Tappable regions that expand a bundled licence, keyed by the entry's title.
    private var disclosures: [(range: ClosedRange<CGFloat>, title: String)] = []

    /// Which licence texts are currently unfolded. Collapsed on every visit — the text is
    /// there to be available, not to be read every time.
    private var expandedLicences: Set<String> = []

    // MARK: - Setup

    override func didMove(to view: SKView) {
        // A scene built in code defaults to an anchorPoint of (0,0) — the bottom-left
        // corner — whereas the .sks scenes are all authored at (0.5, 0.5). Every position
        // in this file assumes a centre origin like the rest of the game, so without this
        // the whole screen sits in the bottom-left quadrant.
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        backgroundColor = SKColor(red: 18/256, green: 45/256, blue: 110/256, alpha: 1)

        background.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        background.position.y = HEIGHT/2
        background.zPosition = -1
        addChild(background)

        // Over the gradient, under the mountains (-0.9).
        addChild(BackgroundOverlay.make())

        mountains.anchorPoint = CGPoint(x: 0, y: 0)
        mountains.position = CGPoint(x: -WIDTH/2, y: -HEIGHT/2)
        mountains.zPosition = -0.9
        addChild(mountains)

        let title = label("Credits", size: MenuTextSize.title, color: Self.headingColor)
        // The label helper defaults to left alignment for the list rows; a page heading
        // wants centring.
        title.horizontalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 352)
        title.zPosition = 20
        addChild(title)

        homeButton = SKButton(x: WIDTH/2 - 75, y: HEIGHT/2 - 75,
                              unclick: "homebuttonsmall", click: "homebuttonsmall",
                              test_function: goHome)
        homeButton.scale(scale: 0.65)
        for child in homeButton.getSpriteNode() {
            addChild(child)
        }

        buildList()
    }

    /// Greedily breaks `text` into lines that fit `width`, measuring with the real font
    /// rather than counting characters.
    ///
    /// Pixel Operator is proportional, not monospace: at 16pt a lowercase "i" is under 10
    /// points wide and a capital "W" is 18, so a fixed column count either wraps prose far
    /// too early or lets the licence's all-caps warranty paragraph run off the panel.
    /// Paragraphs are separated by blank lines and re-flowed, so the stored text doesn't
    /// have to be pre-wrapped to any particular width.
    private func wrap(_ text: String, size: CGFloat, width: CGFloat) -> [String] {
        // One reused node for every measurement; SKLabelNode reports its width as soon as
        // the text is set, with no need to be in the tree.
        let ruler = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        ruler.fontSize = size

        func measure(_ candidate: String) -> CGFloat {
            ruler.text = candidate
            return ruler.frame.width
        }

        var lines: [String] = []

        for paragraph in text.components(separatedBy: "\n\n") {
            let words = paragraph.split(whereSeparator: \.isWhitespace).map(String.init)
            guard !words.isEmpty else { continue }

            var line = ""
            for word in words {
                let candidate = line.isEmpty ? word : line + " " + word
                if line.isEmpty || measure(candidate) <= width {
                    line = candidate
                } else {
                    lines.append(line)
                    line = word
                }
            }
            if !line.isEmpty { lines.append(line) }

            // Blank line between paragraphs, which the caller renders as vertical space.
            lines.append("")
        }

        // Trailing separator after the final paragraph is just dead space.
        if lines.last == "" { lines.removeLast() }

        return lines
    }

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .left
        return node
    }

    /// Sets up the clipped scrolling window, then fills it.
    private func buildList() {
        let crop = SKCropNode()
        let mask = SKSpriteNode(color: .black, size: Self.windowSize)
        crop.maskNode = mask
        crop.position = Self.windowOrigin
        crop.zPosition = 40

        // Content is positioned from the top of the window downwards.
        content.position = CGPoint(x: 0, y: Self.windowSize.height/2 - 30)
        crop.addChild(content)
        addChild(crop)

        layoutContent()
    }

    /// Lays out every entry into `content`. Re-run when a licence is folded or unfolded,
    /// since that changes the height of everything below it.
    private func layoutContent() {
        content.removeAllChildren()
        links.removeAll()
        disclosures.removeAll()

        let left = -Self.windowSize.width/2 + Self.textInset
        let usableWidth = Self.windowSize.width - Self.textInset * 2
        var y: CGFloat = 0

        for (index, item) in Attributions.all.enumerated() {
            if index > 0 { y -= Self.entrySpacing }

            let heading = label(item.title, size: Self.titleSize, color: Self.headingColor)
            heading.position = CGPoint(x: left, y: y)
            content.addChild(heading)
            y -= Self.lineSpacing + 4

            for line in ["by \(item.author)", item.licence] {
                let node = label(line, size: Self.bodySize, color: Self.bodyColor)
                node.position = CGPoint(x: left, y: y)
                content.addChild(node)
                y -= Self.lineSpacing
            }

            if let modifications = item.modifications {
                let node = label("Modified: \(modifications)", size: Self.bodySize, color: Self.bodyColor)
                node.position = CGPoint(x: left, y: y)
                content.addChild(node)
                y -= Self.lineSpacing
            }

            // The source link doubles as the "link to the material" CC BY asks for. Shown
            // shortened because a full itch.io URL is far wider than the panel.
            if let source = item.sourceURL, let url = URL(string: source) {
                let shown = item.displayLink ?? source
                let node = label("\(shown)  >", size: Self.bodySize, color: Self.linkColor)
                node.position = CGPoint(x: left, y: y)
                content.addChild(node)
                links.append((range: (y - 14)...(y + 14), url: url))
                y -= Self.lineSpacing
            }

            if let licenceText = item.licenceText {
                // A licence that ships its own text gets a fold rather than a link out: the
                // bundled copy is the one that matters, so an external link would be a
                // second row saying the same thing.
                let expanded = expandedLicences.contains(item.title)
                let node = label("\(item.licence) licence  \(expanded ? "-" : "+")",
                                 size: Self.bodySize, color: Self.linkColor)
                node.position = CGPoint(x: left, y: y)
                content.addChild(node)
                disclosures.append((range: (y - 14)...(y + 14), title: item.title))
                y -= Self.lineSpacing

                if expanded {
                    y -= 6
                    for line in wrap(licenceText, size: Self.bodySize, width: usableWidth) {
                        // Blank entries are paragraph breaks — no node, just the gap.
                        if !line.isEmpty {
                            let node = label(line, size: Self.bodySize, color: Self.bodyColor)
                            node.position = CGPoint(x: left, y: y)
                            content.addChild(node)
                        }
                        y -= Self.licenceLineSpacing
                    }
                }
            } else if let licenceLink = item.licenceURL, let url = URL(string: licenceLink) {
                let node = label("\(item.licence) terms  >", size: Self.bodySize, color: Self.linkColor)
                node.position = CGPoint(x: left, y: y)
                content.addChild(node)
                links.append((range: (y - 14)...(y + 14), url: url))
                y -= Self.lineSpacing
            }
        }

        contentHeight = -y

        // Folding a licence shut can leave the view scrolled past the new, shorter end.
        scrollY = min(scrollY, maxScroll)
        content.position.y = Self.windowSize.height/2 - 30 + scrollY
    }

    /// How far the list can travel before its last line reaches the bottom of the window.
    private var maxScroll: CGFloat {
        max(0, contentHeight - Self.windowSize.height + 60)
    }

    private func goHome() {
        if let scene = SKScene(fileNamed: "StartScene") {
            scene.size = CGSize(width: GameViewController.WIDTH, height: GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.5))
        }
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self) else { return }

        homeButton.checkPressed(pos: pos)

        dragStartY = pos.y
        dragStartScroll = scrollY
        dragDistance = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pos = touches.first?.location(in: self) else { return }

        let delta = pos.y - dragStartY
        dragDistance = max(dragDistance, abs(delta))

        scrollY = min(max(dragStartScroll + delta, 0), maxScroll)
        content.position.y = Self.windowSize.height/2 - 30 + scrollY
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        homeButton.unpressed()

        guard let pos = touches.first?.location(in: self) else { return }

        // Only treat it as a tap if the finger barely moved, so scrolling past a link
        // doesn't open it.
        guard dragDistance <= Self.tapSlop else { return }
        handleTap(at: pos)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        homeButton.unpressed()
    }

    private func handleTap(at scenePoint: CGPoint) {
        // Scene point -> content-local, accounting for the crop node and the scroll offset.
        let localY = scenePoint.y - Self.windowOrigin.y - content.position.y
        let localX = scenePoint.x - Self.windowOrigin.x

        guard abs(localX) <= Self.windowSize.width/2 else { return }

        for fold in disclosures where fold.range.contains(localY) {
            if expandedLicences.contains(fold.title) {
                expandedLicences.remove(fold.title)
            } else {
                expandedLicences.insert(fold.title)
            }
            layoutContent()
            return
        }

        for link in links where link.range.contains(localY) {
            UIApplication.shared.open(link.url)
            return
        }
    }
}

/// Font sizes shared with the settings dropdown, kept as multiples of the font's 8px grid.
enum MenuTextSize {
    static let title: CGFloat = 32
}
