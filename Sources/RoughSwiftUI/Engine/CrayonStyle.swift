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
///
/// The preset is a dry crayon on toothy paper: a dense wax core, pinholes,
/// a torn edge with loose flecks, and a second lighter pass. `segmentLength`
/// stretches that rhythm; it does not change how fine the speckle is.
public struct CrayonStyle: Equatable, Hashable, Sendable {
    /// How much bare paper shows through, from 0 (solid wax) to 1 (very broken).
    ///
    /// This opens pinholes in the core and widens the longer gaps between wax runs.
    /// Default is 0.5.
    public var grain: Float

    /// How ragged the edge is, as a fraction of the stroke width. Range 0...1.
    ///
    /// Higher values tear the side of the stroke and throw off more detached flecks.
    /// Default is 0.88.
    public var edgeRoughness: Float

    /// How much the width swells and thins along the stroke. Range 0...1.
    /// Default is 0.28.
    public var widthVariation: Float

    /// How much later wax passes fade relative to the first. Range 0...1.
    /// Default is 0.62. Ignored when `passes` is 1.
    public var opacityVariation: Float

    /// Number of overlapping wax passes. Clamped to 1...3. Default is 2.
    public var passes: Int

    /// Length of each wax run relative to the preset, and the paper gap that goes with it.
    ///
    /// `1` is the preset. `3` makes both the wax runs and the gaps between them
    /// about three times longer. Speckle size does not change. Clamped to 0.25...8.
    public var segmentLength: Float

    /// How fine the paper-tooth speckle is. Range 0...1.
    ///
    /// `0` uses larger wax blobs. `1` breaks the stroke into small flecks, pinholes,
    /// and edge crumbs. Default is 0.86.
    public var tooth: Float

    /// Seed for the grain. Change it to get a different, still-stable texture.
    public var seed: UInt64

    /// Creates crayon texture settings.
    public init(
        grain: Float = 0.5,
        edgeRoughness: Float = 0.88,
        widthVariation: Float = 0.28,
        opacityVariation: Float = 0.62,
        passes: Int = 2,
        segmentLength: Float = 1,
        tooth: Float = 0.86,
        seed: UInt64 = 1
    ) {
        self.grain = min(1, max(0, grain))
        self.edgeRoughness = min(1, max(0, edgeRoughness))
        self.widthVariation = min(1, max(0, widthVariation))
        self.opacityVariation = min(1, max(0, opacityVariation))
        self.passes = min(3, max(1, passes))
        self.segmentLength = min(8, max(0.25, segmentLength))
        self.tooth = min(1, max(0, tooth))
        self.seed = seed
    }
}
