//
//  HighscoreScene.swift
//  DropBall
//
//  Created by Jordan Horacsek on 2022-05-03.
//

import SpriteKit

/// The score screen, in two modes: this device's best runs, and the global Game Center
/// leaderboard. One scene rather than two, so switching between them is an in-place swap
/// instead of a scene transition.
///
/// Still loaded from HighscoreScene.sks, which holds no nodes of its own — it exists to carry
/// the custom class and the centred anchor point that every .sks scene in the project uses.
class HighscoreScene: SKScene, PresentedScene {
    let HEIGHT : CGFloat = GameViewController.HEIGHT
    let WIDTH : CGFloat = GameViewController.WIDTH

    // MARK: - Layout

    /// The panel art's dark interior, which runs from y 347 down to -448.
    private static let panelInteriorTop: CGFloat = 346
    private static let panelInteriorCentreX: CGFloat = 6
    private static let panelInteriorWidth: CGFloat = 554

    /// The strip taken off the top of the interior for the column headings.
    private static let headerHeight: CGFloat = 56

    /// The clip region for the rows: the panel interior less the heading strip.
    ///
    /// The headings have to sit *outside* this, not merely above it in z — a row scrolled to
    /// the top of the full interior would otherwise slide up into the heading strip and be
    /// drawn over them.
    private static let rowWindowSize = CGSize(width: panelInteriorWidth, height: 794 - headerHeight)
    private static let rowWindowOrigin = CGPoint(x: panelInteriorCentreX, y: -51 - headerHeight/2)

    /// Distance from the top and bottom of the row window to the nearest row.
    private static let listInset: CGFloat = 36

    private static let headerFontSize: CGFloat = 16
    private static let headerColor = SKColor(white: 1.0, alpha: 0.6)
    private static let headerRuleColor = SKColor(white: 1.0, alpha: 0.18)

    private static let rowSpacing: CGFloat = 48
    private static let rowFontSize: CGFloat = 24

    /// Column positions in window-local coordinates. Rank and score are right-aligned so
    /// their digits line up, rather than "1" and "20" sharing a left edge.
    private static let rankRightX: CGFloat = -215
    private static let middleLeftX: CGFloat = -195
    private static let scoreRightX: CGFloat = 261

    /// Clear space kept between the longest score and the column beside it.
    private static let columnGap: CGFloat = 24

    private static let rowColor = SKColor(white: 1.0, alpha: 0.88)
    private static let dimColor = SKColor(white: 1.0, alpha: 0.5)

    /// The local player's own row in the global list. Matches the "on" green from the
    /// settings dropdown so the palette stays consistent.
    private static let highlightColor = SKColor(red: 0.42, green: 0.86, blue: 0.48, alpha: 1)

    // The footers sit on the sky below the panel rather than on the panel itself, where
    // white comes out at under 2:1. These are the credits screen's colours.
    private static let footerColor = SKColor(red: 0.07, green: 0.14, blue: 0.32, alpha: 1.0)
    private static let footerLinkColor = SKColor(red: 0.06, green: 0.27, blue: 0.62, alpha: 1.0)

    /// The panel bottoms out at -500, and on a 16:9 phone (half-height 667) that leaves
    /// about 167 points of sky underneath. Two rows is what fits. Shorter scenes scale the
    /// whole group down instead — see fitPanel().
    private static let toggleFooterY: CGFloat = -542
    private static let rankFooterY: CGFloat = -596

    /// Padding added around a footer label to make it a comfortable finger target.
    ///
    /// The vertical figure is capped by the 54-point gap between the two footers: a label is
    /// 23 points tall, so anything over 15 makes the two targets overlap, and the toggle —
    /// tested first — would swallow taps aimed at the top of the row below it. 14 still gives
    /// a 51-point target, comfortably over the 44 Apple asks for.
    private static let footerTouchPadding = CGSize(width: 20, height: 14)

    // MARK: - Nodes

    let background = SKSpriteNode(imageNamed: "background")
    let scoreOverlay = SKSpriteNode(imageNamed: "scoreoverlay")
    let mountains = SKSpriteNode(imageNamed: "mountains")

    var homeButton = SKButton(x:0, y:100, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: {} )

    private let content = SKNode()
    private var contentHeight: CGFloat = 0

    /// The panel art, the list, its headings and the footers, kept together so the whole
    /// layout can be scaled down as one on a screen too short for it.
    private let panel = SKNode()

    private let toggleFooter = SKLabelNode(fontNamed: SettingsDropdown.fontName)
    private let rankFooter = SKLabelNode(fontNamed: SettingsDropdown.fontName)

    /// Column headings, pinned above the scrolling rows.
    private let header = SKNode()
    private let rankHeading = SKLabelNode(fontNamed: SettingsDropdown.fontName)
    private let middleHeading = SKLabelNode(fontNamed: SettingsDropdown.fontName)
    private let scoreHeading = SKLabelNode(fontNamed: SettingsDropdown.fontName)

    // MARK: - State

    enum Mode {
        case local
        case global
    }

    private var mode: Mode = .local

    /// The global list is fetched on first switch and then kept, so toggling back and forth
    /// doesn't re-hit the network every time.
    private enum GlobalState {
        case notLoaded
        case loading
        case loaded(GameCenter.Standings)
        case failed
    }

    private var globalState: GlobalState = .notLoaded

    private var scores = [Score]()

    /// A row of the list, in whichever mode. Both modes reduce to rank / middle / score, so
    /// the layout below doesn't need to know which one it's drawing.
    private struct Row {
        let rank: Int
        let middle: String
        let score: Int
        let highlighted: Bool
    }

    /// Local rows are dated rather than named. Scores saved before dates were recorded have
    /// none, and show nothing rather than a placeholder date.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - Scrolling

    private var scrollY: CGFloat = 0
    private var velocity: CGFloat = 0
    private var isDragging = false
    private var dragStartY: CGFloat = 0
    private var dragStartScroll: CGFloat = 0
    private var dragDistance: CGFloat = 0
    private var previousTouchY: CGFloat = 0
    private var currentTouchY: CGFloat = 0

    /// Movement beyond this counts as a scroll rather than a tap.
    private static let tapSlop: CGFloat = 12

    #if DEBUG
    private var debugOverlay: DebugOverlay?

    /// First tap arms, second tap wipes. Cheap guard against losing a pile of test scores
    /// to a stray tap, without putting an alert in the way.
    private var resetArmed = false
    #endif

    // MARK: - Setup

    func didPresent() {
        getScores()

        background.anchorPoint = CGPoint(x:0.5,y:1.0)
        background.position.y = GameViewController.HEIGHT/2
        self.addChild(background)
        background.zPosition = -1

        // Over the gradient, under the mountains (-0.9).
        addChild(BackgroundOverlay.make())
        panel.addChild(scoreOverlay)
        scoreOverlay.zPosition = 10

        addChild(mountains)
        mountains.anchorPoint = CGPoint(x:0,y:0)
        mountains.position.x = -WIDTH/2
        mountains.position.y = GameViewController.mountainsBaseY
        mountains.zPosition = -0.9

        homeButton = SKButton(x:(WIDTH/2-75), y:HEIGHT/2-75, unclick:"homebuttonsmall", click:"homebuttonsmall", test_function: go_home )
        homeButton.scale(scale: 0.65)
        // Pulled in from the corner only where it would otherwise be off-screen or under
        // the camera, rounded corners or home indicator.
        homeButton.keep(inside: safeFrame)

        for child in homeButton.getSpriteNode(){
            addChild(child)
        }

        setUpWindow()
        setUpHeader()
        setUpFooters()
        layoutContent()

        addChild(panel)
        fitPanel()

        #if DEBUG
        setUpDebugOverlay()
        #endif
    }

    private func getScores(){
        scores = ScoreStore.top()
    }

    private func setUpWindow() {
        let crop = SKCropNode()
        crop.maskNode = SKSpriteNode(color: .black, size: Self.rowWindowSize)
        crop.position = Self.rowWindowOrigin
        crop.zPosition = 40

        content.position = CGPoint(x: 0, y: listTopY)
        crop.addChild(content)
        panel.addChild(crop)
    }

    /// Builds the headings and the rule under them, in scene coordinates, sitting in the
    /// strip above the row window.
    private func setUpHeader() {
        let baselineY = Self.panelInteriorTop - 22
        let ruleY = Self.panelInteriorTop - Self.headerHeight + 6

        let columns: [(SKLabelNode, CGFloat, SKLabelHorizontalAlignmentMode)] = [
            (rankHeading, Self.rankRightX, .right),
            (middleHeading, Self.middleLeftX, .left),
            (scoreHeading, Self.scoreRightX, .right)
        ]

        for (node, columnX, alignment) in columns {
            node.fontSize = Self.headerFontSize
            node.fontColor = Self.headerColor
            node.verticalAlignmentMode = .center
            node.horizontalAlignmentMode = alignment
            node.position = CGPoint(x: Self.panelInteriorCentreX + columnX, y: baselineY)
            header.addChild(node)
        }

        let halfWidth = Self.panelInteriorWidth/2
        let rule = SKShapeNode()
        let path = UIBezierPath()
        path.move(to: CGPoint(x: Self.panelInteriorCentreX - halfWidth, y: ruleY))
        path.addLine(to: CGPoint(x: Self.panelInteriorCentreX + halfWidth, y: ruleY))
        rule.path = path.cgPath
        rule.lineWidth = 2
        rule.strokeColor = Self.headerRuleColor
        header.addChild(rule)

        header.zPosition = 45
        panel.addChild(header)
    }

    private func setUpFooters() {
        for (node, y, color) in [(toggleFooter, Self.toggleFooterY, Self.footerColor),
                                 (rankFooter, Self.rankFooterY, Self.footerLinkColor)] {
            node.fontSize = 24
            node.fontColor = color
            node.verticalAlignmentMode = .center
            node.horizontalAlignmentMode = .center
            node.position = CGPoint(x: 0, y: y)
            node.zPosition = 20
            node.alpha = 0
            panel.addChild(node)
        }
    }

    /// Lowest point of the panel group, in its own coordinates: the second footer, with
    /// room for its touch padding.
    private static let panelGroupBottom: CGFloat = rankFooterY - 30

    /// Scales and centres the panel group into the safe space below the home button, but
    /// only when the layout as designed doesn't fit — so every screen it already fitted is
    /// left exactly as it was. Squat screens like the folded iPhone Duo give the scene too
    /// little height for the panel plus its footers.
    private func fitPanel() {
        let safe = safeFrame
        let margin: CGFloat = 12

        let top = min(safe.maxY, homeButton.y - homeButton.unclickedSprite.size.height/2) - margin
        let bottom = safe.minY + margin
        let groupTop = scoreOverlay.size.height/2
        let groupHeight = groupTop - Self.panelGroupBottom
        let groupWidth = scoreOverlay.size.width

        let fitsAsDesigned = groupTop <= top && Self.panelGroupBottom >= bottom
            && -groupWidth/2 >= safe.minX + margin && groupWidth/2 <= safe.maxX - margin
        guard !fitsAsDesigned else { return }

        let scale = min(1, (top - bottom) / groupHeight, (safe.width - 2 * margin) / groupWidth)
        panel.setScale(scale)

        // Centred in the space available rather than on the screen, since that space can be
        // lopsided — the folded Duo's camera strip runs down the right-hand side only.
        let groupMidY = (groupTop + Self.panelGroupBottom) / 2
        panel.position = CGPoint(x: safe.midX, y: (top + bottom) / 2 - groupMidY * scale)
    }

    // MARK: - Mode

    private func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }

        mode = newMode

        // The two lists are different lengths, so carrying the offset over would leave the
        // shorter one scrolled past its end.
        scrollY = 0
        velocity = 0

        if case .notLoaded = globalState, mode == .global {
            loadGlobalScores()
        } else {
            layoutContent()
        }
    }

    private func loadGlobalScores() {
        globalState = .loading
        layoutContent()

        Task { @MainActor in
            do {
                globalState = .loaded(try await GameCenter.loadTopScores())
            } catch {
                print("Game Center leaderboard load failed: \(error.localizedDescription)")
                globalState = .failed
            }

            // The player may have switched back to the local list while this was in flight.
            if mode == .global {
                layoutContent()
            }
        }
    }

    // MARK: - Layout

    private var listTopY: CGFloat {
        Self.rowWindowSize.height/2 - Self.listInset
    }

    /// Headings describe columns, so they're hidden whenever there are no columns to
    /// describe — an empty list, a load in flight, or a failure.
    private func updateHeader(showing: Bool) {
        header.alpha = showing ? 1 : 0
        guard showing else { return }

        rankHeading.text = "#"
        scoreHeading.text = "SCORE"
        middleHeading.text = mode == .local ? "DATE" : "PLAYER"
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

    /// Rebuilds the list for the current mode and state. Cheap enough to run wholesale —
    /// it's twenty rows, and it only runs on a mode switch or a completed load.
    private func layoutContent() {
        content.removeAllChildren()
        updateHeader(showing: hasRows)

        switch mode {
        case .local:
            if scores.isEmpty {
                // On a fresh install the panel is otherwise a blank grey rectangle, which
                // reads as a loading failure rather than "you haven't played yet".
                centredMessage("NO SCORES YET", detail: "Play a round to set one")
            } else {
                layoutRows(localRows())
            }

        case .global:
            switch globalState {
            case .notLoaded, .loading:
                centredMessage("LOADING...", detail: nil)
            case .failed:
                centredMessage("COULDN'T LOAD SCORES", detail: "Tap to try again")
            case .loaded(let standings) where standings.entries.isEmpty:
                centredMessage("NO SCORES YET", detail: "Be the first")
            case .loaded(let standings):
                layoutRows(globalRows(standings))
            }
        }

        updateFooters()
    }

    /// Whether the current mode and state will draw actual rows, as opposed to a message.
    private var hasRows: Bool {
        switch mode {
        case .local:
            return !scores.isEmpty
        case .global:
            if case .loaded(let standings) = globalState { return !standings.entries.isEmpty }
            return false
        }
    }

    private func localRows() -> [Row] {
        scores.enumerated().map { index, score in
            Row(rank: index + 1,
                middle: score.date.map { Self.dateFormatter.string(from: $0) } ?? "",
                score: Int(score.score),
                highlighted: false)
        }
    }

    private func globalRows(_ standings: GameCenter.Standings) -> [Row] {
        standings.entries.map { entry in
            Row(rank: entry.rank,
                middle: entry.name,
                score: entry.score,
                highlighted: entry.isLocalPlayer)
        }
    }

    private func centredMessage(_ text: String, detail: String?) {
        contentHeight = 0

        // A message can replace a list that was left scrolled. The centring below assumes an
        // unscrolled content node, so this has to go back to the top or it lands off-panel.
        scrollY = 0
        velocity = 0
        content.position.y = listTopY

        let centreY = -Self.rowWindowSize.height/2 + Self.listInset

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

    private func layoutRows(_ rows: [Row]) {
        var y: CGFloat = 0

        // The middle column gets whatever the score column doesn't need. Measured from the
        // real scores rather than assumed: the score column is right-aligned, so a five-digit
        // score reaches 45 points further left than a three-digit one, and a fixed budget
        // that looks fine at "142" collides at "99999".
        let middleMaxWidth = Self.scoreRightX
            - widestScoreWidth(rows)
            - Self.columnGap
            - Self.middleLeftX

        for (index, row) in rows.enumerated() {
            // Advanced before each row but the first, so `contentHeight` ends up as the
            // distance to the *last* row rather than including a trailing gap below it —
            // which would otherwise let the list scroll one empty row too far.
            if index > 0 { y -= Self.rowSpacing }

            let color = row.highlighted ? Self.highlightColor : Self.rowColor

            let rank = label("\(row.rank)", size: Self.rowFontSize, color: color)
            rank.horizontalAlignmentMode = .right
            rank.position = CGPoint(x: Self.rankRightX, y: y)
            content.addChild(rank)

            if !row.middle.isEmpty {
                let middle = label(truncate(row.middle, to: middleMaxWidth, size: Self.rowFontSize),
                                   size: Self.rowFontSize,
                                   color: row.highlighted ? color : Self.dimColor)
                middle.position = CGPoint(x: Self.middleLeftX, y: y)
                content.addChild(middle)
            }

            let score = label("\(row.score)", size: Self.rowFontSize, color: color)
            score.horizontalAlignmentMode = .right
            score.position = CGPoint(x: Self.scoreRightX, y: y)
            content.addChild(score)
        }

        contentHeight = -y

        // A reload can land while scrolled past the new, possibly shorter, end.
        scrollY = min(scrollY, maxScroll)
        content.position.y = listTopY + scrollY
    }

    /// Width of the longest score in the list, as drawn.
    private func widestScoreWidth(_ rows: [Row]) -> CGFloat {
        let ruler = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        ruler.fontSize = Self.rowFontSize

        return rows.reduce(0) { widest, row in
            ruler.text = "\(row.score)"
            return max(widest, ruler.frame.width)
        }
    }

    /// Clips text to `width`, ending it with an ellipsis.
    ///
    /// Game Center display names are arbitrary and can be far wider than the column.
    /// Measured with the real font rather than cut at a character count, because Pixel
    /// Operator is proportional — an "I" is a third the width of a "W".
    private func truncate(_ text: String, to width: CGFloat, size: CGFloat) -> String {
        let ruler = SKLabelNode(fontNamed: SettingsDropdown.fontName)
        ruler.fontSize = size

        func fits(_ candidate: String) -> Bool {
            ruler.text = candidate
            return ruler.frame.width <= width
        }

        guard !fits(text) else { return text }

        var trimmed = text
        while !trimmed.isEmpty {
            trimmed.removeLast()
            if fits(trimmed + "...") { return trimmed + "..." }
        }

        return "..."
    }

    private func updateFooters() {
        switch mode {
        case .local:
            // Hidden until sign-in completes, which happens asynchronously and often after
            // this scene is already on screen. update() reveals it when it lands.
            toggleFooter.text = "GLOBAL SCORES  >"
            toggleFooter.alpha = GameCenter.isAuthenticated ? 1 : 0
            rankFooter.alpha = 0

        case .global:
            toggleFooter.text = "<  YOUR SCORES"
            toggleFooter.alpha = 1

            // Doubles as the way into the system leaderboard, because there is only room for
            // two rows under the panel and the player's standing is worth stating outright —
            // especially outside the top twenty, where the list above doesn't show it.
            if case .loaded(let standings) = globalState {
                if let rank = standings.localRank {
                    rankFooter.text = "RANK \(rank) OF \(standings.totalPlayers)  >"
                } else {
                    rankFooter.text = "NOT RANKED YET  >"
                }
                rankFooter.alpha = 1
            } else {
                rankFooter.alpha = 0
            }
        }
    }

    /// How far the list can travel before its last row reaches the bottom of the window.
    private var maxScroll: CGFloat {
        max(0, contentHeight - Self.rowWindowSize.height + Self.listInset * 2)
    }

    // MARK: - Navigation

    func go_home(){
        Entity.cameraTranslationY = 0

        if let scene = SKScene(fileNamed: "StartScene") {
            scene.size = CGSize(width:GameViewController.WIDTH, height:GameViewController.HEIGHT)
            scene.scaleMode = .aspectFill
            transition(to: scene)
        }
    }

    #if DEBUG
    private func setUpDebugOverlay(){
        let overlay = DebugOverlay(in: self, sceneSize: CGSize(width: WIDTH, height: HEIGHT))

        overlay.addAction("Reset Scores") { [weak self] in
            guard let self = self else { return nil }

            guard self.resetArmed else {
                self.resetArmed = true
                return "Tap again to wipe"
            }

            self.resetScores()
            return nil
        }

        debugOverlay = overlay
    }

    /// Deletes every saved score, then rebuilds the local list.
    private func resetScores(){
        ScoreStore.removeAll()
        getScores()
        resetArmed = false

        scrollY = 0
        velocity = 0
        layoutContent()
    }
    #endif

    // MARK: - Input

    func touchDown(atPoint pos : CGPoint) {
        // Checked first, and returns, so tapping a debug button doesn't also start a drag
        // and fling the list.
        #if DEBUG
        if debugOverlay?.handleTouch(at: pos) == true {
            return
        }
        #endif

        // The list and footers live in the panel, which may be scaled down, so they're
        // tested in its coordinates. The home button sits outside it, in the scene's.
        let local = panel.convert(pos, from: self)

        // Footers are checked before the drag starts, and only while visible, so a tap
        // landing there before sign-in has finished can't trigger anything.
        if hits(toggleFooter, local) || hits(rankFooter, local) {
            return
        }

        homeButton.checkPressed(pos: pos)

        isDragging = true
        dragStartY = local.y
        dragStartScroll = scrollY
        dragDistance = 0
        velocity = 0
        previousTouchY = local.y
        currentTouchY = local.y
    }

    func touchMoved(toPoint pos : CGPoint) {
        guard isDragging else { return }

        // In the panel's coordinates, so the list tracks the finger even when scaled.
        let local = panel.convert(pos, from: self)

        previousTouchY = currentTouchY
        currentTouchY = local.y

        // Velocity is the last frame's finger movement, which becomes the fling speed on lift.
        velocity = currentTouchY - previousTouchY

        let delta = local.y - dragStartY
        dragDistance = max(dragDistance, abs(delta))

        scrollY = min(max(dragStartScroll + delta, 0), maxScroll)
        content.position.y = listTopY + scrollY
    }

    func touchUp(atPoint pos : CGPoint) {
        homeButton.unpressed()

        let wasDragging = isDragging
        isDragging = false

        guard wasDragging, dragDistance <= Self.tapSlop else { return }

        // A tap rather than a scroll, so nothing should coast afterwards.
        velocity = 0
        handleTap(at: panel.convert(pos, from: self))
    }

    /// Whether a touch landed on a visible footer, acting on it if so.
    @discardableResult
    private func hits(_ footer: SKLabelNode, _ pos: CGPoint) -> Bool {
        guard footer.alpha > 0 else { return false }

        let target = footer.frame.insetBy(dx: -Self.footerTouchPadding.width,
                                          dy: -Self.footerTouchPadding.height)
        guard target.contains(pos) else { return false }

        if footer === toggleFooter {
            setMode(mode == .local ? .global : .local)
        } else {
            GameCenter.presentLeaderboard()
        }

        return true
    }

    private func handleTap(at pos: CGPoint) {
        // Retry by tapping the panel, which is where the failure message is.
        if mode == .global, case .failed = globalState, scoreOverlay.frame.contains(pos) {
            loadGlobalScores()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        // Ahead of everything else, so the row appears on a fresh install too.
        if mode == .local {
            toggleFooter.alpha = GameCenter.isAuthenticated ? 1 : 0
        }

        coast()
    }

    /// Carries the list on after the finger lifts, shedding speed until it stops.
    private func coast() {
        guard !isDragging, velocity != 0 else { return }

        let decay: CGFloat = 0.75

        if abs(velocity) < decay {
            velocity = 0
            return
        }

        velocity -= decay * (velocity > 0 ? 1 : -1)

        let next = min(max(scrollY + velocity, 0), maxScroll)

        // Hitting either end kills the fling rather than letting it grind there.
        if next == scrollY { velocity = 0 }

        scrollY = next
        content.position.y = listTopY + scrollY
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchDown(atPoint: location(of: t)) }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchMoved(toPoint: location(of: t)) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: location(of: t)) }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { self.touchUp(atPoint: location(of: t)) }
    }
}
