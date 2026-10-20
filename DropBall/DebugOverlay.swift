//
//  DebugOverlay.swift
//  DropBall
//

#if DEBUG

import Foundation
import SpriteKit

/// A small panel of on-screen toggles for testing.
///
/// The whole file is inside `#if DEBUG`, so none of it is compiled into a release build and
/// there is no way for it to reach the App Store. Built from shape and label nodes rather
/// than SKButton on purpose: it needs no art, and looking nothing like the game's own
/// buttons makes it hard to mistake for one in a screenshot.
final class DebugOverlay {

    /// Serves both kinds of button. `isOn` is nil for a one-shot action, non-nil for a
    /// toggle — the only difference is whether the state is folded into the label and the
    /// fill colour.
    private final class DebugButton: SKShapeNode {
        private let title: String
        private let label = SKLabelNode(fontNamed: "Menlo-Bold")

        /// Receives the button's state after the tap (nil for an action button) and returns
        /// a replacement label, or nil to keep the current one. The return lets a
        /// destructive action ask for confirmation on a second tap.
        private let onTap: (Bool?) -> String?

        private(set) var isOn: Bool?
        private var overrideTitle: String?

        init(title: String,
             isOn: Bool?,
             size: CGSize,
             onTap: @escaping (Bool?) -> String?) {
            self.title = title
            self.isOn = isOn
            self.onTap = onTap
            super.init()

            path = CGPath(roundedRect: CGRect(x: -size.width/2, y: -size.height/2,
                                              width: size.width, height: size.height),
                          cornerWidth: 8, cornerHeight: 8, transform: nil)
            strokeColor = SKColor.white.withAlphaComponent(0.55)
            lineWidth = 2

            label.fontSize = 22
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            addChild(label)

            refresh()
        }

        required init?(coder: NSCoder) {
            fatalError("DebugOverlay is created in code only")
        }

        func tapped() {
            if isOn != nil {
                isOn?.toggle()
            }
            if let replacement = onTap(isOn) {
                overrideTitle = replacement
            }
            refresh()
        }

        private func refresh() {
            if let overrideTitle = overrideTitle {
                label.text = overrideTitle
            } else if let isOn = isOn {
                label.text = "\(title): \(isOn ? "ON" : "OFF")"
            } else {
                label.text = title
            }

            if let isOn = isOn {
                fillColor = isOn
                    ? SKColor(red: 0.10, green: 0.50, blue: 0.22, alpha: 0.85)
                    : SKColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.75)
            } else {
                // Actions read as neutral until tapped, so they don't look like state.
                fillColor = SKColor(red: 0.26, green: 0.14, blue: 0.14, alpha: 0.85)
            }
        }
    }

    private static let buttonSize = CGSize(width: 230, height: 46)
    private static let buttonSpacing: CGFloat = 54

    private let container = SKNode()
    private var buttons: [DebugButton] = []

    /// - Parameters:
    ///   - target: the scene to attach to.
    ///   - sceneSize: used to pin the panel to the top-left, clear of the pause button.
    init(in target: SKNode, sceneSize: CGSize) {
        // Far above everything else in the scene so it is never occluded by the lose
        // overlay or the pause text.
        container.zPosition = 10_000
        container.position = CGPoint(x: -sceneSize.width/2 + Self.buttonSize.width/2 + 24,
                                     y: sceneSize.height/2 - 70)
        target.addChild(container)
    }

    /// Adds a toggle below the previous one. `onChange` fires only on an actual tap, not
    /// when the initial value is set.
    func addToggle(_ title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        add(DebugButton(title: title, isOn: isOn, size: Self.buttonSize) { newState in
            onChange(newState ?? false)
            return nil
        })
    }

    /// Adds a one-shot action button.
    ///
    /// - Parameter handler: performs the action and optionally returns new label text, so a
    ///   destructive action can ask for confirmation on a second tap.
    func addAction(_ title: String, handler: @escaping () -> String?) {
        add(DebugButton(title: title, isOn: nil, size: Self.buttonSize) { _ in handler() })
    }

    private func add(_ button: DebugButton) {
        button.position = CGPoint(x: 0, y: -CGFloat(buttons.count) * Self.buttonSpacing)
        container.addChild(button)
        buttons.append(button)
    }

    /// Routes a touch to the panel.
    ///
    /// - Returns: true if a toggle was hit, so the scene can swallow the touch rather than
    ///   treating it as gameplay input.
    func handleTouch(at scenePoint: CGPoint) -> Bool {
        // The container is only ever translated, never rotated or scaled, so converting
        // into its space is a plain subtraction.
        let local = CGPoint(x: scenePoint.x - container.position.x,
                            y: scenePoint.y - container.position.y)

        for button in buttons where button.frame.contains(local) {
            button.tapped()
            return true
        }
        return false
    }
}

#endif
