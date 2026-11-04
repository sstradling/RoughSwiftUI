//
//  WatercolorFill.swift
//  Sketchy
//
//  A clipped wash. The shape is already padded and shifted by the generator
//  (`fillPadding` / `fillOffset`).
//
//  Layers are ordinary translucent fills, so they glaze. A ring of uneven dabs
//  dries darker at the edge. Specks and a few backruns keep the interior from
//  looking airbrushed. Nothing here is blurred.
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
        _ = nextGroup
        let bounds = shape.boundingRect
        guard style.pigment > 0, fillOpacity > 0, bounds.width > 1, bounds.height > 1 else { return [] }

        let pigment = CGFloat(style.pigment)
        var pieces: [RibbonPiece] = [
            RibbonPiece(path: shape, opacity: min(1, pigment * 0.2 * fillOpacity), t: 0)
        ]

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for layer in 0..<style.layers {
            let seed = style.seed &+ UInt64(layer + 1) &* 0x9E37_79B9_7F4A_7C15
            let reach = CGFloat(style.wetness) * min(bounds.width, bounds.height) * 0.04
            let dx = SeededNoise.signed(at: 0.4 + CGFloat(layer), seed: seed) * reach
            let dy = SeededNoise.signed(at: 1.7 + CGFloat(layer), seed: seed &+ 9) * reach
            let factor = 0.9 + 0.06 * CGFloat(SeededNoise.unit(at: Float(layer) + 0.2, seed: seed))
            let moved = shape
                .applying(scaledAbout(center, factor: factor))
                .applying(CGAffineTransform(translationX: dx, y: dy))
            let opacity = pigment * (0.08 + 0.05 * CGFloat(layer % 2)) * fillOpacity
            pieces.append(RibbonPiece(path: moved, opacity: min(1, opacity), t: CGFloat(layer)))
        }

        let outline = perimeter(of: shape, spacing: max(6, min(bounds.width, bounds.height) * 0.045))
        pieces.append(contentsOf: edgeDabs(
            outline: outline,
            toward: center,
            style: style,
            pigment: pigment,
            fillOpacity: fillOpacity
        ))
        pieces.append(contentsOf: backruns(
            outline: outline,
            toward: center,
            bounds: bounds,
            style: style,
            pigment: pigment,
            fillOpacity: fillOpacity
        ))
        pieces.append(contentsOf: interiorGrain(
            shape: shape,
            bounds: bounds,
            style: style,
            pigment: pigment,
            fillOpacity: fillOpacity
        ))
        return glazeCommands(pieces, color: color, clip: shape)
    }

    /// Uneven pigment dried just inside the outline. The outer side is the shape edge.
    private static func edgeDabs(
        outline: [PerimeterSample],
        toward: CGPoint,
        style: WatercolorStyle,
        pigment: CGFloat,
        fillOpacity: CGFloat
    ) -> [RibbonPiece] {
        let darkening = CGFloat(style.edgeDarkening)
        guard darkening > 0.02, outline.count >= 2 else { return [] }
        var pieces: [RibbonPiece] = []
        for index in 0..<(outline.count - 1) {
            let start = outline[index]
            let end = outline[index + 1]
            let unit0 = SeededNoise.unit(at: Float(index) * 0.23, seed: style.seed &+ 41)
            let unit1 = SeededNoise.unit(at: Float(index + 1) * 0.23, seed: style.seed &+ 41)
            let band = (2.2 + 5.5 * darkening) * (0.55 + CGFloat(style.bleed) * 0.35)
            let startInner = step(from: start.point, toward: toward, distance: band * (0.65 + CGFloat(unit0)))
            let endInner = step(from: end.point, toward: toward, distance: band * (0.65 + CGFloat(unit1)))
            var path = SwiftUI.Path()
            path.move(to: start.point)
            path.addLine(to: end.point)
            path.addLine(to: endInner)
            path.addLine(to: startInner)
            path.closeSubpath()
            let opacity = pigment * (0.14 + 0.28 * darkening) * fillOpacity * (0.75 + 0.35 * CGFloat(unit0))
            pieces.append(RibbonPiece(path: path, opacity: min(1, opacity), t: CGFloat(index)))
        }
        return pieces
    }

    /// A few low-opacity puddles near the edge. Overlapping ellipses glaze into one blot.
    private static func backruns(
        outline: [PerimeterSample],
        toward: CGPoint,
        bounds: CGRect,
        style: WatercolorStyle,
        pigment: CGFloat,
        fillOpacity: CGFloat
    ) -> [RibbonPiece] {
        guard style.bleed > 0.05, outline.count >= 8 else { return [] }
        let blooms = 3
        var pieces: [RibbonPiece] = []
        let reach = min(bounds.width, bounds.height)
        for bloom in 0..<blooms {
            let seed = style.seed &+ UInt64(bloom) &* 0xC2B2_AE3D
            let slot = Int(SeededNoise.unit(at: Float(bloom) + 0.4, seed: seed) * Float(outline.count - 1))
            let anchor = outline[min(outline.count - 1, max(0, slot))]
            let inward = step(from: anchor.point, toward: toward, distance: reach * (0.12 + 0.05 * CGFloat(bloom)))
            for puff in 0..<3 {
                let jitter = SeededNoise.signed(at: CGFloat(puff) + 0.2, seed: seed &+ UInt64(puff))
                let center = CGPoint(
                    x: inward.x + cos(anchor.tangent) * jitter * 8,
                    y: inward.y + sin(anchor.tangent) * jitter * 8
                )
                let radius = reach * (0.06 + 0.03 * CGFloat(style.bleed)) * (0.8 + 0.35 * CGFloat(puff))
                let opacity = pigment * 0.07 * fillOpacity
                pieces.append(RibbonPiece(path: circle(center, radius), opacity: opacity, t: CGFloat(bloom)))
            }
        }
        return pieces
    }

    /// Small seeded specks. Points that fall outside the shape are skipped.
    private static func interiorGrain(
        shape: SwiftUI.Path,
        bounds: CGRect,
        style: WatercolorStyle,
        pigment: CGFloat,
        fillOpacity: CGFloat
    ) -> [RibbonPiece] {
        let path = shape.cgPath
        let count = 22 + Int(CGFloat(style.variation) * 10)
        var pieces: [RibbonPiece] = []
        pieces.reserveCapacity(count)
        var attempt = 0
        var placed = 0
        while placed < count && attempt < count * 6 {
            let seed = style.seed &+ UInt64(attempt) &* 0x27BB_2EE6
            let x = bounds.minX + CGFloat(SeededNoise.unit(at: Float(attempt) * 0.17, seed: seed)) * bounds.width
            let y = bounds.minY + CGFloat(SeededNoise.unit(at: Float(attempt) * 0.17 + 2, seed: seed &+ 3)) * bounds.height
            let point = CGPoint(x: x, y: y)
            attempt += 1
            guard path.contains(point) else { continue }
            let unit = SeededNoise.unit(at: Float(attempt) * 0.2, seed: seed &+ 9)
            let radius = 1.1 + CGFloat(unit) * (1.6 + CGFloat(style.variation) * 1.4)
            let opacity = pigment * fillOpacity * (0.035 + 0.06 * CGFloat(unit))
            pieces.append(RibbonPiece(path: circle(point, radius), opacity: min(1, opacity), t: CGFloat(placed)))
            placed += 1
        }
        return pieces
    }

    private static func perimeter(of path: SwiftUI.Path, spacing: CGFloat) -> [PerimeterSample] {
        var samples: [PerimeterSample] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        path.forEach { element in
            switch element {
            case .move(let point):
                current = point
                subpathStart = point
            case .line(let point):
                append(from: current, to: point, spacing: spacing, into: &samples)
                current = point
            case .quadCurve(let point, let control):
                flatten(from: current, to: point, controls: [control], spacing: spacing, into: &samples)
                current = point
            case .curve(let point, let control1, let control2):
                flatten(from: current, to: point, controls: [control1, control2], spacing: spacing, into: &samples)
                current = point
            case .closeSubpath:
                append(from: current, to: subpathStart, spacing: spacing, into: &samples)
                current = subpathStart
            }
        }
        return samples
    }

    private static func append(from: CGPoint, to: CGPoint, spacing: CGFloat, into samples: inout [PerimeterSample]) {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let length = hypot(dx, dy)
        guard length > 0.5 else { return }
        let tangent = atan2(dy, dx)
        let steps = max(1, Int((length / spacing).rounded(.up)))
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            samples.append(PerimeterSample(
                point: CGPoint(x: from.x + dx * t, y: from.y + dy * t),
                tangent: tangent
            ))
        }
    }

    private static func flatten(
        from: CGPoint,
        to: CGPoint,
        controls: [CGPoint],
        spacing: CGFloat,
        into samples: inout [PerimeterSample]
    ) {
        let steps = 8
        var previous = from
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let point: CGPoint
            if controls.count == 1 {
                point = quad(from: from, control: controls[0], to: to, t: t)
            } else {
                point = cubic(from: from, c1: controls[0], c2: controls[1], to: to, t: t)
            }
            append(from: previous, to: point, spacing: spacing, into: &samples)
            previous = point
        }
    }

    private static func quad(from: CGPoint, control: CGPoint, to: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
            y: u * u * from.y + 2 * u * t * control.y + t * t * to.y
        )
    }

    private static func cubic(from: CGPoint, c1: CGPoint, c2: CGPoint, to: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * u * from.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * to.x,
            y: u * u * u * from.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * to.y
        )
    }

    private static func step(from: CGPoint, toward: CGPoint, distance: CGFloat) -> CGPoint {
        let dx = toward.x - from.x
        let dy = toward.y - from.y
        let length = hypot(dx, dy)
        guard length > 0.001 else { return from }
        return CGPoint(x: from.x + dx / length * distance, y: from.y + dy / length * distance)
    }

    private static func circle(_ center: CGPoint, _ radius: CGFloat) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path
    }

    private static func scaledAbout(_ center: CGPoint, factor: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y)
            .scaledBy(x: factor, y: factor)
            .translatedBy(x: -center.x, y: -center.y)
    }
}

private struct PerimeterSample {
    var point: CGPoint
    var tangent: CGFloat
}
