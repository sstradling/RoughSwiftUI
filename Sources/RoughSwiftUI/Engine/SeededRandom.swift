//
//  SeededRandom.swift
//  RoughSwiftUI
//
//  Deterministic random source for rough strokes and fills.
//

import Foundation

/// SplitMix64 generator.
///
/// The same seed produces the same sequence. `Options.seed` starts a fresh
/// generator at each top-level drawing, filler, or scribble generation.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    /// Creates a generator. Every `UInt64` value, including zero, is a valid seed.
    public init(seed: UInt64) {
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

/// Class box so one generator can advance across nested drawing calls.
final class RoughRandomBox: RandomNumberGenerator, @unchecked Sendable {
    private var generator: SplitMix64

    init(seed: UInt64) {
        generator = SplitMix64(seed: seed)
    }

    func next() -> UInt64 {
        var copy = generator
        let value = copy.next()
        generator = copy
        return value
    }
}

/// Random source for one drawing.
///
/// View modifiers write `Options.seed`. `NativeGenerator.generate`, each filler
/// entry point, `ScribbleFillGenerator`, and the public `RoughMath` helpers
/// call `with(seed:)`. A nested call keeps advancing the outer sequence.
/// `nil` keeps `Float.random`, which is the unseeded behavior.
public enum RoughRandom {
    @TaskLocal static var box: RoughRandomBox?

    /// True while a seeded sequence is already running.
    static var isActive: Bool { box != nil }

    /// Runs `body` inside a seeded sequence.
    ///
    /// An active sequence is left in place so fillers and line helpers do not
    /// restart the seed on every stroke. A `nil` seed does not install a
    /// generator.
    public static func with<T>(seed: UInt64?, _ body: () -> T) -> T {
        if box != nil {
            return body()
        }
        guard let seed else {
            return body()
        }
        let created = RoughRandomBox(seed: seed)
        return $box.withValue(created, operation: body)
    }

    /// Uniform value in `0...1`, matching `Float.random(in: 0...1)`.
    public static func unit() -> Float {
        guard var active = box else {
            return Float.random(in: 0...1)
        }
        return Float.random(in: 0...1, using: &active)
    }
}
