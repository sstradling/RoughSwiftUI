//
//  WatercolorFill.swift
//  Sketchy
//
//  A clipped wash. The shape handed in is already padded and shifted by the
//  generator (`fillPadding` / `fillOffset`), so this painter does not inset again.
//
//  Wet copies sit inside the clip. One mask paints a darker rim by filling the
//  shape, then replacing the centre with a smaller, lighter copy. A small blur
//  feathers the rim and the paper edge.
//

import CoreGraphics
import SwiftUI

enum WatercolorFill {
    /// Wash commands clipped to `shape`.
    static func commands(
        shape: SwiftUI.Path,
        color: Color,
        style: WatercolorStyle,
        fillOpacity: CGFloat,
        nextGroup: inout Int
    ) -> [RoughRenderCommand] {
        let bounds = shape.boundingRect
        guard style.pigment > 0, fillOpacity > 0, bounds.width > 1, bounds.height > 1 else { return [] }

        var result: [RoughRenderCommand] = []
        let pigment = CGFloat(style.pigment)
        let baseBlur = 0.3 + CGFloat(style.bleed) * 1.1
        result.append(contentsOf: fillMask(
            path: shape,
            clip: shape,
            color: color,
            opacity: pigment * 0.28 * fillOpacity,
            blur: baseBlur,
            nextGroup: &nextGroup
        ))

        let wetPasses = max(0, style.layers - 1)
        for layer in 0..<wetPasses {
            let seed = style.seed &+ UInt64(layer + 1) &* 0x9E37_79B9_7F4A_7C15
            let reach = CGFloat(style.wetness) * min(bounds.width, bounds.height) * 0.035
            let dx = SeededNoise.signed(at: 0.4 + CGFloat(layer), seed: seed) * reach
            let dy = SeededNoise.signed(at: 1.7 + CGFloat(layer), seed: seed &+ 9) * reach
            let moved = shape.applying(CGAffineTransform(translationX: dx, y: dy))
            result.append(contentsOf: fillMask(
                path: moved,
                clip: shape,
                color: color,
                opacity: pigment * 0.14 * fillOpacity,
                blur: 0,
                nextGroup: &nextGroup
            ))
        }

        let darkening = CGFloat(style.edgeDarkening)
        let rim = pigment * (0.2 + 0.62 * darkening) * fillOpacity
        let centre = rim * (1 - 0.86 * darkening)
        // A large light centre leaves a narrow pigment rim instead of a vignette.
        let scale = 0.78 + 0.14 * (1 - darkening)
        var pooling: [RibbonPiece] = [
            RibbonPiece(path: shape, opacity: min(1, rim), t: 0)
        ]
        if darkening > 0.02 {
            pooling.append(RibbonPiece(path: scaled(shape, by: scale), opacity: min(1, centre), t: 1))
        }
        let poolBlur = 0.8 + CGFloat(style.bleed) * 2.2
        result.append(contentsOf: maskCommands(
            pooling,
            color: color,
            blur: poolBlur,
            clip: shape,
            nextGroup: &nextGroup
        ))
        return result
    }

    private static func fillMask(
        path: SwiftUI.Path,
        clip: SwiftUI.Path,
        color: Color,
        opacity: CGFloat,
        blur: CGFloat,
        nextGroup: inout Int
    ) -> [RoughRenderCommand] {
        maskCommands(
            [RibbonPiece(path: path, opacity: min(1, max(0, opacity)), t: 0)],
            color: color,
            blur: blur,
            clip: clip,
            nextGroup: &nextGroup
        )
    }

    /// Scales `path` about its bounding-box centre.
    private static func scaled(_ path: SwiftUI.Path, by factor: CGFloat) -> SwiftUI.Path {
        let bounds = path.boundingRect
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let transform = CGAffineTransform(translationX: center.x, y: center.y)
            .scaledBy(x: factor, y: factor)
            .translatedBy(x: -center.x, y: -center.y)
        return path.applying(transform)
    }
}
