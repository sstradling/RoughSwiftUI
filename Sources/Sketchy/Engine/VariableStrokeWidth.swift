//
//  VariableStrokeWidth.swift
//  Sketchy
//
//  Seeded along-stroke width for the marker brush.
//  The lattice hash is the splitmix mix from the earlier width-jitter draft,
//  indexed by normalized position so it lives on `ThicknessProfile`.
//

import CoreGraphics
import Foundation

/// Width multiplier along one open stroke.
///
/// Values are fractions of `strokeWidth`. `ThicknessProfile` already tapers
/// and interpolates pressure. This type adds a seeded wobble and keeps the
/// result inside a minimum and maximum.
///
/// `BrushProfile.marker()` with the default arguments is the uniform marker.
/// A non-zero `variation`, an explicit bound, a taper, or a pressure curve
/// builds `ThicknessProfile.variable`.
///
/// Closed contours still drop this profile. `StrokeToFillConverter` uses an
/// even width there so the join does not seam.
public struct VariableStrokeWidth: Equatable, Hashable, Sendable {
    /// Fraction of `[minimum, maximum]` used by the noise, centered on the span.
    /// `1` uses the whole span. `0` leaves the body at multiplier 1.
    public private(set) var amount: CGFloat

    /// Lowest body multiplier. Taper may go below this, down to 0.
    public private(set) var minimum: CGFloat

    /// Highest multiplier. Noise, pressure, and taper never exceed it.
    public private(set) var maximum: CGFloat

    /// Length of the start taper as a fraction of the stroke, 0...1.
    public private(set) var taperStart: CGFloat

    /// Length of the end taper as a fraction of the stroke, 0...1.
    public private(set) var taperEnd: CGFloat

    /// Pressure multipliers, interpolated the same way as `ThicknessProfile.pressure`.
    /// Empty means no pressure shaping.
    public private(set) var pressure: [CGFloat]

    /// Repeats the same wobble. Any `UInt64` is valid, including 0.
    public private(set) var seed: UInt64

    /// Noise cycles from the start of the stroke to the end. Clamped to at least 0.5.
    public private(set) var frequency: CGFloat

    /// Creates a width profile.
    ///
    /// - Parameters:
    ///   - variation: Wander as a fraction of `strokeWidth` when `minimum` and
    ///     `maximum` are omitted. `0.35` keeps the noisy body in `[0.65, 1.35]`.
    ///     Clamped to `0...1`. Default 0.
    ///   - minimum: Lower body multiplier. Omitted with `variation` becomes
    ///     `1 - variation`. When both bounds are set and `variation` is 0, the
    ///     noise uses the whole span.
    ///   - maximum: Upper multiplier. Omitted with `variation` becomes
    ///     `1 + variation`.
    ///   - taperStart: How far along the stroke the start thins to a point. Default 0.
    ///   - taperEnd: How far from the end the stroke thins to a point. Default 0.
    ///   - pressure: Pressure multipliers along the stroke. Multiplied by the
    ///     noisy body. Empty skips pressure. Default empty.
    ///   - seed: Stable noise seed. Default 1.
    ///   - frequency: Noise cycles along the stroke. Default 3.
    public init(
        variation: CGFloat = 0,
        minimum: CGFloat? = nil,
        maximum: CGFloat? = nil,
        taperStart: CGFloat = 0,
        taperEnd: CGFloat = 0,
        pressure: [CGFloat] = [],
        seed: UInt64 = 1,
        frequency: CGFloat = 3
    ) {
        let variation = min(1, max(0, variation))
        let explicitBounds = minimum != nil || maximum != nil
        let resolved: (low: CGFloat, high: CGFloat, amount: CGFloat)

        if explicitBounds || variation > 0 {
            let lower = minimum ?? (1 - variation)
            let upper = maximum ?? (1 + variation)
            let low = min(lower, upper)
            let high = max(lower, upper)
            // Bounds already describe the span. `variation` then scales that
            // span. Variation alone is the span, so the noise uses all of it.
            let amount: CGFloat = explicitBounds ? (variation > 0 ? variation : 1) : 1
            resolved = (low, high, amount)
        } else if !pressure.isEmpty || taperStart > 0 || taperEnd > 0 {
            let peak = pressure.max() ?? 1
            resolved = (0, max(1, peak), 0)
        } else {
            resolved = (1, 1, 0)
        }

        self.amount = resolved.amount
        self.minimum = resolved.low
        self.maximum = resolved.high
        self.taperStart = min(1, max(0, taperStart))
        self.taperEnd = min(1, max(0, taperEnd))
        self.pressure = pressure
        self.seed = seed
        self.frequency = max(0.5, frequency)
    }

    /// Same wobble with a different seed.
    ///
    /// Watercolor uses this when `Options.seed` replaces a default style seed.
    /// The marker factory does not call it, so an existing marker seed stays put.
    func with(seed: UInt64) -> VariableStrokeWidth {
        var copy = self
        copy.seed = seed
        return copy
    }

    /// True when the multiplier is not identically 1.
    var changesWidth: Bool {
        if taperStart > 0 || taperEnd > 0 || !pressure.isEmpty {
            return true
        }
        if amount <= 0 {
            return false
        }
        return abs(minimum - 1) > 0.000_001 || abs(maximum - 1) > 0.000_001
    }

    /// Thickness multiplier at `t`, from 0 at the start to 1 at the end.
    ///
    /// Without a taper the result stays in `[minimum, maximum]`. A taper may
    /// fall to 0 and still does not exceed `maximum`.
    public func multiplier(at t: CGFloat) -> CGFloat {
        let clampedT = min(1, max(0, t))
        let body = noisyBody(at: clampedT)
        let pressureValue = pressure.isEmpty
            ? 1
            : ThicknessProfile.pressure(pressure).multiplier(at: clampedT)
        let taper = min(
            ThicknessProfile.taperIn(start: taperStart).multiplier(at: clampedT),
            ThicknessProfile.taperOut(end: taperEnd).multiplier(at: clampedT)
        )
        let raw = body * pressureValue * taper
        let floor: CGFloat = (taperStart > 0 || taperEnd > 0) ? 0 : minimum
        return min(maximum, max(floor, raw))
    }

    /// Noisy body before pressure and taper. `1` when `amount` is 0.
    private func noisyBody(at t: CGFloat) -> CGFloat {
        guard amount > 0 else { return 1 }
        guard maximum > minimum else { return minimum }
        let noise = Self.signedNoise(at: t * frequency, seed: seed)
        let center = (minimum + maximum) / 2
        let half = (maximum - minimum) / 2
        return center + noise * half * min(amount, 1)
    }

    /// 1-D value noise in `[-1, 1]`, smooth between lattice points.
    private static func signedNoise(at x: CGFloat, seed: UInt64) -> CGFloat {
        let noise = valueNoise1D(at: Float(x), seed: seed)
        return CGFloat(noise * 2 - 1)
    }

    /// Hashes integer lattice points into `[0, 1]` and smoothsteps between them.
    private static func valueNoise1D(at x: Float, seed: UInt64) -> Float {
        let i = floor(x)
        let fraction = x - i
        let fade = fraction * fraction * (3 - 2 * fraction)
        let left = hash(Int64(i), seed: seed)
        let right = hash(Int64(i) + 1, seed: seed)
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
