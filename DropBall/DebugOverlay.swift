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

    private final class ToggleButton: SKShapeNode {
        private let title: String
        private let onChange: (Bool) -> Void
        private let label = SKLabelNode(fontNamed: "Menlo-Bold")

        private(set) var isOn: Bool

        init(title: String,
             isOn: Bool,
             size: CGSize,
             onChange: @escaping (Bool) -> Void) {
            self.title = title
            self.isOn = isOn
            self.onChange = onChange
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

        func toggle() {
            isOn.toggle()
            refresh()
            onChange(isOn)
        }

        private func refresh() {
            label.text = "\(title): \(isOn ? "ON" : "OFF")"
            fillColor = isOn
                ? SKColor(red: 0.10, green: 0.50, blue: 0.22, alpha: 0.85)
                : SKColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 0.75)
        }
    }

    private static let buttonSize = CGSize(width: 230, height: 46)
    private static let buttonSpacing: CGFloat = 54

    private let container = SKNode()
    private var buttons: [ToggleButton] = []

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
        let button = ToggleButton(title: title,
                                  isOn: isOn,
                                  size: Self.buttonSize,
                                  onChange: onChange)
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
            button.toggle()
            return true
        }
        return false
    }
}

#endif
