//
//  RibbonAppearance.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Per-ribbon shader inputs derived from the renderer's `Options`.
//

import Foundation
import simd
import UIKit
import RoughSwiftUI

/// Inputs to the gradient-ribbon fragment shader for a single stroke.
///
/// The shader interpolates `colorStart` to `colorEnd` along the stroke,
/// multiplies the result by `opacityScale`, and applies a soft edge across
/// the ribbon width controlled by `edgeSoftness`.
public struct RibbonAppearance: Equatable {
    /// Color at `s = 0` (start of the stroke).
    public var colorStart: SIMD4<Float>

    /// Color at `s = 1` (end of the stroke).
    public var colorEnd: SIMD4<Float>

    /// Multiplier applied to the alpha channel of the interpolated color.
    /// Use `1.0` for fully opaque, `0.0` for fully transparent.
    public var opacityScale: Float

    /// Cross-stroke edge softness in `[0, 1]`. `0` is a hard ribbon edge
    /// (matches `BrushCap.butt`); higher values produce an ink-like falloff
    /// out to the boundary at `|t| = 1`.
    public var edgeSoftness: Float

    public init(
        colorStart: SIMD4<Float>,
        colorEnd: SIMD4<Float>,
        opacityScale: Float,
        edgeSoftness: Float
    ) {
        self.colorStart = colorStart
        self.colorEnd = colorEnd
        self.opacityScale = opacityScale
        self.edgeSoftness = edgeSoftness
    }

    /// Builds an appearance from base library `Options`.
    ///
    /// Resolution order:
    /// - **Color**: `Options.strokeColorAlongPath` if set; otherwise a
    ///   flat-color appearance derived from `Options.stroke`.
    /// - **Opacity**: `Options.strokeOpacityAlongPath` if set; otherwise
    ///   the constant `Options.strokeOpacity`.
    /// - **Edge softness**: `Options.strokeEdgeSoftness` (default `0`).
    ///
    /// The Metal fragment shader interpolates between `colorStart` and
    /// `colorEnd` linearly over `s ∈ [0, 1]` and multiplies by
    /// `opacityScale`. Per-`s` opacity envelopes are baked into the
    /// `.a` channels of `colorStart`/`colorEnd` when an
    /// `OpacityAlongPath` is supplied (so a single linear interpolation
    /// in the shader handles both color and opacity gradients).
    public static func from(options: Options) -> RibbonAppearance {
        let baseStart: SIMD4<Float>
        let baseEnd: SIMD4<Float>

        if let colorAlong = options.strokeColorAlongPath {
            baseStart = colorAlong.startColor.simd4
            baseEnd = colorAlong.endColor.simd4
        } else {
            let c = options.stroke.simd4
            baseStart = c
            baseEnd = c
        }

        // Per-endpoint alpha multiplier. When a taper is present, bake it
        // into the .a of each endpoint so the shader doesn't need a
        // separate per-vertex opacity attribute.
        let alphaStart: Float
        let alphaEnd: Float
        if let opacityAlong = options.strokeOpacityAlongPath {
            switch opacityAlong {
            case .constant(let v):
                alphaStart = v; alphaEnd = v
            case .taper(let s, let e):
                alphaStart = s; alphaEnd = e
            }
        } else {
            alphaStart = 1
            alphaEnd = 1
        }

        let colorStart = SIMD4<Float>(
            baseStart.x, baseStart.y, baseStart.z, baseStart.w * alphaStart
        )
        let colorEnd = SIMD4<Float>(
            baseEnd.x, baseEnd.y, baseEnd.z, baseEnd.w * alphaEnd
        )

        return RibbonAppearance(
            colorStart: colorStart,
            colorEnd: colorEnd,
            opacityScale: options.strokeOpacity,
            edgeSoftness: options.strokeEdgeSoftness
        )
    }
}

// MARK: - Color helpers

extension UIColor {
    /// Returns the receiver's RGBA components in extended sRGB space, clamped
    /// to `[0, 1]`. Falls back to `(0, 0, 0, 1)` if the color cannot be
    /// converted (e.g. pattern colors).
    var rgbaComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        if !getRed(&r, green: &g, blue: &b, alpha: &a) {
            // Try to coerce via converting through sRGB.
            let cs = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            if let converted = cgColor.converted(to: cs, intent: .defaultIntent, options: nil),
               let comps = converted.components, comps.count >= 4 {
                return (comps[0], comps[1], comps[2], comps[3])
            }
            return (0, 0, 0, 1)
        }
        return (r, g, b, a)
    }

    /// RGBA components packed into a SIMD4 of Float for direct use as
    /// shader uniforms.
    var simd4: SIMD4<Float> {
        let c = rgbaComponents
        return SIMD4<Float>(Float(c.r), Float(c.g), Float(c.b), Float(c.a))
    }
}
