//
//  SegmentedStrokeBuilder.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Splits a stroke path into N short subpaths so the SwiftUI renderer
//  can emit per-segment fills with interpolated color and opacity along
//  the path.
//
//  This is the SwiftUI-side counterpart to the Metal renderer's
//  fragment-shader-driven gradient: the Metal path interpolates
//  per-pixel over `s ∈ [0, 1]` for free, while the SwiftUI path emits
//  one `context.stroke(...)` call per segment because SwiftUI Canvas
//  has no shader-level along-path control. The cost is bounded by the
//  segment count (default 16, capped at 64) so worst-case per-stroke
//  draw count is a small constant.
//

import SwiftUI

/// Constructs per-segment stroke commands for a path with along-path
/// color and/or opacity variation.
///
/// The builder is deliberately renderer-agnostic in its outputs (it
/// returns `RoughRenderCommand`s) so it can be invoked from any place
/// that has a `SwiftUI.Path` to draw, including future per-stroke effects
/// added to fill rendering.
enum SegmentedStrokeBuilder {

    /// Default number of segments. Chosen empirically: high enough that a
    /// linear gradient across an entire screen-width stroke is smooth to
    /// the eye, low enough that a screen full of strokes is still cheap
    /// (a 200-stroke chart at 16 segments = 3 200 fill calls per frame,
    /// well under SwiftUI Canvas budget).
    static let defaultSegmentCount = 16

    /// Hard cap on segment count. Prevents pathological growth if a
    /// caller decides to drive segment count from animation frame index
    /// or similar.
    static let maxSegmentCount = 64

    /// Builds per-segment stroke commands for `path` using the supplied
    /// along-path color and opacity descriptors.
    ///
    /// - Parameters:
    ///   - path: The full stroke path. Should be the entire stroke as one
    ///     `SwiftUI.Path`; multiple subpaths are handled internally by
    ///     `Path.trimmedPath`.
    ///   - lineWidth: Stroke width passed through unchanged to each
    ///     command.
    ///   - cap: Stroke cap style for each segment.
    ///   - join: Stroke join style for each segment.
    ///   - colorAlongPath: Optional along-path color descriptor. When
    ///     `nil`, the segment color is `baseColor`.
    ///   - opacityAlongPath: Optional along-path opacity descriptor.
    ///     When `nil`, the segment alpha is `baseOpacity`.
    ///   - baseColor: Fallback color when `colorAlongPath == nil`. Also
    ///     used as the target when only opacity varies.
    ///   - baseOpacity: Fallback opacity when `opacityAlongPath == nil`.
    ///   - segmentCount: Number of segments to emit. Clamped to
    ///     `[1, maxSegmentCount]`. Defaults to `defaultSegmentCount`.
    /// - Returns: An array of stroke commands, one per segment.
    static func build(
        path: SwiftUI.Path,
        lineWidth: CGFloat,
        cap: BrushCap,
        join: BrushJoin,
        colorAlongPath: ColorAlongPath?,
        opacityAlongPath: OpacityAlongPath?,
        baseColor: UIColor,
        baseOpacity: Float,
        segmentCount: Int = defaultSegmentCount
    ) -> [RoughRenderCommand] {
        let n = max(1, min(maxSegmentCount, segmentCount))
        var commands: [RoughRenderCommand] = []
        commands.reserveCapacity(n)

        for i in 0..<n {
            let from = CGFloat(i) / CGFloat(n)
            let to = CGFloat(i + 1) / CGFloat(n)
            // Sample the appearance at the segment midpoint. Linear
            // interpolation between adjacent midpoint samples is what
            // the human eye actually perceives — sampling at endpoints
            // would double-count joins.
            let s = (from + to) / 2

            let segmentPath = path.trimmedPath(from: from, to: to)

            let segmentColor = resolveColor(
                colorAlongPath: colorAlongPath,
                baseColor: baseColor,
                at: Float(s)
            )
            let segmentAlpha = resolveOpacity(
                opacityAlongPath: opacityAlongPath,
                baseOpacity: baseOpacity,
                at: Float(s)
            )

            let swiftColor = Color(segmentColor).opacity(Double(segmentAlpha))
            commands.append(
                RoughRenderCommand(
                    path: segmentPath,
                    style: .stroke(swiftColor, lineWidth: lineWidth),
                    cap: cap,
                    join: join
                )
            )
        }

        return commands
    }

    // MARK: - Sampling

    /// Resolves the color at parameter `s ∈ [0, 1]` along the path.
    static func resolveColor(
        colorAlongPath: ColorAlongPath?,
        baseColor: UIColor,
        at s: Float
    ) -> UIColor {
        guard let along = colorAlongPath else { return baseColor }
        switch along.kind {
        case .solid:
            return along.startColor
        case .gradient:
            return interpolateColor(
                from: along.startColor,
                to: along.endColor,
                t: CGFloat(max(0, min(1, s)))
            )
        }
    }

    /// Resolves the opacity multiplier at parameter `s ∈ [0, 1]`.
    static func resolveOpacity(
        opacityAlongPath: OpacityAlongPath?,
        baseOpacity: Float,
        at s: Float
    ) -> Float {
        guard let along = opacityAlongPath else { return baseOpacity }
        switch along {
        case .constant(let v):
            return baseOpacity * max(0, min(1, v))
        case .taper(let start, let end):
            let interp = start + (end - start) * max(0, min(1, s))
            return baseOpacity * max(0, min(1, interp))
        }
    }

    /// Linearly interpolates between two `UIColor` values in extended
    /// sRGB space. Falls back to `from` if either color cannot be
    /// resolved into RGBA components.
    static func interpolateColor(from: UIColor, to: UIColor, t: CGFloat) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        guard from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa),
              to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta) else {
            return from
        }
        let clampedT = max(0, min(1, t))
        return UIColor(
            red:   fr + (tr - fr) * clampedT,
            green: fg + (tg - fg) * clampedT,
            blue:  fb + (tb - fb) * clampedT,
            alpha: fa + (ta - fa) * clampedT
        )
    }
}
