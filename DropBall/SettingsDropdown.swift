//
//  SettingsDropdown.swift
//  DropBall
//

import Foundation
import SpriteKit

/// The settings menu, as a panel that drops out from under the gear button instead of a
/// separate scene.
///
/// Each option is stored as an *off* flag rather than an on flag, matching the `RumbleOff`
/// key that already shipped. Keeping that convention means existing players don't lose the
/// setting they'd chosen.
final class SettingsDropdown {

    /// Pixel Operator 8 by Jayvee Enaguas, bundled with the app (CC0). This is the font's
    /// PostScript name, which is what iOS matches on — not the filename, though the two
    /// happen to agree here. Registered via UIAppFonts in Info.plist.
    static let fontName = "PixelOperator8"

    /// The font is drawn on an 8-pixel grid (800 units per em, 100 per pixel), so it only
    /// lands on whole pixels at sizes that are multiples of 8. Anything else puts glyph
    /// edges on fractions of a pixel and the lettering goes soft and uneven.
    private static let fontGrid: CGFloat = 8

    // MARK: - Metrics

    /// Size of one "pixel" in the panel's chunky edges, in scene units. Every other metric
    /// below is a whole multiple of this so the whole panel sits on one grid.
    private static let pixelSize: CGFloat = 6

    /// Corner radius measured in pixels rather than points. 4 gives a visible two-step
    /// stair; 2 is a subtle nick; 0 is a hard square corner.
    private static let cornerPixels: Int = 4

    private static let panelWidth: CGFloat = 420        // 70 px
    private static let rowHeight: CGFloat = 60          // 10 px
    private static let verticalPadding: CGFloat = 18    //  3 px
    private static let horizontalPadding: CGFloat = 24  //  4 px
    private static let gapBelowButton: CGFloat = 12     //  2 px

    // Both multiples of fontGrid. See the note on fontName. Pixel Operator runs a lot
    // wider than the font it replaced, so these are smaller than you might expect —
    // "Sound Effects" at 32 overflowed the panel by 63 points.
    private static let titleFontSize: CGFloat = 24
    private static let stateFontSize: CGFloat = 24

    private static let panelFill = SKColor(white: 0.16, alpha: 0.72)
    private static let panelStroke = SKColor(white: 1.0, alpha: 0.22)
    private static let separatorColor = SKColor(white: 1.0, alpha: 0.12)
    private static let titleColor = SKColor(white: 1.0, alpha: 0.95)
    private static let onColor = SKColor(red: 0.42, green: 0.86, blue: 0.48, alpha: 1)
    private static let offColor = SKColor(white: 1.0, alpha: 0.38)

    private static let animationDuration: TimeInterval = 0.16

    // MARK: - Options

    /// Music is wired to storage but nothing reads it yet — it becomes live once there is
    /// a track to switch off.
    ///
    /// A nil key marks a row that performs an action instead of holding a setting; those
    /// show a chevron rather than ON/OFF.
    private static let options: [(title: String, disabledKey: String?)] = [
        ("Rumble", "RumbleOff"),
        ("Sound Effects", "SoundOff"),
        ("Music", "MusicOff"),
        ("Credits", nil)
    ]

    /// Called when the Credits row is tapped. Set by the scene that owns the dropdown, so
    /// the dropdown doesn't need to know how scenes are presented.
    var onShowCredits: (() -> Void)?

    /// Called after a toggle is flipped and written, with the UserDefaults key and the new
    /// enabled state. Lets anything that needs to react immediately — rather than at its
    /// next natural checkpoint — do so, without the dropdown knowing what it's talking to.
    var onSettingChanged: ((String, Bool) -> Void)?

    private struct Row {
        let disabledKey: String?
        let stateLabel: SKLabelNode
        let highlight: SKShapeNode
        let centerY: CGFloat
        var isOn: Bool
    }

    // MARK: - State

    /// Scaled and faded as a whole, and positioned at the panel's *top* edge so the panel
    /// can be laid out downwards from there.
    private let container = SKNode()
    private var rows: [Row] = []

    private(set) var isExpanded = false

    private let panelHeight: CGFloat

    /// Where the container sits when the panel is fully open. The single source of truth
    /// for its position — every animation targets this absolutely rather than nudging the
    /// current position, so repeated opening and closing cannot accumulate drift.
    private let restingPosition: CGPoint

    /// How far above its resting place the panel starts and ends, for the slide.
    private static let slideOffset: CGFloat = 14

    // MARK: - Setup

    /// - Parameters:
    ///   - button: the gear. Its sprite is measured directly, so the panel stays anchored
    ///     to it even if the button is moved or rescaled.
    ///   - parent: the scene.
    init(below button: SKButton, in parent: SKNode) {
        let gear = button.getSpriteNode()[0]
        panelHeight = CGFloat(Self.options.count) * Self.rowHeight + 2 * Self.verticalPadding

        let right = gear.position.x + gear.size.width/2
        let top = gear.position.y - gear.size.height/2 - Self.gapBelowButton

        restingPosition = CGPoint(x: right - Self.panelWidth/2, y: top)

        container.name = "settingsDropdown"
        container.position = restingPosition
        container.zPosition = 100
        container.alpha = 0
        container.isHidden = true
        parent.addChild(container)

        addPanel()
        addRows()
    }

    /// A rounded rectangle whose corners are a staircase of square blocks instead of a
    /// smooth arc, so the panel reads as pixel art next to the game's sprites.
    ///
    /// Turning antialiasing off alone wouldn't do it — that gives a jagged *curve*, not
    /// chunky blocks. The geometry itself has to be quantised. The corner here is a quarter
    /// circle snapped to the grid: a block is kept when its centre falls inside the circle.
    ///
    /// Returned anchored at top-centre, matching how the container is positioned: the shape
    /// spans x of ±width/2 and y from 0 down to -height.
    private static func pixelRoundedRect(width: CGFloat,
                                         height: CGFloat,
                                         cornerPixels: Int) -> CGPath {
        let pixel = pixelSize
        let cols = max(Int((width / pixel).rounded()), 1)
        let rows = max(Int((height / pixel).rounded()), 1)
        let radius = max(min(cornerPixels, min(cols, rows) / 2), 0)

        // How many blocks are cut from the start of each row inside the corner square.
        var corner = [Int](repeating: 0, count: radius)
        for y in 0..<radius {
            let dy = CGFloat(y) + 0.5 - CGFloat(radius)
            var cut = 0
            for x in 0..<radius {
                let dx = CGFloat(x) + 0.5 - CGFloat(radius)
                if dx*dx + dy*dy > CGFloat(radius * radius) { cut += 1 }
            }
            corner[y] = cut
        }

        func cut(_ row: Int) -> Int {
            guard radius > 0 else { return 0 }
            if row < radius { return corner[row] }
            if row >= rows - radius { return corner[rows - 1 - row] }
            return 0
        }

        let gridWidth = CGFloat(cols) * pixel
        func point(_ col: Int, _ row: Int) -> CGPoint {
            CGPoint(x: -gridWidth/2 + CGFloat(col) * pixel, y: -CGFloat(row) * pixel)
        }

        // Walked as one closed polygon rather than stacked rectangles, so it fills the same
        // way no matter which winding rule the renderer applies.
        let path = CGMutablePath()
        path.move(to: point(cut(0), 0))

        for row in 0..<rows {
            let right = cols - cut(row)
            path.addLine(to: point(right, row))       // across, into this row
            path.addLine(to: point(right, row + 1))   // down its right edge
        }
        for row in stride(from: rows - 1, through: 0, by: -1) {
            let left = cut(row)
            path.addLine(to: point(left, row + 1))    // back across the bottom
            path.addLine(to: point(left, row))        // up its left edge
        }
        path.closeSubpath()

        return path
    }

    private func addPanel() {
        let panel = SKShapeNode(path: Self.pixelRoundedRect(width: Self.panelWidth,
                                                            height: panelHeight,
                                                            cornerPixels: Self.cornerPixels))
        panel.fillColor = Self.panelFill
        panel.strokeColor = Self.panelStroke
        panel.lineWidth = 3

        // Without this the stepped corners get smoothed back over and the whole point
        // of the quantised path is lost.
        panel.isAntialiased = false

        container.addChild(panel)
    }

    private func addRows() {
        let left = -Self.panelWidth/2 + Self.horizontalPadding
        let right = Self.panelWidth/2 - Self.horizontalPadding

        for (index, option) in Self.options.enumerated() {
            let centerY = -(Self.verticalPadding + Self.rowHeight/2 + CGFloat(index) * Self.rowHeight)

            // Action rows have no stored setting, so they read as "on" only in the sense
            // that their chevron is drawn in the same bright colour as an enabled toggle.
            let isOn = option.disabledKey.map { !UserDefaults.standard.bool(forKey: $0) } ?? true

            // Sits behind the text and flashes on tap, so a row reads as pressable without
            // needing a button frame around it. Inset by one pixel so it tucks inside the
            // panel's own stepped border.
            let highlight = SKShapeNode(path: Self.pixelRoundedRect(width: Self.panelWidth - 2 * Self.pixelSize,
                                                                    height: Self.rowHeight,
                                                                    cornerPixels: 2))
            highlight.position = CGPoint(x: 0, y: centerY + Self.rowHeight/2)
            highlight.fillColor = SKColor(white: 1.0, alpha: 1.0)
            highlight.strokeColor = .clear
            highlight.isAntialiased = false
            highlight.alpha = 0
            container.addChild(highlight)

            let title = label(option.title, size: Self.titleFontSize, color: Self.titleColor)
            title.horizontalAlignmentMode = .left
            title.position = CGPoint(x: left, y: centerY)
            container.addChild(title)

            let isAction = option.disabledKey == nil
            let state = label(isAction ? ">" : (isOn ? "ON" : "OFF"),
                              size: Self.stateFontSize,
                              color: isOn ? Self.onColor : Self.offColor)
            state.horizontalAlignmentMode = .right
            state.position = CGPoint(x: right, y: centerY)
            container.addChild(state)

            if index > 0 {
                let y = centerY + Self.rowHeight/2
                let path = CGMutablePath()
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))

                // One pixel thick and unsmoothed, so it matches the panel's grid rather
                // than reading as a hairline from a different design language.
                let separator = SKShapeNode(path: path)
                separator.strokeColor = Self.separatorColor
                separator.lineWidth = Self.pixelSize
                separator.isAntialiased = false
                container.addChild(separator)
            }

            rows.append(Row(disabledKey: option.disabledKey,
                            stateLabel: state,
                            highlight: highlight,
                            centerY: centerY,
                            isOn: isOn))
        }
    }

    private func label(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: Self.fontName)
        node.text = text
        node.fontSize = size
        node.fontColor = color
        node.verticalAlignmentMode = .center
        return node
    }

    // MARK: - Open and close

    func toggleExpanded() {
        setExpanded(!isExpanded)
    }

    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded

        container.removeAllActions()

        // Both directions move to an absolute point rather than by a relative amount.
        // A relative close that isn't matched by a relative open leaves the container
        // permanently displaced, and because it is anchored at the panel's top edge the
        // panel appears to grow upward a little more on every cycle.
        let raised = CGPoint(x: restingPosition.x, y: restingPosition.y + Self.slideOffset)

        // Fading and sliding rather than unrolling the panel's height: scaling the
        // container would squash the text on the way in, which looks cheap.
        if expanded {
            container.isHidden = false

            // Snap to a known start, so an interrupted close can't offset the open either.
            container.position = raised
            container.alpha = 0

            let slide = SKAction.move(to: restingPosition, duration: Self.animationDuration)
            slide.timingMode = .easeOut
            let fade = SKAction.fadeAlpha(to: 1, duration: Self.animationDuration)
            container.run(SKAction.group([slide, fade]))
        } else {
            let slide = SKAction.move(to: raised, duration: Self.animationDuration)
            slide.timingMode = .easeIn
            let fade = SKAction.fadeAlpha(to: 0, duration: Self.animationDuration)

            container.run(SKAction.sequence([
                SKAction.group([slide, fade]),
                SKAction.run { [weak self] in
                    guard let self = self else { return }
                    self.container.isHidden = true
                    self.container.position = self.restingPosition
                }
            ]))
        }
    }

    // MARK: - Input

    /// Routes a touch to the dropdown.
    ///
    /// - Returns: true if the dropdown dealt with it, so the scene can ignore it. A tap
    ///   outside an open panel closes it *and* is swallowed, so dismissing the menu can't
    ///   also start a game by accident.
    func handleTouch(at scenePoint: CGPoint) -> Bool {
        guard isExpanded else { return false }

        let local = CGPoint(x: scenePoint.x - container.position.x,
                            y: scenePoint.y - container.position.y)

        let insidePanel = abs(local.x) <= Self.panelWidth/2
            && local.y <= 0 && local.y >= -panelHeight

        guard insidePanel else {
            setExpanded(false)
            return true
        }

        for index in rows.indices where abs(local.y - rows[index].centerY) <= Self.rowHeight/2 {
            activate(rowAt: index)
            return true
        }

        // Inside the panel but between rows: swallow it so it doesn't fall through.
        return true
    }

    private func activate(rowAt index: Int) {
        let row = rows[index]

        flash(row)

        // An action row has no setting to flip; it just runs and closes the menu so the
        // panel isn't left hanging over whatever it navigated to.
        guard let key = row.disabledKey else {
            setExpanded(false)
            onShowCredits?()
            return
        }

        rows[index].isOn.toggle()
        let isOn = rows[index].isOn

        UserDefaults.standard.set(!isOn, forKey: key)

        row.stateLabel.text = isOn ? "ON" : "OFF"
        row.stateLabel.fontColor = isOn ? Self.onColor : Self.offColor

        onSettingChanged?(key, isOn)
    }

    private func flash(_ row: Row) {
        row.highlight.removeAllActions()
        row.highlight.alpha = 0.16
        row.highlight.run(SKAction.fadeAlpha(to: 0, duration: 0.22))
    }
}
