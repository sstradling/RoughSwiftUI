//
//  CrayonStyle.swift
//  RoughSwift
//
//  Texture settings for the wax-crayon brush preset.
//

import Foundation

/// Controls the grain, edge, and layering of a crayon stroke.
///
/// Values are clamped. The same `seed` and path produce the same texture,
/// so a render does not flicker when SwiftUI redraws it.
public struct CrayonStyle: Equatable, Hashable, Sendable {
    /// How much bare paper shows through the wax, from 0 (solid) to 1 (very broken).
    /// Default is 0.34.
    public var grain: Float

    /// How far the edge wanders, as a fraction of the stroke width. Range 0...1.
    /// Default is 0.62.
    public var edgeRoughness: Float

    /// How much the width swells and thins along the stroke. Range 0...1.
    /// Default is 0.3.
    public var widthVariation: Float

    /// How much later wax passes fade relative to the first. Range 0...1.
    /// Default is 0.38. Ignored when `passes` is 1.
    public var opacityVariation: Float

    /// Number of overlapping wax passes. Clamped to 1...3. Default is 2.
    public var passes: Int

    /// Seed for the grain. Change it to get a different, still-stable texture.
    public var seed: UInt64

    /// Creates crayon texture settings.
    public init(
        grain: Float = 0.34,
        edgeRoughness: Float = 0.62,
        widthVariation: Float = 0.3,
        opacityVariation: Float = 0.38,
        passes: Int = 2,
        seed: UInt64 = 1
    ) {
        self.grain = min(1, max(0, grain))
        self.edgeRoughness = min(1, max(0, edgeRoughness))
        self.widthVariation = min(1, max(0, widthVariation))
        self.opacityVariation = min(1, max(0, opacityVariation))
        self.passes = min(3, max(1, passes))
        self.seed = seed
    }
}
