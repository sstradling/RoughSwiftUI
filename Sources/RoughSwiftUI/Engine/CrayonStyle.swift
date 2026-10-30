//
//  CrayonStyle.swift
//  RoughSwift
//
//  Texture settings for the wax-crayon brush preset.
//

import Foundation

/// Controls the base wax and the grit laid over a crayon stroke.
///
/// Values are clamped. The same `seed` and path produce the same texture,
/// so a render does not flicker when SwiftUI redraws it.
///
/// A crayon stroke is continuous. A soft, slightly translucent wax base is
/// drawn first, then denser flakes and edge crumbs are laid on top. There is
/// no parameter that opens paper breaks along the stroke.
public struct CrayonStyle: Equatable, Hashable, Sendable {
    /// How much the grit layer thins out, from 0 (packed flakes) to 1 (more paper speckle).
    ///
    /// This does not break the wax base. Default is 0.28.
    public var grain: Float

    /// How ragged the grit edge is, as a fraction of the stroke width. Range 0...1.
    ///
    /// Higher values throw more detached flakes off the side. Default is 0.75.
    public var edgeRoughness: Float

    /// How much the width swells and thins along the stroke. Range 0...1.
    /// Default is 0.18.
    public var widthVariation: Float

    /// How much later grit passes fade relative to the first. Range 0...1.
    /// Default is 0.35. Ignored when `passes` is 1.
    public var opacityVariation: Float

    /// Number of grit layers drawn on top of the base. Clamped to 1...3. Default is 2.
    public var passes: Int

    /// Opacity of the greasy base, from 0.2 (thin wash) to 1 (opaque wax).
    ///
    /// The soft halo under the base is a fraction of this. Default is 0.8.
    public var baseOpacity: Float

    /// How soft and wide the base edge is. Range 0...1.
    ///
    /// `0` is a firm edge. `1` spreads a wider translucent smudge around the core.
    /// Default is 0.5.
    public var baseSoftness: Float

    /// How densely flakes cover the base. Range 0...1.
    ///
    /// `0` is a few marks. `1` packs the core with wax clumps and speckle. Default is 0.92.
    public var grit: Float

    /// Size of the grit flakes relative to the stroke width. Range 0.35...3.
    ///
    /// `1` is the preset flake. Larger values make darker clumps and specks bigger.
    /// A thinner stroke gets smaller flakes, so the grit stays a fraction of the wax.
    /// Default is 1.45.
    public var flakeSize: Float

    /// Preset grain seed. `Options.seed` replaces this only while a crayon
    /// style is still on the preset. Any other value wins over `Options.seed`.
    public static let defaultSeed: UInt64 = 1

    /// Seed for the grain. Change it to get a different, still-stable texture.
    public var seed: UInt64

    /// Creates crayon texture settings.
    public init(
        grain: Float = 0.28,
        edgeRoughness: Float = 0.75,
        widthVariation: Float = 0.18,
        opacityVariation: Float = 0.35,
        passes: Int = 2,
        baseOpacity: Float = 0.8,
        baseSoftness: Float = 0.5,
        grit: Float = 0.92,
        flakeSize: Float = 1.45,
        seed: UInt64 = CrayonStyle.defaultSeed
    ) {
        self.grain = min(1, max(0, grain))
        self.edgeRoughness = min(1, max(0, edgeRoughness))
        self.widthVariation = min(1, max(0, widthVariation))
        self.opacityVariation = min(1, max(0, opacityVariation))
        self.passes = min(3, max(1, passes))
        self.baseOpacity = min(1, max(0.2, baseOpacity))
        self.baseSoftness = min(1, max(0, baseSoftness))
        self.grit = min(1, max(0, grit))
        self.flakeSize = min(3, max(0.35, flakeSize))
        self.seed = seed
    }
}
