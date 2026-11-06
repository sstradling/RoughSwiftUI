//
//  SeededNoise.swift
//  Sketchy
//
//  1-D value noise shared by opacity profiles and watercolor offsets.
//  The lattice hash matches `VariableStrokeWidth` so a seed stays stable.
//

import CoreGraphics
import Foundation

/// Deterministic 1-D value noise. The same seed and position always match.
enum SeededNoise {
    /// Smooth value in `[0, 1)` at `x`. `x` is in noise cycles, not stroke `t`.
    static func unit(at x: Float, seed: UInt64) -> Float {
        let i = floor(x)
        let fraction = x - i
        let fade = fraction * fraction * (3 - 2 * fraction)
        let left = hash(Int64(i), seed: seed)
        let right = hash(Int64(i) + 1, seed: seed)
        return left + (right - left) * fade
    }

    /// Smooth value in `[-1, 1]` at `x`.
    static func signed(at x: CGFloat, seed: UInt64) -> CGFloat {
        CGFloat(unit(at: Float(x), seed: seed) * 2 - 1)
    }

    /// Value noise that repeats every `period` lattice cells.
    ///
    /// `period` is at least 1. `unitPeriodic(0)` equals `unitPeriodic(period)`,
    /// so a closed stroke can join without a step when `x` runs `0...period`.
    static func unitPeriodic(at x: Float, period: Int, seed: UInt64) -> Float {
        let period = max(1, period)
        let span = Float(period)
        var wrapped = x.truncatingRemainder(dividingBy: span)
        if wrapped < 0 { wrapped += span }
        let i = floor(wrapped)
        let fraction = wrapped - i
        let fade = fraction * fraction * (3 - 2 * fraction)
        let leftIndex = Int(i) % period
        let rightIndex = (leftIndex + 1) % period
        let left = hash(Int64(leftIndex), seed: seed)
        let right = hash(Int64(rightIndex), seed: seed)
        return left + (right - left) * fade
    }

    /// Splitmix mix of `(seed, lattice index)` mapped into `[0, 1)`.
    private static func hash(_ index: Int64, seed: UInt64) -> Float {
        var z = seed &+ UInt64(bitPattern: index) &* 0x9E3779B97F4A7C15
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        z = z ^ (z &>> 31)
        return Float(z >> 40) / Float(1 << 24)
    }
}

/// Pulls `value` toward `join` within `window` of either end of a closed stroke.
///
/// `t` is 0...1. Open strokes should skip this. The blend keeps a loop from
/// showing a step where the first sample meets the last.
func seamBlend(value: CGFloat, toward join: CGFloat, t: CGFloat, window: CGFloat) -> CGFloat {
    guard window > 0 else { return value }
    let edge = min(max(0, t), max(0, 1 - t))
    guard edge < window else { return value }
    let mix = edge / window
    let smooth = mix * mix * (3 - 2 * mix)
    return join + (value - join) * smooth
}
