//
//  WatercolorStroke.swift
//  Sketchy
//
//  Crisp watercolor glazes. There is no blur halo.
//
//  Each pass is a ribbon with a darker rim and a lighter core. The rim and the
//  core do not overlap, so the edge stays darker. Passes, granules, and a
//  stroke that crosses itself are ordinary translucent fills, so pigment stacks
//  the way overlapping washes do. The plain variable-opacity stroke still uses
//  the opacity mask and does not build up.
//

import CoreGraphics
import SwiftUI

enum WatercolorStroke {
    /// Outline commands for the path sets of one shape.
    ///
    /// The first centreline carries the dried rim. Later rough passes are a
    /// lighter body glaze, so they add pigment without a second outline.
    /// `width` is the body width in destination points.
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
        _ = nextGroup
        guard width >= 0.5, strokeOpacity > 0, style.pigment > 0 else { return [] }
        guard let primary = sets.first else { return [] }
        let lines = StrokeToFillConverter.centerlines(operations: primary, transform: transform)
        guard !lines.isEmpty else { return [] }

        var pieces: [RibbonPiece] = []
        for line in lines {
            for layer in 0..<style.layers {
                pieces.append(contentsOf: glaze(
                    line: line,
                    width: width,
                    brush: brush,
                    style: style,
                    strokeOpacity: strokeOpacity,
                    layer: layer,
                    edged: true,
                    strength: 1 - 0.1 * CGFloat(layer)
                ))
            }
            pieces.append(contentsOf: granules(
                line: line,
                width: width,
                brush: brush,
                style: style,
                strokeOpacity: strokeOpacity
            ))
        }
        return glazeCommands(pieces, color: color)
    }

    /// One wet pass: lighter core, darker rim, round tapered ends on an open stroke.
    private static func glaze(
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        strokeOpacity: CGFloat,
        layer: Int,
        edged: Bool,
        strength: CGFloat
    ) -> [RibbonPiece] {
        let stations = stations(line: line, width: width, brush: brush, style: style, layer: layer)
        guard stations.count >= 2 else { return [] }
        let darkening = CGFloat(style.edgeDarkening)
        let pigment = CGFloat(style.pigment) * strength
        let along = alongOpacity(0.5, closed: line.isClosed, brush: brush, strokeOpacity: strokeOpacity)
        let edge = min(1, pigment * (0.34 + 0.4 * darkening) * along)
        let core = min(1, edge * (0.42 + 0.4 * (1 - darkening)))
        var pieces = [
            RibbonPiece(path: ribbon(stations, outer: true, closed: line.isClosed), opacity: core, t: 0.5)
        ]
        if edged, darkening > 0.02 {
            var ringPiece = RibbonPiece(path: ring(stations, closed: line.isClosed), opacity: edge * 0.8, t: 0.5)
            ringPiece.evenOdd = true
            pieces.append(ringPiece)
        }
        return pieces
    }

    /// The whole wash as one shape, so the edge is a single outline instead of a row of quads.
    private static func ribbon(_ stations: [Station], outer: Bool, closed: Bool) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        guard let first = stations.first, let last = stations.last else { return path }
        path.move(to: outer ? first.outerLeft : first.innerLeft)
        for station in stations.dropFirst() {
            path.addLine(to: outer ? station.outerLeft : station.innerLeft)
        }
        if !closed {
            addCap(to: &path, at: last, radius: outer ? last.outerRadius : last.innerRadius, forward: last.forward)
        }
        for station in stations.reversed() {
            path.addLine(to: outer ? station.outerRight : station.innerRight)
        }
        if !closed {
            addCap(to: &path, at: first, radius: outer ? first.outerRadius : first.innerRadius, forward: first.forward + .pi)
        }
        path.closeSubpath()
        return path
    }

    /// Outer shape with the core cut out. Filled even-odd so only the rim remains.
    private static func ring(_ stations: [Station], closed: Bool) -> SwiftUI.Path {
        var path = ribbon(stations, outer: true, closed: closed)
        path.addPath(ribbon(stations, outer: false, closed: closed))
        return path
    }

    private static func addCap(to path: inout SwiftUI.Path, at station: Station, radius: CGFloat, forward: CGFloat) {
        guard radius >= 0.4 else { return }
        let steps = 8
        let start = forward + .pi / 2
        for step in 1...steps {
            let angle = start - .pi * CGFloat(step) / CGFloat(steps)
            path.addLine(to: CGPoint(
                x: station.center.x + cos(angle) * radius,
                y: station.center.y + sin(angle) * radius
            ))
        }
    }

    /// Grain and a few larger pigment blotches inside the ribbon.
    private static func granules(
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        strokeOpacity: CGFloat
    ) -> [RibbonPiece] {
        let samples = line.samples
        guard samples.count >= 2 else { return [] }
        var pieces: [RibbonPiece] = []
        let step = max(1, samples.count / 18)
        var index = 0
        while index < samples.count {
            let sample = samples[index]
            let half = halfWidth(at: sample, forward: sample.tangent, width: width, brush: brush, style: style, layer: 2, line: line)
            let seed = style.seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
            let across = SeededNoise.signed(at: CGFloat(index) * 0.17, seed: seed)
            let unit = SeededNoise.unit(at: Float(index) * 0.13, seed: seed &+ 11)
            let big = unit > 0.86
            let radius = half * (big ? 0.28 + 0.16 * CGFloat(unit) : 0.05 + 0.07 * CGFloat(unit))
            guard radius >= 0.4 else {
                index += step
                continue
            }
            let normal = sample.tangent + .pi / 2
            let center = CGPoint(
                x: sample.point.x + cos(normal) * across * half * 0.5,
                y: sample.point.y + sin(normal) * across * half * 0.5
            )
            let fade = line.isClosed ? 1 : tipScale(sample.t)
            let profile = alongOpacity(sample.t, closed: line.isClosed, brush: brush, strokeOpacity: strokeOpacity)
            let opacity = CGFloat(style.pigment) * profile * fade * (big ? 0.2 : 0.1) * (0.45 + CGFloat(unit))
            pieces.append(RibbonPiece(path: ellipse(center: center, radius: radius), opacity: min(1, opacity), t: sample.t))
            index += big ? step * 2 : step
        }
        return pieces
    }

    private static func stations(
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        layer: Int
    ) -> [Station] {
        let points = smoothedPoints(line.samples, closed: line.isClosed)
        let tangents = smoothedTangents(points, closed: line.isClosed)
        return line.samples.enumerated().map { index, sample in
            let forward = tangents[index]
            let located = StrokeCenterSample(point: points[index], tangent: forward, t: sample.t)
            let half = halfWidth(at: located, forward: forward, width: width, brush: brush, style: style, layer: layer, line: line)
            let shift = shiftAmount(at: sample.t, closed: line.isClosed, style: style, width: width, layer: layer)
            let bloom = bloomAmount(at: sample.t, closed: line.isClosed, style: style, layer: layer)
            let normalAngle = forward + .pi / 2
            let nx = cos(normalAngle)
            let ny = sin(normalAngle)
            let center = CGPoint(
                x: located.point.x + nx * shift,
                y: located.point.y + ny * shift
            )
            let innerScale = 1 - 0.38 * CGFloat(style.edgeDarkening)
            let left = half * (1 + max(0, bloom))
            let right = half * (1 + max(0, -bloom))
            return Station(
                center: center,
                forward: forward,
                outerLeft: CGPoint(x: center.x + nx * left, y: center.y + ny * left),
                outerRight: CGPoint(x: center.x - nx * right, y: center.y - ny * right),
                innerLeft: CGPoint(x: center.x + nx * left * innerScale, y: center.y + ny * left * innerScale),
                innerRight: CGPoint(x: center.x - nx * right * innerScale, y: center.y - ny * right * innerScale),
                outerRadius: max(left, right),
                innerRadius: max(left, right) * innerScale,
                t: sample.t
            )
        }
    }

    private static func halfWidth(
        at sample: StrokeCenterSample,
        forward: CGFloat,
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        layer: Int,
        line: (samples: [StrokeCenterSample], isClosed: Bool)
    ) -> CGFloat {
        let thickness = thicknessCurve(closed: line.isClosed, brush: brush)(sample.t)
        let tip = brush.tip.effectiveWidth(baseWidth: width * thickness, strokeAngle: forward)
        let wander = signed(sample.t, cycles: 1.7, seed: style.seed &+ UInt64(layer) &+ 19, closed: line.isClosed)
        let crisp = 1 + wander * (0.03 + CGFloat(style.bleed) * 0.1)
        let end = line.isClosed ? 1 : tipScale(sample.t)
        return max(0.2, tip * 0.5 * crisp * end)
    }

    /// A moving average of the centreline. Rough jitter would otherwise tooth the rim.
    private static func smoothedPoints(_ samples: [StrokeCenterSample], closed: Bool) -> [CGPoint] {
        let reach = 4
        return samples.indices.map { index in
            var x: CGFloat = 0
            var y: CGFloat = 0
            var weight: CGFloat = 0
            for offset in -reach...reach {
                let neighbor = neighbor(index + offset, count: samples.count, closed: closed)
                let influence = 1 - abs(CGFloat(offset)) / CGFloat(reach + 1)
                x += samples[neighbor].point.x * influence
                y += samples[neighbor].point.y * influence
                weight += influence
            }
            return CGPoint(x: x / weight, y: y / weight)
        }
    }

    /// Direction from a short chord of the smoothed centreline.
    private static func smoothedTangents(_ points: [CGPoint], closed: Bool) -> [CGFloat] {
        guard points.count >= 2 else { return [0] }
        let reach = 5
        return points.indices.map { index in
            let before = neighbor(index - reach, count: points.count, closed: closed)
            let after = neighbor(index + reach, count: points.count, closed: closed)
            let dx = points[after].x - points[before].x
            let dy = points[after].y - points[before].y
            if dx * dx + dy * dy < 0.01 {
                let step = neighbor(index + 1, count: points.count, closed: closed)
                return atan2(points[step].y - points[index].y, points[step].x - points[index].x)
            }
            return atan2(dy, dx)
        }
    }

    private static func neighbor(_ index: Int, count: Int, closed: Bool) -> Int {
        if closed {
            return (index % count + count) % count
        }
        return min(count - 1, max(0, index))
    }

    /// One-sided puddle. Zero along most of the stroke, a bulge at a few seeds.
    private static func bloomAmount(at t: CGFloat, closed: Bool, style: WatercolorStyle, layer: Int) -> CGFloat {
        guard style.bleed > 0.02 else { return 0 }
        let gates = closed ? 3 : 2
        var best: CGFloat = 0
        for gate in 0..<gates {
            let seed = style.seed &+ UInt64(layer * 5 + gate) &* 0x85EB_CA6B
            let at = 0.18 + CGFloat(gate) * (closed ? 0.28 : 0.46)
            let delta = abs(t - at)
            let wrapped = closed ? min(delta, 1 - delta) : delta
            let width = 0.07 + CGFloat(style.bleed) * 0.04
            let bell = max(0, 1 - wrapped / width)
            let signedGate = SeededNoise.signed(at: CGFloat(gate) + 0.3, seed: seed)
            let value = bell * bell * signedGate
            if abs(value) > abs(best) { best = value }
        }
        return best * CGFloat(style.bleed) * 0.55
    }

    private static func shiftAmount(
        at t: CGFloat,
        closed: Bool,
        style: WatercolorStyle,
        width: CGFloat,
        layer: Int
    ) -> CGFloat {
        let amount = CGFloat(style.wetness) * width * 0.07
        let raw = signed(t, cycles: 2.2, seed: style.seed &+ UInt64(layer) &* 0x9E37_79B9_7F4A_7C15, closed: closed) * amount
        guard closed else { return raw }
        let join = signed(0, cycles: 2.2, seed: style.seed &+ UInt64(layer) &* 0x9E37_79B9_7F4A_7C15, closed: true) * amount
        return seamBlend(value: raw, toward: join, t: t, window: 0.1)
    }

    private static func ellipse(center: CGPoint, radius: CGFloat) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path
    }

    /// Open strokes narrow into a round tip instead of a square cut.
    private static func tipScale(_ t: CGFloat) -> CGFloat {
        let window: CGFloat = 0.14
        let edge = min(max(0, t), max(0, 1 - t))
        if edge >= window { return 1 }
        let mix = edge / window
        let smooth = mix * mix * (3 - 2 * mix)
        return 0.36 + 0.64 * smooth
    }

    private static func thicknessCurve(closed: Bool, brush: BrushProfile) -> (CGFloat) -> CGFloat {
        let join = brush.thicknessProfile.multiplier(at: 0)
        return { t in
            let raw = brush.thicknessProfile.multiplier(at: t)
            guard closed else { return raw }
            return seamBlend(value: raw, toward: join, t: t, window: 0.1)
        }
    }

    private static func alongOpacity(
        _ t: CGFloat,
        closed: Bool,
        brush: BrushProfile,
        strokeOpacity: CGFloat
    ) -> CGFloat {
        let profile = brush.opacityProfile
        let join = profile.value(at: 0, periodic: true)
        let raw = profile.value(at: t, periodic: closed)
        let blended = closed ? seamBlend(value: raw, toward: join, t: t, window: 0.08) : raw
        return min(1, max(0, blended * strokeOpacity))
    }

    private static func signed(_ t: CGFloat, cycles: CGFloat, seed: UInt64, closed: Bool) -> CGFloat {
        if closed {
            let cells = max(1, Int(cycles.rounded()))
            let unit = SeededNoise.unitPeriodic(at: Float(t) * Float(cells), period: cells, seed: seed)
            return CGFloat(unit) * 2 - 1
        }
        return SeededNoise.signed(at: t * cycles, seed: seed)
    }
}

/// One sample of a watercolor ribbon, split into a light core and a dark rim.
private struct Station {
    var center: CGPoint
    var forward: CGFloat
    var outerLeft: CGPoint
    var outerRight: CGPoint
    var innerLeft: CGPoint
    var innerRight: CGPoint
    var outerRadius: CGFloat
    var innerRadius: CGFloat
    var t: CGFloat
}
