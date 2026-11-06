//
//  OpacityProfile.swift
//  Sketchy
//
//  Opacity along a stroke, independent of `ThicknessProfile`.
//  Positioned stops live here so width-stop work can land beside them.
//

import CoreGraphics
import Foundation

/// One opacity sample at a position along a stroke.
///
/// `position` is 0 at the start and 1 at the end. `opacity` is a multiplier
/// in 0...1, applied on top of `Options.strokeOpacity`.
public struct OpacityStop: Equatable, Hashable, Sendable {
    /// Distance along the stroke, clamped to 0...1.
    public var position: CGFloat

    /// Opacity multiplier at `position`, clamped to 0...1.
    public var opacity: CGFloat

    /// Creates a stop.
    /// - Parameters:
    ///   - opacity: Multiplier in 0...1. Values outside the range are clamped.
    ///   - position: Distance along the stroke, 0...1. Values outside are clamped.
    public init(_ opacity: CGFloat, at position: CGFloat) {
        self.position = min(1, max(0, position))
        self.opacity = min(1, max(0, opacity))
    }
}

/// Seeded opacity wobble between a minimum and a maximum.
///
/// The same `seed` repeats the same curve. `variation` scales how much of the
/// span is used: `1` covers `[minimum, maximum]`, `0` stays at the midpoint.
public struct OpacityNoise: Equatable, Hashable, Sendable {
    /// Lowest opacity when `variation` is 1. Clamped to 0...1.
    public private(set) var minimum: CGFloat

    /// Highest opacity when `variation` is 1. Clamped to 0...1.
    public private(set) var maximum: CGFloat

    /// Fraction of `[minimum, maximum]` used by the noise, 0...1.
    ///
    /// The wobble is centered on the midpoint. `0` is that midpoint with no wobble.
    public private(set) var variation: CGFloat

    /// Repeats the wobble. Any `UInt64` is valid, including 0.
    ///
    /// `defaultSeed` (`1`) is replaced by `Options.seed` when that is set.
    /// Any other seed wins, matching `CrayonStyle`.
    public private(set) var seed: UInt64

    /// Noise cycles from the start of the stroke to the end. Clamped to at least 0.5.
    public private(set) var frequency: CGFloat

    /// Preset seed. `Options.seed` replaces this only while a noise profile is still here.
    public static let defaultSeed: UInt64 = 1

    /// Creates a noise profile.
    /// - Parameters:
    ///   - minimum: Lower opacity, 0...1. Default 0.35.
    ///   - maximum: Upper opacity, 0...1. Default 1. Swapped if it is below `minimum`.
    ///   - variation: How much of the span the noise uses, 0...1. Default 1.
    ///   - seed: Stable noise seed. Default `defaultSeed`.
    ///   - frequency: Cycles along the stroke. Default 3.
    public init(
        minimum: CGFloat = 0.35,
        maximum: CGFloat = 1,
        variation: CGFloat = 1,
        seed: UInt64 = OpacityNoise.defaultSeed,
        frequency: CGFloat = 3
    ) {
        let low = min(1, max(0, minimum))
        let high = min(1, max(0, maximum))
        self.minimum = min(low, high)
        self.maximum = max(low, high)
        self.variation = min(1, max(0, variation))
        self.seed = seed
        self.frequency = max(0.5, frequency)
    }

    /// True when samples along the stroke are not all the same value.
    public var varies: Bool {
        variation > 0 && maximum - minimum > 0.000_001
    }

    /// Opacity in 0...1 at `t` (0 start, 1 end).
    ///
    /// When `periodic` is true the noise repeats so `t = 0` matches `t = 1`.
    /// Closed contours use that so the join does not step.
    public func opacity(at t: CGFloat, periodic: Bool = false) -> CGFloat {
        let clamped = min(1, max(0, t))
        guard maximum > minimum, variation > 0 else {
            return (minimum + maximum) / 2
        }
        let noise = periodic
            ? periodicUnit(at: clamped)
            : SeededNoise.unit(at: Float(clamped * frequency), seed: seed)
        let signed = CGFloat(noise) * 2 - 1
        let mid = (minimum + maximum) / 2
        let half = (maximum - minimum) / 2
        let raw = mid + signed * half * variation
        return min(maximum, max(minimum, raw))
    }

    /// Same profile with a different seed. Used when `Options.seed` wins.
    func with(seed: UInt64) -> OpacityNoise {
        var copy = self
        copy.seed = seed
        return copy
    }

    private func periodicUnit(at t: CGFloat) -> Float {
        let cells = max(1, Int(frequency.rounded()))
        let x = Float(t) * Float(cells)
        return SeededNoise.unitPeriodic(at: x, period: cells, seed: seed)
    }
}

/// How opacity changes from the start of a stroke to the end.
///
/// The value is a multiplier in 0...1. The renderer multiplies it by
/// `Options.strokeOpacity`. `.uniform` is 1, so existing strokes stay put.
///
/// Cases:
/// - `.uniform` — the same multiplier everywhere
/// - `.values` — evenly spaced samples, interpolated like `ThicknessProfile.custom`
/// - `.stops` — positioned samples in 0...1
/// - `.noise` — seeded wobble between a minimum and a maximum
public enum OpacityProfile: Equatable, Hashable, Sendable {
    /// Multiplier 1 along the whole stroke.
    case uniform

    /// Evenly spaced multipliers. Empty falls back to 1. One value is constant.
    case values([CGFloat])

    /// Stops placed along the stroke. Positions are 0...1.
    case stops([OpacityStop])

    /// Seeded wobble. See `OpacityNoise`.
    case noise(OpacityNoise)

    /// Seeded noise between `minimum` and `maximum`.
    public static func noise(
        minimum: CGFloat = 0.35,
        maximum: CGFloat = 1,
        variation: CGFloat = 1,
        seed: UInt64 = OpacityNoise.defaultSeed,
        frequency: CGFloat = 3
    ) -> OpacityProfile {
        .noise(OpacityNoise(
            minimum: minimum,
            maximum: maximum,
            variation: variation,
            seed: seed,
            frequency: frequency
        ))
    }

    /// True when opacity is not a single constant along the stroke.
    ///
    /// A constant below 1 (one value, flat stops, or noise with no variation)
    /// is false. The renderer multiplies `strokeOpacity` by that constant and
    /// keeps the existing stroke path.
    public var variesAlongStroke: Bool {
        switch self {
        case .uniform:
            return false
        case .values(let samples):
            let clamped = samples.map(Self.clamp)
            guard let first = clamped.first else { return false }
            return clamped.contains { abs($0 - first) > 0.000_001 }
        case .stops(let stops):
            guard let first = stops.first else { return false }
            return stops.contains { abs($0.opacity - first.opacity) > 0.000_001 }
        case .noise(let noise):
            return noise.varies
        }
    }

    /// Opacity multiplier at `t`, from 0 at the start to 1 at the end.
    ///
    /// The result is clamped to 0...1. It does not include `strokeOpacity`.
    /// `periodic` wraps noise so a closed contour matches at the join.
    /// Values and stops do not wrap; the stroke builder blends those joins.
    public func value(at t: CGFloat, periodic: Bool = false) -> CGFloat {
        let clampedT = min(1, max(0, t))
        switch self {
        case .uniform:
            return 1
        case .values(let samples):
            return Self.clamp(Self.interpolate(samples.map(Self.clamp), at: clampedT))
        case .stops(let stops):
            return Self.clamp(Self.interpolate(stops: stops, at: clampedT))
        case .noise(let noise):
            return noise.opacity(at: clampedT, periodic: periodic)
        }
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }

    /// Linear interpolation through evenly spaced samples. Empty returns 1.
    private static func interpolate(_ samples: [CGFloat], at t: CGFloat) -> CGFloat {
        guard !samples.isEmpty else { return 1 }
        guard samples.count > 1 else { return samples[0] }
        let scaled = t * CGFloat(samples.count - 1)
        let lower = Int(scaled)
        let upper = min(lower + 1, samples.count - 1)
        let fraction = scaled - CGFloat(lower)
        return samples[lower] + (samples[upper] - samples[lower]) * fraction
    }

    /// Linear interpolation through stops sorted by position.
    ///
    /// Before the first stop the value holds. After the last stop it holds.
    /// Duplicate positions use the later stop.
    private static func interpolate(stops: [OpacityStop], at t: CGFloat) -> CGFloat {
        guard !stops.isEmpty else { return 1 }
        let ordered = stops.sorted { lhs, rhs in
            if lhs.position == rhs.position { return false }
            return lhs.position < rhs.position
        }
        guard let first = ordered.first else { return 1 }
        if t <= first.position { return first.opacity }
        for index in 1..<ordered.count {
            let right = ordered[index]
            if t > right.position { continue }
            let left = ordered[index - 1]
            let span = right.position - left.position
            if span <= 0.000_001 { return right.opacity }
            let fraction = (t - left.position) / span
            return left.opacity + (right.opacity - left.opacity) * fraction
        }
        return ordered[ordered.count - 1].opacity
    }
}
