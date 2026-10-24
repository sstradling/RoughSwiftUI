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
    /// The proof-of-concept derives a flat color (start == end) from
    /// `options.stroke` and applies `options.strokeOpacity`. Future work
    /// will populate `colorStart`/`colorEnd` from `Options.strokeColorAlongPath`
    /// once that field lands as part of the variable-stroke plan.
    public static func from(options: Options) -> RibbonAppearance {
        let rgba = options.stroke.rgbaComponents
        let color = SIMD4<Float>(
            Float(rgba.r),
            Float(rgba.g),
            Float(rgba.b),
            Float(rgba.a)
        )
        return RibbonAppearance(
            colorStart: color,
            colorEnd: color,
            opacityScale: options.strokeOpacity,
            edgeSoftness: 0
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
}
