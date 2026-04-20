//
//  BrushTexture.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Texture mode for stroke ribbons. Currently consumed by the Metal
//  renderer only — the SwiftUI renderer ignores the field and continues
//  to render smooth strokes.
//

import Foundation

/// The texture style applied across the stroke ribbon by renderers that
/// support per-pixel stroke shading (currently the Metal renderer in the
/// `RoughSwiftUIMetal` library).
///
/// The Metal fragment shader samples a procedural value-noise function
/// parameterized by the per-vertex `(s, t)` coordinates and modulates
/// alpha (and in some cases color) based on the selected style. All
/// styles share the same triangle-strip mesh — switching styles is a
/// one-uniform change with no extra geometry.
///
/// On the SwiftUI renderer this field is ignored; behavior matches
/// `.smooth`. A future PR will add multi-pass stipple emission to the
/// SwiftUI renderer for parity (the equivalent CPU technique is bounded
/// by stamp count rather than fragment count, so it scales differently).
public enum BrushTexture: Equatable, Hashable, Sendable {

    // MARK: Cases

    /// No texture. The stroke ribbon is filled with the gradient/opacity
    /// appearance as-is. Default.
    case smooth

    /// Pencil-style grain: per-pixel value-noise threshold cuts random
    /// gaps out of the alpha channel. Mimics the way graphite skips over
    /// paper texture.
    /// - `grain`: spatial frequency of the noise (cycles per stroke
    ///   width). Default `1.5`. Higher values produce finer grain.
    /// - `density`: probability that any given pixel is rendered.
    ///   Range `[0, 1]`. Default `0.7`. Lower values produce sparser
    ///   coverage.
    case pencil(grain: Float = 1.5, density: Float = 0.7)

    /// Chalk: large-grain noise, lower coverage than pencil, with extra
    /// drop-out toward the stroke edges (chalk on board doesn't fill
    /// edges evenly).
    /// - `grain`: spatial frequency. Default `0.8` (chunkier than pencil).
    /// - `density`: pixel coverage probability. Default `0.55`.
    case chalk(grain: Float = 0.8, density: Float = 0.55)

    /// Ink bleed: darker inset core with a soft outer halo, simulating
    /// pigment spreading on paper. Multiplies the base alpha by a smooth
    /// across-stroke envelope; does not introduce gaps.
    /// - `bleed`: how far the alpha falloff extends across the ribbon
    ///   width. Range `[0, 1]`. Default `0.6`. Higher values produce a
    ///   wider, softer halo.
    case ink(bleed: Float = 0.6)

    /// Watercolor: edge-darkened wash. Multiplies alpha by a noise-
    /// modulated envelope that emphasizes the ribbon boundary (where
    /// water pools in real watercolor).
    /// - `edgeDarkness`: how much the boundary is emphasized.
    ///   Range `[0, 1]`. Default `0.5`.
    /// - `bleed`: width of the soft falloff inside the boundary.
    ///   Range `[0, 1]`. Default `0.4`.
    case watercolor(edgeDarkness: Float = 0.5, bleed: Float = 0.4)

    // MARK: Convenience presets

    /// Default pencil with library defaults.
    public static let pencilDefault: BrushTexture = .pencil()

    /// Default chalk with library defaults.
    public static let chalkDefault: BrushTexture = .chalk()

    /// Default ink with library defaults.
    public static let inkDefault: BrushTexture = .ink()

    /// Default watercolor with library defaults.
    public static let watercolorDefault: BrushTexture = .watercolor()

    // MARK: Introspection

    /// True iff this texture is `.smooth` — the renderer can skip the
    /// procedural-noise fragment shader path entirely.
    public var isSmooth: Bool {
        if case .smooth = self { return true } else { return false }
    }
}
