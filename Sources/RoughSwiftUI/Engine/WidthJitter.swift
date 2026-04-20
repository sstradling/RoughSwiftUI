//
//  WidthJitter.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Along-stroke width modulation. Multiplies the per-sample stroke width
//  by a deterministic noise function indexed by accumulated arc length,
//  producing the subtle wobble that makes constant-width hand-drawn
//  lines feel hand-drawn rather than mechanical.
//

import Foundation
import CoreGraphics

/// Describes deterministic along-stroke width modulation.
///
/// `WidthJitter` is consumed by both renderers:
/// - **SwiftUI** (`StrokeToFillConverter`): multiplies the per-sample
///   ribbon thickness before outline construction, so the resulting
///   filled outline visibly bulges and narrows along the path.
/// - **Metal** (`RibbonMeshBuilder`): same multiplication applied at
///   vertex generation time, producing identical geometry.
///
/// The noise function is **deterministic** given a `seed` and an
/// arc-length coordinate. Two strokes drawn with identical jitter
/// configurations produce pixel-identical wobble; toggling the seed
/// changes the wobble pattern without changing its statistical
/// character. This is important for animation: the same stroke at the
/// same animation step must wobble the same way every frame, otherwise
/// the strokes would shimmer.
public struct WidthJitter: Equatable, Hashable, Sendable {

    /// Maximum fractional deviation from the base width. `0` disables
    /// jitter entirely; `0.3` means the width can swing in
    /// `[0.7, 1.3] × baseWidth` at the noise peaks. Values above `1`
    /// are accepted but produce strokes that visibly collapse to zero
    /// width at troughs (effectively dotted line); the consumer clamps
    /// the final width to a sensible minimum.
    ///
    /// Range: `[0, 1+]`. Default: `0` (no jitter).
    public var amount: CGFloat

    /// Spatial frequency of the noise, in cycles per 100 points of arc
    /// length. `0.05` (the default) gives one wobble cycle every ~2000
    /// points, suitable for long sweeping curves; `0.2` gives one cycle
    /// every ~500 points, suitable for shorter strokes.
    ///
    /// Range: `> 0`. Default: `0.05`.
    public var frequency: CGFloat

    /// Seed for the deterministic random sequence. Two `WidthJitter`
    /// values with identical `amount` and `frequency` but different
    /// `seed` produce visually-distinct wobble patterns; reusing the
    /// same seed produces pixel-identical results.
    ///
    /// Default: `0` (a fixed value chosen so default-configured jitter
    /// is reproducible across runs).
    public var seed: UInt64

    /// Creates a width-jitter descriptor. All defaults are tuned so the
    /// `WidthJitter()` construction is "subtle hand-drawn wobble" and
    /// can be applied with no parameter tweaking.
    public init(
        amount: CGFloat = 0.15,
        frequency: CGFloat = 0.05,
        seed: UInt64 = 0
    ) {
        self.amount = max(0, amount)
        self.frequency = max(0.001, frequency)
        self.seed = seed
    }

    /// Returns the width multiplier at a given arc length along the
    /// stroke. Always in `[1 - amount, 1 + amount]` (modulo the
    /// minimum-width clamp applied by the consumer). The function is a
    /// 1-D value noise indexed by arc length.
    ///
    /// - Parameter arcLength: Distance from the start of the stroke,
    ///   in points. Negative values are clamped to 0.
    /// - Returns: A multiplier in `[1 - amount, 1 + amount]`.
    @inline(__always)
    public func multiplier(at arcLength: CGFloat) -> CGFloat {
        guard amount > 0 else { return 1 }
        let length = max(0, arcLength)
        // Convert arc length into the noise index. `frequency` is
        // cycles per 100 points; multiply by 0.01 so a frequency of
        // 0.05 yields one cycle per 2000 points.
        let index = Float(length * frequency * 0.01)
        let noise = WidthJitter.valueNoise1D(at: index, seed: seed)
        // noise is in [0, 1]; map to [-1, +1] then scale by amount.
        let signed = noise * 2 - 1
        return 1 + CGFloat(signed) * amount
    }

    // MARK: - Deterministic 1-D value noise

    /// Cheap, allocation-free 1-D value noise. Hashes integer lattice
    /// points to pseudo-random floats in `[0, 1]` and bilinearly
    /// interpolates with a smoothstep falloff. Same construction as the
    /// 2-D noise used by the Metal grain shaders, kept in pure CPU code
    /// here so callers without a GPU can use it.
    @inline(__always)
    static func valueNoise1D(at x: Float, seed: UInt64) -> Float {
        let i = floor(x)
        let f = x - i
        let u = f * f * (3 - 2 * f)   // smoothstep

        let a = hash(Int64(i), seed: seed)
        let b = hash(Int64(i) + 1, seed: seed)
        return a + (b - a) * u
    }

    /// Fast hash from `(lattice index, seed)` to a float in `[0, 1]`.
    /// Uses splitmix64 mixing on a packed `(seed, index)` 128-bit pair
    /// reduced to 64 bits, then maps the result into `[0, 1]`.
    @inline(__always)
    static func hash(_ index: Int64, seed: UInt64) -> Float {
        var z = seed &+ UInt64(bitPattern: index) &* 0x9E3779B97F4A7C15
        z = (z ^ (z &>> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z &>> 27)) &* 0x94D049BB133111EB
        z = z ^ (z &>> 31)
        // Map the upper 24 bits to [0, 1] for float precision.
        return Float(z >> 40) / Float(1 << 24)
    }
}
