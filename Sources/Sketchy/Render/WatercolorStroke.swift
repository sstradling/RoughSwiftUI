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
        let core = min(1, pigment * (0.22 + 0.16 * (1 - darkening)) * along)
        var pieces = [
            RibbonPiece(path: ribbon(stations, closed: line.isClosed), opacity: core, t: 0.5)
        ]
        if edged {
            pieces.append(contentsOf: brokenRim(
                stations: stations,
                pigment: pigment * along,
                darkening: darkening,
                seed: style.seed &+ UInt64(layer) &* 17,
                closed: line.isClosed
            ))
        }
        return pieces
    }

    /// Short rim pieces. Width and darkness fade in and out so the edge is not a hard ring.
    private static func brokenRim(
        stations: [Station],
        pigment: CGFloat,
        darkening: CGFloat,
        seed: UInt64,
        closed: Bool
    ) -> [RibbonPiece] {
        guard darkening > 0.02, stations.count >= 2 else { return [] }
        var pieces: [RibbonPiece] = []
        let count = stations.count
        let limit = closed ? count : count - 1
        for index in 0..<limit {
            let next = (index + 1) % count
            let start = stations[index]
            let end = stations[next]
            let gate = SeededNoise.unit(at: Float(start.t * 4.2 + CGFloat(index) * 0.01), seed: seed &+ 71)
            let flicker = SeededNoise.unit(at: Float(start.t * 11), seed: seed &+ 93)
            let presence = max(0, (CGFloat(gate) - 0.34) / 0.66) * (0.25 + 0.75 * CGFloat(flicker))
            if presence < 0.12 { continue }
            let opacity = min(1, pigment * (0.08 + 0.22 * darkening) * presence)
            pieces.append(contentsOf: sideRim(start, end, side: 1, presence: presence, opacity: opacity))
            pieces.append(contentsOf: sideRim(start, end, side: -1, presence: presence, opacity: opacity * 0.9))
        }
        return pieces
    }

    /// A thin band on one side, plus a fainter band just inside it so the edge melts into the wash.
    private static func sideRim(
        _ start: Station,
        _ end: Station,
        side: CGFloat,
        presence: CGFloat,
        opacity: CGFloat
    ) -> [RibbonPiece] {
        let startOuter = side > 0 ? start.outerLeft : start.outerRight
        let endOuter = side > 0 ? end.outerLeft : end.outerRight
        let startHalf = max(0.5, hypot(startOuter.x - start.center.x, startOuter.y - start.center.y))
        let endHalf = max(0.5, hypot(endOuter.x - end.center.x, endOuter.y - end.center.y))
        let startDepth = min(startHalf * 0.55, startHalf * (0.07 + 0.2 * presence))
        let endDepth = min(endHalf * 0.55, endHalf * (0.07 + 0.2 * presence))
        let startMid = mix(startOuter, start.center, startDepth / startHalf)
        let endMid = mix(endOuter, end.center, endDepth / endHalf)
        let startDeep = mix(startOuter, start.center, min(0.7, startDepth * 2.4 / startHalf))
        let endDeep = mix(endOuter, end.center, min(0.7, endDepth * 2.4 / endHalf))
        return [
            RibbonPiece(path: quad(startOuter, endOuter, endMid, startMid), opacity: opacity, t: start.t),
            RibbonPiece(path: quad(startMid, endMid, endDeep, startDeep), opacity: opacity * 0.4, t: start.t)
        ]
    }

    /// The wash as one shape. The cap meets the real edge points so a peak does not pinch.
    private static func ribbon(_ stations: [Station], closed: Bool) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        guard let first = stations.first, let last = stations.last else { return path }
        path.move(to: first.outerLeft)
        for station in stations.dropFirst() {
            path.addLine(to: station.outerLeft)
        }
        if !closed {
            addCap(to: &path, from: last.outerLeft, center: last.center, to: last.outerRight, forward: last.forward)
        }
        for station in stations.reversed() {
            path.addLine(to: station.outerRight)
        }
        if !closed {
            addCap(to: &path, from: first.outerRight, center: first.center, to: first.outerLeft, forward: first.forward + .pi)
        }
        path.closeSubpath()
        return path
    }

    /// Arc from `from` to `to` that bulges along `forward` and lands on both edges.
    private static func addCap(
        to path: inout SwiftUI.Path,
        from: CGPoint,
        center: CGPoint,
        to: CGPoint,
        forward: CGFloat
    ) {
        let start = atan2(from.y - center.y, from.x - center.x)
        let end = atan2(to.y - center.y, to.x - center.x)
        var sweep = end - start
        if sweep > .pi { sweep -= 2 * .pi }
        if sweep < -.pi { sweep += 2 * .pi }
        let mid = start + sweep / 2
        if abs(atan2(sin(mid - forward), cos(mid - forward))) > .pi / 2 {
            sweep += sweep > 0 ? -2 * .pi : 2 * .pi
        }
        let startRadius = hypot(from.x - center.x, from.y - center.y)
        let endRadius = hypot(to.x - center.x, to.y - center.y)
        let steps = 8
        for step in 1...steps {
            let u = CGFloat(step) / CGFloat(steps)
            let angle = start + sweep * u
            let radius = startRadius * (1 - u) + endRadius * u
            path.addLine(to: CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius))
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
        let dense = densify(points: points, times: line.samples.map(\.t), maxStep: 1.6, closed: line.isClosed)
        let tangents = smoothedTangents(dense.map(\.point), closed: line.isClosed)
        let built = dense.enumerated().map { index, sample in
            let forward = tangents[index]
            let located = StrokeCenterSample(point: sample.point, tangent: forward, t: sample.t)
            let half = halfWidth(at: located, forward: forward, width: width, brush: brush, style: style, layer: layer, line: line)
            let shift = shiftAmount(at: sample.t, closed: line.isClosed, style: style, width: width, layer: layer)
            let limit = curvatureLimit(index: index, points: dense.map(\.point))
            let left = min(max(0.4, half), limit.left)
            let right = min(max(0.4, half), limit.right)
            let normalAngle = forward + .pi / 2
            let nx = cos(normalAngle)
            let ny = sin(normalAngle)
            let center = CGPoint(
                x: located.point.x + nx * shift,
                y: located.point.y + ny * shift
            )
            let innerScale = 1 - 0.22 * CGFloat(style.edgeDarkening)
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
        return clipSpikes(built, closed: line.isClosed)
    }

    /// Pulls offset points that shoot past their neighbours back onto the ribbon.
    private static func clipSpikes(_ stations: [Station], closed: Bool) -> [Station] {
        guard stations.count >= 3 else { return stations }
        var copy = stations
        let limit: CGFloat = 1.4
        for index in copy.indices {
            let previous = neighbor(index - 1, count: copy.count, closed: closed)
            let next = neighbor(index + 1, count: copy.count, closed: closed)
            if !closed, index == 0 || index == copy.count - 1 { continue }
            copy[index].outerLeft = pulled(
                copy[index].outerLeft,
                previous: copy[previous].outerLeft,
                next: copy[next].outerLeft,
                toward: copy[index].center,
                limit: limit
            )
            copy[index].outerRight = pulled(
                copy[index].outerRight,
                previous: copy[previous].outerRight,
                next: copy[next].outerRight,
                toward: copy[index].center,
                limit: limit
            )
        }
        return copy
    }

    private static func pulled(
        _ point: CGPoint,
        previous: CGPoint,
        next: CGPoint,
        toward: CGPoint,
        limit: CGFloat
    ) -> CGPoint {
        let dx = next.x - previous.x
        let dy = next.y - previous.y
        let lengthSquared = dx * dx + dy * dy
        let closest: CGPoint
        if lengthSquared < 0.01 {
            closest = previous
        } else {
            let u = min(1, max(0, ((point.x - previous.x) * dx + (point.y - previous.y) * dy) / lengthSquared))
            closest = CGPoint(x: previous.x + dx * u, y: previous.y + dy * u)
        }
        let offsetX = point.x - closest.x
        let offsetY = point.y - closest.y
        let distance = hypot(offsetX, offsetY)
        guard distance > limit else { return point }
        return CGPoint(x: closest.x + offsetX / distance * limit, y: closest.y + offsetY / distance * limit)
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
        let reach = 14
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

    /// Splits long steps so a tight peak is offset along the bend instead of across it.
    private static func densify(
        points: [CGPoint],
        times: [CGFloat],
        maxStep: CGFloat,
        closed: Bool
    ) -> [(point: CGPoint, t: CGFloat)] {
        guard points.count >= 2, points.count == times.count else {
            return zip(points, times).map { (point: $0.0, t: $0.1) }
        }
        var result: [(point: CGPoint, t: CGFloat)] = []
        let last = closed ? points.count : points.count - 1
        for index in 0..<last {
            let next = (index + 1) % points.count
            let from = points[index]
            let to = points[next]
            let distance = hypot(to.x - from.x, to.y - from.y)
            let steps = max(1, Int(ceil(distance / maxStep)))
            let startStep = result.isEmpty ? 0 : 1
            for step in startStep...steps {
                let u = CGFloat(step) / CGFloat(steps)
                result.append((
                    point: CGPoint(x: from.x + (to.x - from.x) * u, y: from.y + (to.y - from.y) * u),
                    t: times[index] + (times[next] - times[index]) * u
                ))
            }
        }
        if result.isEmpty {
            return zip(points, times).map { (point: $0.0, t: $0.1) }
        }
        return result
    }

    /// Keeps the inside of a tight bend from crossing the centreline and filling the corner.
    private static func curvatureLimit(index: Int, points: [CGPoint]) -> (left: CGFloat, right: CGFloat) {
        let open: CGFloat = 10_000
        guard index > 0, index < points.count - 1 else { return (open, open) }
        let previous = points[index - 1]
        let here = points[index]
        let next = points[index + 1]
        let incoming = CGPoint(x: here.x - previous.x, y: here.y - previous.y)
        let outgoing = CGPoint(x: next.x - here.x, y: next.y - here.y)
        let incomingLength = hypot(incoming.x, incoming.y)
        let outgoingLength = hypot(outgoing.x, outgoing.y)
        guard incomingLength > 0.4, outgoingLength > 0.4 else { return (open, open) }
        let cross = incoming.x * outgoing.y - incoming.y * outgoing.x
        let dot = incoming.x * outgoing.x + incoming.y * outgoing.y
        let angle = atan2(cross, dot)
        guard abs(angle) > 0.04 else { return (open, open) }
        let radius = min(incomingLength, outgoingLength) / abs(angle)
        let limit = max(0.8, radius * 0.82)
        return (limit, limit)
    }

    private static func mix(_ from: CGPoint, _ to: CGPoint, _ amount: CGFloat) -> CGPoint {
        CGPoint(
            x: from.x + (to.x - from.x) * amount,
            y: from.y + (to.y - from.y) * amount
        )
    }

    private static func quad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.addLine(to: d)
        path.closeSubpath()
        return path
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
