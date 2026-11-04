//
//  WatercolorStyle.swift
//  Sketchy
//
//  Wet-wash settings for `BrushProfile.watercolor` and `.fillStyle(.watercolor)`.
//

import Foundation

/// Controls a watercolor stroke or a watercolor fill.
///
/// `BrushProfile.watercolor` stores one of these. `.fillStyle(.watercolor)`
/// uses that style when the brush is watercolor, and these defaults otherwise.
/// `Options.seed` replaces `defaultSeed`. Values are clamped. The same `seed`
/// repeats the same wash.
/// Nothing here reads the system random generator.
///
/// The fill is several translucent glazes clipped to the shape. The rim is
/// darker than the centre, the edge wanders, and a few blooms break up the
/// interior. Glazes stack, so a second layer goes darker. `bleed` is that
/// uneven edge and the backruns, not a blur.
public struct WatercolorStyle: Equatable, Hashable, Sendable {
    /// How strong the pigment is, from 0 (paper) to 1 (a heavy wash). Default 0.72.
    public var pigment: Float

    /// How far wet passes drift, from 0 to 1. Default 0.6.
    public var wetness: Float

    /// How much darker the rim is than the centre, from 0 (flat) to 1. Default 0.75.
    public var edgeDarkening: Float

    /// The body passes. Clamped to 1...5. Default 3.
    public var layers: Int

    /// How much the wash wanders, from 0 to 1. Default 0.45.
    public var variation: Float

    /// How far the dried edge wanders, and how many backruns appear, from 0 to 1.
    ///
    /// This does not blur the fill. Default 0.5.
    public var bleed: Float

    /// Preset seed. `Options.seed` replaces this only while a style is still here.
    public static let defaultSeed: UInt64 = 1

    /// Seed for the wash offsets.
    ///
    /// Change it for a different, still-stable wash. `defaultSeed` yields to
    /// `Options.seed`. Any other value wins.
    public var seed: UInt64

    /// Creates watercolor settings.
    public init(
        pigment: Float = 0.72,
        wetness: Float = 0.6,
        edgeDarkening: Float = 0.75,
        layers: Int = 3,
        variation: Float = 0.45,
        bleed: Float = 0.5,
        seed: UInt64 = WatercolorStyle.defaultSeed
    ) {
        self.pigment = min(1, max(0, pigment))
        self.wetness = min(1, max(0, wetness))
        self.edgeDarkening = min(1, max(0, edgeDarkening))
        self.layers = min(5, max(1, layers))
        self.variation = min(1, max(0, variation))
        self.bleed = min(1, max(0, bleed))
        self.seed = seed
    }
}
