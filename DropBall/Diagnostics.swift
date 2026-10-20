//
//  Diagnostics.swift
//  DropBall
//

#if DEBUG

import Foundation
import SpriteKit

/// Periodic logging to track down a crash that leaves no error behind.
///
/// A silent termination on device usually means the OS killed the process rather than the
/// app trapping — most often for memory. Those kills produce no crash report, but anything
/// already written to the log survives, so the last line printed before the app vanishes
/// tells you what state it died in.
///
/// Debug-only, and off unless `isEnabled` is set.
enum Diagnostics {

    /// Flip to true to start logging. Left off so a normal debug run isn't noisy.
    ///
    /// Kept around rather than deleted: this is what caught the emitter crash, and the
    /// memory/node trend is the fastest way to characterise anything similar.
    static var isEnabled = false

    /// Seconds between samples. One a second is enough to see a trend without flooding.
    private static let interval: TimeInterval = 1.0

    private static var lastSample: TimeInterval = 0
    private static var firstFootprint: Double?
    private static var peakNodes = 0

    /// Resident memory actually charged to the app, in megabytes. This is the figure the
    /// OS uses when deciding what to kill, so it's the one that matters here.
    static func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.phys_footprint) / 1024.0 / 1024.0
    }

    /// Total nodes in the tree, not just direct children — a leak often hides a level down.
    static func nodeCount(_ node: SKNode) -> Int {
        var total = 1
        for child in node.children {
            total += nodeCount(child)
        }
        return total
    }

    /// Call once per frame from the scene's update. Throttles itself.
    ///
    /// - Parameter extra: scene-specific counters worth seeing alongside the totals.
    static func sample(_ scene: SKScene, time: TimeInterval, extra: @autoclosure () -> String) {
        guard isEnabled else { return }
        guard time - lastSample >= interval else { return }
        lastSample = time

        let footprint = footprintMB()
        let nodes = nodeCount(scene)
        peakNodes = max(peakNodes, nodes)

        if firstFootprint == nil { firstFootprint = footprint }
        let growth = footprint - (firstFootprint ?? footprint)

        print(String(format: "[diag] t=%.0fs mem=%.1fMB (%+.1f) nodes=%d peak=%d %@",
                     time, footprint, growth, nodes, peakNodes, extra()))
    }

    /// Call when a scene is torn down, to confirm the previous one was actually released.
    static func reset() {
        lastSample = 0
        firstFootprint = nil
        peakNodes = 0
    }
}

#endif
