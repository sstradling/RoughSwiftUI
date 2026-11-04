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
        let reach = CGFloat(style.wetness) * min(bounds.width, bounds.height) * 0.015
            let dx = SeededNoise.signed(at: 0.4 + CGFloat(layer), seed: seed) * reach
            let dy = SeededNoise.signed(at: 1.7 + CGFloat(layer), seed: seed &+ 9) * reach
            let factor = 0.985
            let moved = shape
                .applying(scaledAbout(center, factor: factor))
                .applying(CGAffineTransform(translationX: dx * 0.35, y: dy * 0.35))
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
        let count = outline.count
        for index in 0..<count {
            let next = (index + 1) % count
            let start = outline[index]
            let end = outline[next]
            let span = hypot(end.point.x - start.point.x, end.point.y - start.point.y)
            if span < 0.4 || span > 28 { continue }
            let unit0 = SeededNoise.unit(at: Float(index) * 0.23, seed: style.seed &+ 41)
            let unit1 = SeededNoise.unit(at: Float(next) * 0.23, seed: style.seed &+ 41)
            let bandWidth = (1.6 + 3.2 * darkening) * (0.7 + CGFloat(style.bleed) * 0.25)
            let startInner = step(from: start.point, toward: toward, distance: bandWidth * (0.75 + 0.4 * CGFloat(unit0)))
            let endInner = step(from: end.point, toward: toward, distance: bandWidth * (0.75 + 0.4 * CGFloat(unit1)))
            let area = shoelace(start.point, end.point, endInner, startInner)
            if abs(area) < 0.5 { continue }
            let path = area > 0
                ? band(start.point, end.point, endInner, startInner)
                : band(start.point, startInner, endInner, end.point)
            let opacity = pigment * (0.16 + 0.26 * darkening) * fillOpacity * (0.7 + 0.3 * CGFloat(unit0))
            pieces.append(RibbonPiece(path: path, opacity: min(1, opacity), t: CGFloat(index)))
        }
        return pieces
    }

    /// Two irregular puddles. The edge is lumpy, not a stack of discs.
    private static func backruns(
        outline: [PerimeterSample],
        toward: CGPoint,
        bounds: CGRect,
        style: WatercolorStyle,
        pigment: CGFloat,
        fillOpacity: CGFloat
    ) -> [RibbonPiece] {
        guard style.bleed > 0.05, outline.count >= 8 else { return [] }
        let reach = min(bounds.width, bounds.height)
        var pieces: [RibbonPiece] = []
        for bloom in 0..<2 {
            let seed = style.seed &+ UInt64(bloom) &* 0xC2B2_AE3D
            let slot = Int(SeededNoise.unit(at: Float(bloom) + 0.4, seed: seed) * Float(outline.count - 1))
            let anchor = outline[min(outline.count - 1, max(0, slot))]
            let inward = step(from: anchor.point, toward: toward, distance: reach * (0.16 + 0.05 * CGFloat(bloom)))
            let radius = reach * (0.11 + 0.04 * CGFloat(style.bleed))
            pieces.append(RibbonPiece(
                path: cauliflower(center: inward, radius: radius, seed: seed),
                opacity: pigment * 0.09 * fillOpacity,
                t: CGFloat(bloom)
            ))
            pieces.append(RibbonPiece(
                path: cauliflower(center: inward, radius: radius * 0.62, seed: seed &+ 5),
                opacity: pigment * 0.06 * fillOpacity,
                t: CGFloat(bloom)
            ))
        }
        return pieces
    }

    /// A lumpy closed outline. Radius wobbles so the edge reads as a backrun, not a circle.
    private static func cauliflower(center: CGPoint, radius: CGFloat, seed: UInt64) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        let count = 22
        for index in 0...count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
            let noise = 0.78 + 0.42 * CGFloat(SeededNoise.unit(at: Float(index) * 0.41 + Float(angle), seed: seed))
            let lump = 0.88 + 0.18 * sin(angle * 2 + CGFloat(seed % 5))
            let distance = radius * lump * noise
            let point = CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
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
        let count = 8 + Int(CGFloat(style.variation) * 6)
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
            let radius = 0.8 + CGFloat(unit) * (2.8 + CGFloat(style.variation) * 2)
            let opacity = pigment * fillOpacity * (0.02 + 0.05 * CGFloat(unit))
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

    private static func band(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
    }

    private static func shoelace(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGFloat {
        (a.x * b.y - b.x * a.y) + (b.x * c.y - c.x * b.y) + (c.x * d.y - d.x * c.y) + (d.x * a.y - a.x * d.y)
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
