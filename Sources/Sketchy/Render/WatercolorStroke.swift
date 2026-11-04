//
//  WatercolorStroke.swift
//  Sketchy
//
//  Wet layers for a watercolor outline.
//
//  Every path set in the drawing (rough.js draws the outline twice) is unioned
//  into each layer's mask. Overlaps inside a layer replace instead of adding,
//  so the double stroke becomes one wash. Layers then stack with source-over,
//  which is the wet pigment. A later, narrower band in the same mask replaces
//  the centre with a lower opacity and leaves the rim dark.
//

import CoreGraphics
import SwiftUI

enum WatercolorStroke {
    /// Outline commands for every path set of one shape.
    ///
    /// `width` is the body width in destination points. `strokeOpacity` multiplies
    /// the wash. A width below half a point draws nothing.
    static func commands(
        sets: [[Operation]],
        transform: CGAffineTransform,
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        strokeOpacity: CGFloat,
        color: Color,
        nextGroup: inout Int
    ) -> [RoughRenderCommand] {
        guard width >= 0.5, strokeOpacity > 0, style.pigment > 0 else { return [] }
        let lines = sets.flatMap { operations in
            StrokeToFillConverter.centerlines(operations: operations, transform: transform)
        }
        guard !lines.isEmpty else { return [] }

        var result: [RoughRenderCommand] = []
        if style.bleed > 0.02 {
            let bloomScale = 1.45 + CGFloat(style.bleed) * 0.9
            let blur = 0.8 + CGFloat(style.bleed) * 4.5
            let bloom = piecesFor(
                lines: lines,
                brush: brush,
                style: style,
                width: width * bloomScale,
                shiftWidth: width,
                strokeOpacity: strokeOpacity,
                pigment: CGFloat(style.pigment) * 0.1 * CGFloat(style.bleed),
                layer: 0,
                cap: .butt,
                includeCaps: false
            )
            result.append(contentsOf: maskCommands(bloom, color: color, blur: blur, nextGroup: &nextGroup))
        }

        let washCount = max(0, style.layers - 1)
        for layer in 0..<washCount {
            let wash = piecesFor(
                lines: lines,
                brush: brush,
                style: style,
                width: width * (0.92 - 0.04 * CGFloat(layer)),
                shiftWidth: width,
                strokeOpacity: strokeOpacity,
                pigment: CGFloat(style.pigment) * 0.2,
                layer: layer + 1,
                cap: .butt,
                includeCaps: false
            )
            result.append(contentsOf: maskCommands(wash, color: color, blur: 0.6, nextGroup: &nextGroup))
        }

        // One pooling pass. Extra pooled passes would stack into stripes.
        result.append(contentsOf: pooledLayer(
            lines: lines,
            brush: brush,
            style: style,
            width: width,
            strokeOpacity: strokeOpacity,
            color: color,
            layerScale: 1,
            darkening: CGFloat(style.edgeDarkening),
            layer: style.layers + 1,
            nextGroup: &nextGroup
        ))
        return result
    }

    /// One wet pass: a wide rim, then a lighter middle, then a lighter core.
    ///
    /// All three bands share a mask group so the core replaces the centre.
    private static func pooledLayer(
        lines: [(samples: [StrokeCenterSample], isClosed: Bool)],
        brush: BrushProfile,
        style: WatercolorStyle,
        width: CGFloat,
        strokeOpacity: CGFloat,
        color: Color,
        layerScale: CGFloat,
        darkening: CGFloat,
        layer: Int,
        nextGroup: inout Int
    ) -> [RoughRenderCommand] {
        let scales: [(width: CGFloat, opacity: CGFloat)] = [
            (layerScale, 1),
            (layerScale * (1 - 0.22 * darkening), 1 - 0.28 * darkening),
            (layerScale * (1 - 0.7 * darkening), 1 - 0.72 * darkening)
        ]
        var pieces: [RibbonPiece] = []
        for scale in scales {
            let bandPieces = piecesFor(
                lines: lines,
                brush: brush,
                style: style,
                width: width * scale.width,
                shiftWidth: width,
                strokeOpacity: strokeOpacity,
                pigment: CGFloat(style.pigment) * 0.62 * scale.opacity,
                layer: layer,
                cap: .butt,
                includeCaps: false
            )
            pieces.append(contentsOf: bandPieces)
        }
        let bodyBlur = max(1.35, width * 0.04)
        return maskCommands(pieces, color: color, blur: bodyBlur, nextGroup: &nextGroup)
    }

    private static func piecesFor(
        lines: [(samples: [StrokeCenterSample], isClosed: Bool)],
        brush: BrushProfile,
        style: WatercolorStyle,
        width: CGFloat,
        shiftWidth: CGFloat,
        strokeOpacity: CGFloat,
        pigment: CGFloat,
        layer: Int,
        cap: BrushCap,
        includeCaps: Bool
    ) -> [RibbonPiece] {
        var pieces: [RibbonPiece] = []
        for line in lines {
            let along = opacityCurve(closed: line.isClosed, brush: brush, strokeOpacity: strokeOpacity, pigment: pigment)
            let shiftAt = shiftCurve(closed: line.isClosed, style: style, width: shiftWidth, layer: layer)
            let thicknessAt = thicknessCurve(closed: line.isClosed, brush: brush)
            pieces.append(contentsOf: StrokeRibbon.pieces(
                samples: line.samples,
                isClosed: line.isClosed,
                cap: includeCaps ? cap : .butt,
                geometry: { sample in
                    let multiplier = thicknessAt(sample.t)
                    let tipWidth = brush.tip.effectiveWidth(
                        baseWidth: width * multiplier,
                        strokeAngle: sample.tangent
                    )
                    let lift = line.isClosed ? 1 : brushLift(sample.t)
                    return StrokeRibbon.SampleGeometry(
                        halfWidth: max(0, tipWidth / 2),
                        shift: shiftAt(sample.t),
                        opacity: along(sample.t) * lift
                    )
                }
            ))
        }
        return pieces
    }

    /// Fades an open stroke at both ends so the brush lifts off the paper.
    private static func brushLift(_ t: CGFloat) -> CGFloat {
        let window: CGFloat = 0.08
        let edge = min(max(0, t), max(0, 1 - t))
        if edge >= window { return 1 }
        let mix = edge / window
        return mix * mix * (3 - 2 * mix)
    }

    /// Thickness multiplier, blended at the join of a closed contour.
    private static func thicknessCurve(closed: Bool, brush: BrushProfile) -> (CGFloat) -> CGFloat {
        let join = brush.thicknessProfile.multiplier(at: 0)
        return { t in
            let raw = brush.thicknessProfile.multiplier(at: t)
            guard closed else { return raw }
            return seamBlend(value: raw, toward: join, t: t, window: 0.1)
        }
    }

    /// Profile opacity times pigment times stroke opacity.
    private static func opacityCurve(
        closed: Bool,
        brush: BrushProfile,
        strokeOpacity: CGFloat,
        pigment: CGFloat
    ) -> (CGFloat) -> CGFloat {
        let profile = brush.opacityProfile
        let join = profile.value(at: 0, periodic: true) * pigment * strokeOpacity
        return { t in
            let raw = profile.value(at: t, periodic: closed) * pigment * strokeOpacity
            let blended = closed ? seamBlend(value: raw, toward: join, t: t, window: 0.08) : raw
            return min(1, max(0, blended))
        }
    }

    /// Sideways drift for one wet layer. Closed contours meet at `t = 0`.
    private static func shiftCurve(
        closed: Bool,
        style: WatercolorStyle,
        width: CGFloat,
        layer: Int
    ) -> (CGFloat) -> CGFloat {
        let seed = style.seed &+ UInt64(layer) &* 0x9E37_79B9_7F4A_7C15
        let amount = CGFloat(style.wetness) * width * 0.22
        func raw(_ t: CGFloat) -> CGFloat {
            let noise = SeededNoise.signed(at: t * 2.2 + CGFloat(layer) * 0.41, seed: seed)
            return noise * amount
        }
        let join = raw(0)
        return { t in
            let value = raw(t)
            guard closed else { return value }
            return seamBlend(value: value, toward: join, t: t, window: 0.1)
        }
    }
}
