//
//  Haptics.swift
//  DropBall
//

import Foundation
import UIKit

/// Thin wrapper over UIKit's impact feedback, so callers don't each have to think about
/// the rumble setting or about keeping the Taptic Engine warm.
///
/// Deliberately not `AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)`, which is what
/// the lose screen uses: that's a single heavy buzz of fixed length, fine as a one-off for
/// dying but far too blunt to fire on every bounce.
enum Haptics {

    /// Softest of the impact styles, and the only one gentle enough to fire once or twice
    /// a second without becoming irritating.
    private static let generator = UIImpactFeedbackGenerator(style: .soft)

    /// Range the bounce strength is mapped into. Kept well below full intensity — this is
    /// meant to be felt rather than noticed.
    private static let minIntensity: CGFloat = 0.25
    private static let maxIntensity: CGFloat = 0.55

    /// Read live rather than cached, so toggling Rumble takes effect straight away.
    static var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "RumbleOff")
    }

    /// Spins up the Taptic Engine ahead of time. Without this the first impact of a run
    /// arrives noticeably late, because the engine is powered down when idle.
    static func prepare() {
        guard isEnabled else { return }
        generator.prepare()
    }

    /// - Parameter strength: 0 for the gentlest landing, 1 for the hardest.
    static func impact(strength: CGFloat) {
        guard isEnabled else { return }

        let clamped = min(max(strength, 0), 1)
        let intensity = minIntensity + (maxIntensity - minIntensity) * clamped
        generator.impactOccurred(intensity: intensity)

        // Re-arm straight away so the next bounce is just as prompt.
        generator.prepare()
    }
}
