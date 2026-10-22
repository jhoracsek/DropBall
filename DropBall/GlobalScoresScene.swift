//
//  GlobalScoresScene.swift
//  DropBall
//

import SpriteKit
import GameKit

/// The global Game Center leaderboard, drawn in the game's own style.
///
/// A separate scene rather than a second tab on [HighscoreScene]: the local list is built
/// from `ScoreDisplay` digit sprites driven by a bespoke inertial scroll, and these rows are
/// labels with three columns. Sharing that machinery would mean entangling two different row
/// layouts in one scroll loop for no visible gain.
///
/// Built in code, so it's presented with `GlobalScoresScene(size:)` rather than
/// `SKScene(fileNamed:)` like the older scenes.
final class GlobalScoresScene: SKScene {

    // MARK: - Layout

    /// Matches the panel interior that HighscoreScene clips its list to, so both score
    /// screens have the list sitting in the same place.
    private static let windowSize = CGSize(width: 554, height: 794)
    private static let windowOrigin = CGPoint(x: 6, y: -51)

    private static let rowSpacing: CGFloat = 48
    private static let rowFontSize: CGFloat = 24

    /// Column positions in window-local coordinates. Rank is right-aligned so the digits
    /// line up rather than the "1" and the "20" starting at the same x.
    private static let rankRightX: CGFloat = -215
    private static let nameLeftX: CGFloat = -195
    private static let scoreRightX: CGFloat = 261

    /// Clear space kept between the longest score and the name column beside it.
    private static let columnGap: CGFloat = 24

    private static let rowColor = SKColor(white: 1.0, alpha: 0.88)
    private static let dimColor = SKColor(white: 1.0, alpha: 0.5)

    /// The local player's own row, picked out of the list. Matches the "on" green the
    /// settings dropdown uses so the palette stays consistent.
    private static let localPlayerColor = SKColor(red: 0.42, green: 0.86, blue: 0.48, alpha: 1)

    // Dark, because these sit on the sky below the panel rather than on the panel itself.
    private static let footerColor = SKColor(red: 0.07, green: 0.14, blue: 0.32, alpha: 1.0)
    private static let footerLinkColor = SKColor(red: 0.06, green: 0.27, blue: 0.62, alpha: 1.0)

    private static let rankFooterY: CGFloat = -545
    private static let gameCenterFooterY: CGFloat = -597

    /// Movement beyond this counts as a scroll rather than a tap.
    private static let tapSlop: CGFloat = 12

    private let HEIGHT: CGFloat = GameViewController.HEIGHT
    private let WIDTH: CGFloat = GameViewController.WIDTH

    // MARK: - Nodes

    private let background = SKSpriteNode(imageNamed: "background")
    private let mountains = SKSpriteNode(imageNamed: "mountains")
    private let scoreOverlay = SKSpriteNode(imageNamed: "scoreoverlay")

    private var homeButton = SKButton(x: 0, y: 0, unclick: "homebuttonsmall", click: "homebuttonsmall", test_function: {})

    private let content = SKNode()
    private var contentHeight: CGFloat = 0

    private let rankFooter = SKLabelNode(fontNamed: SettingsDropdown.fontName)
    private let gameCenterFooter = SKLabelNode(fontNamed: SettingsDropdown.fontName)

    // MARK: - State

    private enum LoadState {
        case loading
        case loaded(GameCenter.Standings)
        case failed
    }

    private var state: LoadState = .loading

    private var scrollY: CGFloat = 0
    private var dragStartY: CGFloat = 0
    private var dragStartScroll: CGFloat = 0
    private var dragDistance: CGFloat = 0

    // MARK: - Setup

    override func didMove(to view: SKView) {
        // A scene built in code defaults to an anchorPoint of (0,0) — the bottom-left
        // corner — whereas the .sks scenes are all authored at (0.5, 0.5).
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

        scoreOverlay.zPosition = 10
        addChild(scoreOverlay)

        homeButton = SKButton(x: WIDTH/2 - 75, y: HEIGHT/2 - 75,
                              unclick: "homebuttonsmall", click: "homebuttonsmall",
                              test_function: goHome)
        homeButton.scale(scale: 0.65)
        for child in homeButton.getSpriteNode() {
            addChild(child)
        }

        setUpWindow()
        setUpFooters()
        layoutContent()

        load()
    }

    private func setUpWindow() {
        let crop = SKCropNode()
        crop.maskNode = SKSpriteNode(color: .black, size: Self.windowSize)
        crop.position = Self.windowOrigin
        crop.zPosition = 40

        content.position = CGPoint(x: 0, y: Self.windowSize.height/2 - 40)
        crop.addChild(content)
        addChild(crop)
    }

    private func setUpFooters() {
        for (node, y, color) in [(rankFooter, Self.rankFooterY, Self.footerColor),
                                 (gameCenterFooter, Self.gameCenterFooterY, Self.footerLinkColor)] {
            node.fontSize = 24
            node.fontColor = color
            node.verticalAlignmentMode = .center
            node.position = CGPoint(x: 0, y: y)
            node.zPosition = 20
            node.alpha = 0
            addChild(node)
        }

        gameCenterFooter.text = "VIEW IN GAME CENTER"
    }

    // MARK: - Loading

    private func load() {
        state = .loading
        layoutContent()

        Task { @MainActor in
            do {
                state = .loaded(try await GameCenter.loadTopScores())
            } catch {
                print("Game Center leaderboard load failed: \(error.localizedDescription)")
                state = .failed
            }
            layoutContent()
        }
    }

    // MARK: - Layout

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        node.horizontalAlignmentMode = .left
        return node
    }

    /// Rebuilds the list for the current state. Cheap enough to run wholesale — the list is
    /// twenty rows, and it only changes when the load finishes.
    private func layoutContent() {
        content.removeAllChildren()

        switch state {
        case .loading:
            centredMessage("LOADING...", detail: nil)
        case .failed:
            centredMessage("COULDN'T LOAD SCORES", detail: "Tap to try again")
        case .loaded(let standings) where standings.entries.isEmpty:
            centredMessage("NO SCORES YET", detail: "Be the first")
        case .loaded(let standings):
            layoutRows(standings.entries)
        }

        updateFooters()
    }

    private func centredMessage(_ text: String, detail: String?) {
        contentHeight = 0

        // A message can replace a list that was left scrolled — on a retry, say. The
        // centring below is relative to an unscrolled content node, so this has to go back
        // to the top or the message lands off-panel.
        scrollY = 0
        content.position.y = Self.windowSize.height/2 - 40

        // Positioned against the middle of the window rather than the top, where the rows
        // start, so a one-line message isn't stranded at the top of an empty panel.
        let centreY = -Self.windowSize.height/2 + 40

        let headline = label(text, size: 32, color: Self.rowColor)
        headline.horizontalAlignmentMode = .center
        headline.position = CGPoint(x: 0, y: centreY + (detail == nil ? 0 : 20))
        content.addChild(headline)

        if let detail {
            let node = label(detail, size: 16, color: Self.dimColor)
            node.horizontalAlignmentMode = .center
            node.position = CGPoint(x: 0, y: centreY - 20)
            content.addChild(node)
        }
    }

    private func layoutRows(_ entries: [GameCenter.Entry]) {
        var y: CGFloat = 0

        // Names get whatever the score column doesn't need. Measured from the real scores
        // rather than assumed: the score column is right-aligned, so a five-digit score
        // reaches 45 points further left than a three-digit one, and a fixed name budget
        // that looks fine at "142" collides at "99999".
        let nameMaxWidth = Self.scoreRightX
            - widestScoreWidth(entries)
            - Self.columnGap
            - Self.nameLeftX

        for (index, entry) in entries.enumerated() {
            // Advanced before each row but the first, so `contentHeight` ends up as the
            // distance to the *last* row rather than including a trailing gap below it —
            // which would otherwise let the list scroll one empty row too far.
            if index > 0 { y -= Self.rowSpacing }

            let color = entry.isLocalPlayer ? Self.localPlayerColor : Self.rowColor

            let rank = label("\(entry.rank)", size: Self.rowFontSize, color: color)
            rank.horizontalAlignmentMode = .right
            rank.position = CGPoint(x: Self.rankRightX, y: y)
            content.addChild(rank)

            let name = label(truncate(entry.name, to: nameMaxWidth, size: Self.rowFontSize),
                             size: Self.rowFontSize, color: color)
            name.position = CGPoint(x: Self.nameLeftX, y: y)
            content.addChild(name)

            let score = label("\(entry.score)", size: Self.rowFontSize, color: color)
            score.horizontalAlignmentMode = .right
            score.position = CGPoint(x: Self.scoreRightX, y: y)
            content.addChild(score)
        }

        contentHeight = -y

        // A reload can land while scrolled past the new, possibly shorter, end.
        scrollY = min(scrollY, maxScroll)
        content.position.y = Self.windowSize.height/2 - 40 + scrollY
    }

    /// Width of the longest score in the list, as drawn.
    private func widestScoreWidth(_ entries: [GameCenter.Entry]) -> CGFloat {
        let ruler = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        ruler.fontSize = Self.rowFontSize

        return entries.reduce(0) { widest, entry in
            ruler.text = "\(entry.score)"
            return max(widest, ruler.frame.width)
        }
    }

    /// Clips a display name to `width`, ending it with an ellipsis.
    ///
    /// Game Center display names are arbitrary and can be far wider than the name column.
    /// Measured with the real font rather than cut at a character count, because Pixel
    /// Operator is proportional — an "I" is a third the width of a "W".
    private func truncate(_ name: String, to width: CGFloat, size: CGFloat) -> String {
        let ruler = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        ruler.fontSize = size

        func fits(_ candidate: String) -> Bool {
            ruler.text = candidate
            return ruler.frame.width <= width
        }

        guard !fits(name) else { return name }

        var trimmed = name
        while !trimmed.isEmpty {
            trimmed.removeLast()
            if fits(trimmed + "...") { return trimmed + "..." }
        }

        return "..."
    }

    private func updateFooters() {
        guard case .loaded(let standings) = state else {
            rankFooter.alpha = 0
            gameCenterFooter.alpha = 0
            return
        }

        if let rank = standings.localRank {
            rankFooter.text = "YOUR RANK: \(rank) OF \(standings.totalPlayers)"
        } else {
            rankFooter.text = "YOU ARE NOT RANKED YET"
        }

        rankFooter.alpha = 1
        gameCenterFooter.alpha = 1
    }

    /// How far the list can travel before its last row reaches the bottom of the window.
    private var maxScroll: CGFloat {
        max(0, contentHeight - Self.windowSize.height + 80)
    }

    private func goHome() {
        Entity.cameraTranslationY = 0

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
        content.position.y = Self.windowSize.height/2 - 40 + scrollY
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        homeButton.unpressed()

        guard let pos = touches.first?.location(in: self) else { return }

        // Only a tap if the finger barely moved, so scrolling the list doesn't also fire
        // whatever happened to be under it.
        guard dragDistance <= Self.tapSlop else { return }
        handleTap(at: pos)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        homeButton.unpressed()
    }

    private func handleTap(at pos: CGPoint) {
        if gameCenterFooter.alpha > 0 && gameCenterFooter.frame.insetBy(dx: -20, dy: -22).contains(pos) {
            GameCenter.presentLeaderboard()
            return
        }

        // Retry by tapping the panel, which is where the failure message is.
        if case .failed = state, scoreOverlay.frame.contains(pos) {
            load()
        }
    }
}
