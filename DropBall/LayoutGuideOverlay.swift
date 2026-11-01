//
//  LayoutGuideOverlay.swift
//  DropBall
//

#if DEBUG

import UIKit

/// Debug-only guides showing how the scene fits the screen it's on.
///
/// The scene is a fixed size, drawn to fill the screen while keeping its shape, so on a
/// screen of a different shape some of it is cropped. This draws:
/// - the scene's outline, with a square in each of its corners — a square that's cut off,
///   or missing, marks scene content that isn't visible on this screen;
/// - the safe area — the region clear of the Dynamic Island, the rounded corners and the
///   home indicator, which is where anything that has to be seen or tapped belongs;
/// - a readout of the sizes involved and how much is cropped from each side.
///
/// Redrawn whenever the view's size or safe area changes, so it stays correct if the
/// window is resized while the app runs.
final class LayoutGuideOverlay: UIView {

    /// Size of each corner square, in scene points.
    private static let cornerSize: CGFloat = 60

    private static let sceneColor = UIColor.systemPink
    private static let safeAreaColor = UIColor.systemGreen

    /// The scene's size, set by SceneRenderer whenever the scene changes. The anchor point
    /// doesn't matter here: it moves the scene's origin, not where its edges land.
    var sceneSize: CGSize = .zero {
        didSet { if sceneSize != oldValue { refresh() } }
    }

    private let readout = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw

        readout.numberOfLines = 0
        readout.font = .monospacedSystemFont(ofSize: 10, weight: .semibold)
        readout.textColor = .white
        readout.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        readout.translatesAutoresizingMaskIntoConstraints = false
        addSubview(readout)
        NSLayoutConstraint.activate([
            readout.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 8),
            // Raised clear of SceneRenderer's FPS label in the bottom-right corner.
            readout.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        refresh()
    }

    private func refresh() {
        updateReadout()
        setNeedsDisplay()
    }

    // MARK: - Geometry

    /// Screen points per scene point. The same aspect-fill scale SceneRenderer draws with.
    private var scale: CGFloat {
        guard sceneSize.width > 0, sceneSize.height > 0 else { return 0 }
        return max(bounds.width / sceneSize.width, bounds.height / sceneSize.height)
    }

    /// Where the whole scene lands in this view's coordinates. Larger than the view on
    /// whichever axis is being cropped.
    private var sceneFrame: CGRect {
        let width = sceneSize.width * scale
        let height = sceneSize.height * scale
        return CGRect(x: (bounds.width - width) / 2,
                      y: (bounds.height - height) / 2,
                      width: width,
                      height: height)
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard scale > 0 else { return }

        let frame = sceneFrame

        // Scene outline. Dashed, so it reads as a guide rather than part of the game.
        let outline = UIBezierPath(rect: frame.insetBy(dx: 1, dy: 1))
        outline.lineWidth = 2
        outline.setLineDash([8, 6], count: 2, phase: 0)
        Self.sceneColor.setStroke()
        outline.stroke()

        // Corner squares, flush with the scene's corners.
        let side = Self.cornerSize * scale
        let corners = [
            CGPoint(x: frame.minX, y: frame.minY),
            CGPoint(x: frame.maxX - side, y: frame.minY),
            CGPoint(x: frame.minX, y: frame.maxY - side),
            CGPoint(x: frame.maxX - side, y: frame.maxY - side)
        ]
        Self.sceneColor.withAlphaComponent(0.6).setFill()
        for origin in corners {
            UIBezierPath(rect: CGRect(origin: origin, size: CGSize(width: side, height: side))).fill()
        }

        // Safe area.
        let safeArea = UIBezierPath(rect: bounds.inset(by: safeAreaInsets).insetBy(dx: 1, dy: 1))
        safeArea.lineWidth = 2
        Self.safeAreaColor.setStroke()
        safeArea.stroke()
    }

    // MARK: - Readout

    private func updateReadout() {
        guard scale > 0 else {
            readout.text = nil
            return
        }

        let frame = sceneFrame

        // How much of the scene falls off each axis, in scene points, split evenly between
        // the two sides because the scene is centred.
        let cropX = max(0, (frame.width - bounds.width) / 2) / scale
        let cropY = max(0, (frame.height - bounds.height) / 2) / scale

        let insets = safeAreaInsets
        readout.text = """
         screen \(format(bounds.width)) × \(format(bounds.height)) pt \
        (ratio \(format(bounds.height / bounds.width, decimals: 3))) 
         scene  \(format(sceneSize.width)) × \(format(sceneSize.height)) \
        (ratio \(format(sceneSize.height / sceneSize.width, decimals: 3))) 
         scale  \(format(scale, decimals: 3)) screen pt per scene pt 
         crop   \(format(cropX)) left/right, \(format(cropY)) top/bottom (scene pt) 
         safe   top \(format(insets.top)) bottom \(format(insets.bottom)) \
        left \(format(insets.left)) right \(format(insets.right)) (screen pt) 
        """
    }

    private func format(_ value: CGFloat, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", value)
    }
}

#endif
