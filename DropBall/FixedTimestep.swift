//
//  FixedTimestep.swift
//  DropBall
//

import Foundation

/// Converts real elapsed time into a number of fixed 1/60 s game steps.
///
/// All of the game's speeds and accelerations are tuned "per frame at 60 fps". Running the
/// existing per-frame logic a whole number of times per rendered frame keeps that tuning
/// intact, while catching up when the system skips a frame (two steps instead of one) so
/// the game no longer visibly stalls. It also keeps the speed correct on 120 Hz displays.
struct FixedTimestep {
    static let step: TimeInterval = 1.0 / 60.0

    /// Upper bound on catch-up steps per frame, so returning from the background or a long
    /// stall doesn't fast-forward the game.
    private let maxSteps = 4

    private var lastTime: TimeInterval?
    private var accumulator: TimeInterval = 0

    /// Returns how many game steps to run for the frame rendered at `currentTime`.
    mutating func steps(at currentTime: TimeInterval) -> Int {
        guard let last = lastTime else {
            lastTime = currentTime
            return 1
        }
        lastTime = currentTime
        accumulator += min(max(currentTime - last, 0), Self.step * Double(maxSteps))

        var count = Int(accumulator / Self.step)
        // Frame timestamps jitter slightly; treat a frame that's almost a full step as one,
        // otherwise a normal 60 Hz frame could occasionally run zero steps and stutter.
        if accumulator - Double(count) * Self.step >= Self.step * 0.7 {
            count += 1
        }
        count = min(count, maxSteps)
        accumulator = max(accumulator - Double(count) * Self.step, -Self.step * 0.3)
        return count
    }
}
