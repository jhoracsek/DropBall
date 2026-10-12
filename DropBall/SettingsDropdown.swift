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

    /// One line to restyle every label here. Others that ship with iOS and suit hand-drawn
    /// art: `MarkerFelt-Wide`, `Noteworthy-Bold`, `Chalkduster`, `ChalkboardSE-Regular`.
    static let fontName = "ChalkboardSE-Bold"

    // MARK: - Metrics

    private static let panelWidth: CGFloat = 380
    private static let rowHeight: CGFloat = 62
    private static let verticalPadding: CGFloat = 16
    private static let horizontalPadding: CGFloat = 26
    private static let gapBelowButton: CGFloat = 12
    private static let cornerRadius: CGFloat = 18

    private static let titleFontSize: CGFloat = 29
    private static let stateFontSize: CGFloat = 25

    private static let panelFill = SKColor(white: 0.05, alpha: 0.78)
    private static let panelStroke = SKColor(white: 1.0, alpha: 0.18)
    private static let separatorColor = SKColor(white: 1.0, alpha: 0.12)
    private static let titleColor = SKColor(white: 1.0, alpha: 0.95)
    private static let onColor = SKColor(red: 0.42, green: 0.86, blue: 0.48, alpha: 1)
    private static let offColor = SKColor(white: 1.0, alpha: 0.38)

    private static let animationDuration: TimeInterval = 0.16

    // MARK: - Options

    /// Sound and music are wired to storage but nothing reads them yet — they become live
    /// once there is audio to switch off.
    private static let options: [(title: String, disabledKey: String)] = [
        ("Rumble", "RumbleOff"),
        ("Sound Effects", "SoundOff"),
        ("Music", "MusicOff")
    ]

    private struct Row {
        let disabledKey: String
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

    private func addPanel() {
        let rect = CGRect(x: -Self.panelWidth/2, y: -panelHeight,
                          width: Self.panelWidth, height: panelHeight)
        let panel = SKShapeNode(path: CGPath(roundedRect: rect,
                                             cornerWidth: Self.cornerRadius,
                                             cornerHeight: Self.cornerRadius,
                                             transform: nil))
        panel.fillColor = Self.panelFill
        panel.strokeColor = Self.panelStroke
        panel.lineWidth = 2
        container.addChild(panel)
    }

    private func addRows() {
        let left = -Self.panelWidth/2 + Self.horizontalPadding
        let right = Self.panelWidth/2 - Self.horizontalPadding

        for (index, option) in Self.options.enumerated() {
            let centerY = -(Self.verticalPadding + Self.rowHeight/2 + CGFloat(index) * Self.rowHeight)
            let isOn = !UserDefaults.standard.bool(forKey: option.disabledKey)

            // Sits behind the text and flashes on tap, so a row reads as pressable without
            // needing a button frame around it.
            let highlightRect = CGRect(x: -Self.panelWidth/2 + 6, y: centerY - Self.rowHeight/2,
                                       width: Self.panelWidth - 12, height: Self.rowHeight)
            let highlight = SKShapeNode(path: CGPath(roundedRect: highlightRect,
                                                     cornerWidth: 12, cornerHeight: 12,
                                                     transform: nil))
            highlight.fillColor = SKColor(white: 1.0, alpha: 1.0)
            highlight.strokeColor = .clear
            highlight.alpha = 0
            container.addChild(highlight)

            let title = label(option.title, size: Self.titleFontSize, color: Self.titleColor)
            title.horizontalAlignmentMode = .left
            title.position = CGPoint(x: left, y: centerY)
            container.addChild(title)

            let state = label(isOn ? "ON" : "OFF",
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

                let separator = SKShapeNode(path: path)
                separator.strokeColor = Self.separatorColor
                separator.lineWidth = 1
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
            toggle(rowAt: index)
            return true
        }

        // Inside the panel but between rows: swallow it so it doesn't fall through.
        return true
    }

    private func toggle(rowAt index: Int) {
        rows[index].isOn.toggle()
        let row = rows[index]

        UserDefaults.standard.set(!row.isOn, forKey: row.disabledKey)

        row.stateLabel.text = row.isOn ? "ON" : "OFF"
        row.stateLabel.fontColor = row.isOn ? Self.onColor : Self.offColor

        row.highlight.removeAllActions()
        row.highlight.alpha = 0.16
        row.highlight.run(SKAction.fadeAlpha(to: 0, duration: 0.22))
    }
}
