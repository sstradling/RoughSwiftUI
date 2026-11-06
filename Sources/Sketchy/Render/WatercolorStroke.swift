//
//  WatercolorStroke.swift
//  Sketchy
//
//  Crisp watercolor glazes. There is no blur halo.
//
//  Each pass is one ribbon around a single smoothed centreline, with a darker
//  rim and a lighter core. The rim and the core do not overlap, so the edge
//  stays darker. Passes, granules, and a stroke that crosses itself are
//  ordinary translucent fills, so pigment stacks the way overlapping washes do.
//  The plain variable-opacity stroke still uses the opacity mask and does not
//  build up.
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
        nextGroup: inout Int,
        miterLimit: CGFloat = 10
    ) -> [RoughRenderCommand] {
        _ = nextGroup
        guard width >= 0.5, strokeOpacity > 0, style.pigment > 0 else { return [] }
        guard let primary = sets.first else { return [] }
        let lines = StrokeToFillConverter.centerlines(operations: primary, transform: transform)
        // A rough outline is two offset passes. Painting both at full width
        // makes the stroke flare where the passes separate, which is the wedge
        // at the end of the curve. One smoothed centreline carries the wash.
        guard let line = lines.max(by: { $0.samples.count < $1.samples.count }) else { return [] }

        var pieces: [RibbonPiece] = []
        // Paler, slightly larger passes go down first. The saturated body
        // covers them, so only a thin fringe shows past the outline.
        for layer in stride(from: style.layers - 1, through: 0, by: -1) {
            pieces.append(contentsOf: glaze(
                line: line,
                width: width,
                brush: brush,
                style: style,
                strokeOpacity: strokeOpacity,
                layer: layer,
                edged: layer == 0,
                strength: 1 - 0.12 * CGFloat(layer),
                miterLimit: miterLimit
            ))
        }
        pieces.append(contentsOf: granules(
            line: line,
            width: width,
            brush: brush,
            style: style,
            strokeOpacity: strokeOpacity
        ))
        pieces.append(contentsOf: feathers(
            line: line,
            width: width,
            brush: brush,
            style: style,
            strokeOpacity: strokeOpacity
        ))
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
        strength: CGFloat,
        miterLimit: CGFloat
    ) -> [RibbonPiece] {
        let stations = stations(line: line, width: width, brush: brush, style: style, layer: layer)
        guard stations.count >= 2 else { return [] }
        let darkening = CGFloat(style.edgeDarkening)
        let pigment = CGFloat(style.pigment) * strength
        // One centreline replaced the second rough pass, and sampling the
        // opacity noise at a single t was dimming the whole ribbon. The body
        // keeps the stroke colour. The noise still wobbles the edge.
        let core = min(1, pigment * (0.34 + 0.08 * (1 - darkening)) * strokeOpacity)
        var pieces = [
            RibbonPiece(
                path: ribbon(stations, closed: line.isClosed, join: brush.join, miterLimit: miterLimit),
                opacity: core,
                t: 0.5
            )
        ]
        if edged {
            pieces.append(contentsOf: brokenRim(
                stations: stations,
                pigment: pigment * strokeOpacity,
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
            // The body ribbon owns the join. A rim across that corner stacks a dark chord.
            if start.cornerIncoming != nil || end.cornerIncoming != nil { continue }
            let gate = SeededNoise.unit(at: Float(start.t * 3.4), seed: seed &+ 71)
            let flicker = SeededNoise.unit(at: Float(start.t * 9.5), seed: seed &+ 93)
            let presence = max(0, (CGFloat(gate) - 0.22) / 0.78) * (0.25 + 0.75 * CGFloat(flicker))
            if presence < 0.18 { continue }
            let pool = CGFloat(SeededNoise.unit(at: Float(start.t * 5.1), seed: seed &+ 5))
            let opacity = min(1, pigment * (0.12 + 0.7 * darkening) * presence * (0.35 + 1.2 * pool))
            for side: CGFloat in [1, -1] {
                let turn = (start.curvature + end.curvature) * 0.5
                let inside: CGFloat = turn > 0.02 ? 1 : (turn < -0.02 ? -1 : 0)
                // A dark rim in the crotch of a bend is the crease at the peak.
                if inside != 0, side == inside, abs(turn) > 0.045 { continue }
                let sidePool = side > 0 ? opacity : opacity * (0.55 + 0.45 * pool)
                pieces.append(contentsOf: sideRim(start, end, side: side, presence: presence, opacity: sidePool))
            }
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
        let startDepth = min(startHalf * 0.62, startHalf * (0.1 + 0.28 * presence))
        let endDepth = min(endHalf * 0.62, endHalf * (0.1 + 0.28 * presence))
        let startMid = mix(startOuter, start.center, startDepth / startHalf)
        let endMid = mix(endOuter, end.center, endDepth / endHalf)
        let startDeep = mix(startOuter, start.center, min(0.7, startDepth * 2.4 / startHalf))
        let endDeep = mix(endOuter, end.center, min(0.7, endDepth * 2.4 / endHalf))
        return [
            RibbonPiece(path: quad(startOuter, endOuter, endMid, startMid), opacity: opacity, t: start.t),
            RibbonPiece(path: quad(startMid, endMid, endDeep, startDeep), opacity: opacity * 0.55, t: start.t)
        ]
    }

    /// The wash as one shape. The cap meets the real edge points so a peak does not pinch.
    private static func ribbon(
        _ stations: [Station],
        closed: Bool,
        join: BrushJoin,
        miterLimit: CGFloat
    ) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        guard let first = stations.first, let last = stations.last else { return path }
        let leftEdge = contour(stations, left: true, join: join, miterLimit: miterLimit)
        let rightEdge = contour(stations, left: false, join: join, miterLimit: miterLimit)
        guard let leftFirst = leftEdge.first, let rightFirst = rightEdge.first, let rightLast = rightEdge.last else {
            return path
        }
        path.move(to: leftFirst)
        for point in leftEdge.dropFirst() {
            path.addLine(to: point)
        }
        if !closed {
            addCap(to: &path, from: leftEdge.last ?? last.outerLeft, center: last.center, to: rightLast, forward: last.forward)
        } else {
            path.addLine(to: rightLast)
        }
        for point in rightEdge.dropLast().reversed() {
            path.addLine(to: point)
        }
        if !closed {
            addCap(to: &path, from: rightFirst, center: first.center, to: leftFirst, forward: first.forward + .pi)
        }
        path.closeSubpath()
        return path
    }

    /// One offset edge in forward order. Corners insert the shared join.
    /// A station that is not a corner contributes its offset point, as before.
    private static func contour(
        _ stations: [Station],
        left: Bool,
        join: BrushJoin,
        miterLimit: CGFloat
    ) -> [CGPoint] {
        guard let first = stations.first else { return [] }
        var points = [left ? first.outerLeft : first.outerRight]
        var index = 1
        while index < stations.count {
            let here = stations[index]
            if let incoming = here.cornerIncoming, let outgoing = here.cornerOutgoing, index + 1 < stations.count {
                let next = stations[index + 1]
                let lines = StrokeJoinGeometry.sidePolylines(
                    vertex: here.center,
                    incomingTangent: incoming,
                    outgoingTangent: outgoing,
                    incomingHalf: stations[index - 1].outerRadius,
                    outgoingHalf: next.outerRadius,
                    join: join,
                    miterLimit: miterLimit
                )
                points.append(contentsOf: left ? lines.left : lines.right)
                points.append(left ? next.outerLeft : next.outerRight)
                index += 2
                continue
            }
            points.append(left ? here.outerLeft : here.outerRight)
            index += 1
        }
        return points
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

    /// Soft blooms just outside a bulging edge. They stay faint so they feather
    /// into the paper instead of reading as a dark spot.
    private static func feathers(
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        strokeOpacity: CGFloat
    ) -> [RibbonPiece] {
        let center = smoothedCenterline(line.samples, closed: line.isClosed)
        guard center.count >= 2 else { return [] }
        let amount = CGFloat(style.bleed) * 0.7 + CGFloat(style.variation) * 0.55
        guard amount > 0.05 else { return [] }
        var pieces: [RibbonPiece] = []
        let count = 5
        for index in 0..<count {
            let seed = style.seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15 &+ 200
            let along = CGFloat(SeededNoise.unit(at: Float(index), seed: seed))
            let t = line.isClosed ? along : 0.14 + along * 0.72
            let side: CGFloat = SeededNoise.unit(at: Float(index), seed: seed &+ 9) > 0.5 ? 1 : -1
            let size = CGFloat(SeededNoise.unit(at: Float(index), seed: seed &+ 17))
            let sample = sampleCenter(center, at: t)
            let located = StrokeCenterSample(point: sample.point, tangent: sample.forward, t: sample.t)
            let half = halfWidth(at: located, forward: sample.forward, width: width, brush: brush, style: style, layer: 0, line: line)
            let wobble = edgeWobble(at: sample.t, side: side, width: width, style: style, layer: 0, closed: line.isClosed)
            let edge = max(half * 0.45, half + wobble)
            let radius = half * (0.2 + 0.14 * size)
            // Sit on the outline so most of the bloom overlaps the body.
            let reach = edge - radius * 0.35
            let normal = sample.forward + .pi / 2
            let dot = CGPoint(
                x: sample.point.x + cos(normal) * side * reach,
                y: sample.point.y + sin(normal) * side * reach
            )
            let opacity = min(0.5, CGFloat(style.pigment) * strokeOpacity * (0.4 + 0.18 * size))
            pieces.append(RibbonPiece(
                path: bleedBlob(center: dot, radius: radius, seed: seed),
                opacity: opacity,
                t: sample.t
            ))
        }
        return pieces
    }

    /// A lumpy puddle, not a circle, so a bleed reads as wet pigment.
    private static func bleedBlob(center: CGPoint, radius: CGFloat, seed: UInt64) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        let count = 14
        for index in 0...count {
            let angle = CGFloat(index) / CGFloat(count) * 2 * .pi
            let noise = 0.72 + 0.5 * CGFloat(SeededNoise.unit(at: Float(index) * 0.73, seed: seed &+ UInt64(index)))
            let lump = 0.85 + 0.22 * sin(angle * 3 + CGFloat(seed % 7))
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

    /// Fine grain inside the ribbon.
    ///
    /// Each speck takes its position from a hashed index, not from a regular
    /// step along the centreline, so the dots do not line up like stitches.
    /// A few of them bring one or two neighbours. All of them stay small.
    private static func granules(
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        strokeOpacity: CGFloat
    ) -> [RibbonPiece] {
        let center = smoothedCenterline(line.samples, closed: line.isClosed)
        guard center.count >= 2 else { return [] }
        var pieces: [RibbonPiece] = []
        let speckCount = 11 + Int((CGFloat(style.variation) * 6).rounded())
        for index in 0..<speckCount {
            let seed = style.seed &+ UInt64(index) &* 0x9E37_79B9_7F4A_7C15
            let along = CGFloat(SeededNoise.unit(at: Float(index), seed: seed &+ 41))
            let across = CGFloat(SeededNoise.signed(at: CGFloat(index), seed: seed &+ 87))
            let size = CGFloat(SeededNoise.unit(at: Float(index), seed: seed &+ 13))
            let tone = CGFloat(SeededNoise.unit(at: Float(index), seed: seed &+ 59))
            let t = line.isClosed ? along : 0.07 + along * 0.86
            placeSpeck(
                t: t,
                across: across,
                size: size,
                tone: tone,
                radiusScale: 1,
                center: center,
                width: width,
                brush: brush,
                style: style,
                strokeOpacity: strokeOpacity,
                line: line,
                into: &pieces
            )
            let cluster = SeededNoise.unit(at: Float(index), seed: seed &+ 101)
            guard cluster > 0.78 else { continue }
            for mate in 0..<2 {
                let mateSeed = seed &+ UInt64(mate + 1) &* 0xBF58_476D_1CE4_E5B9
                let alongJitter = CGFloat(SeededNoise.signed(at: CGFloat(mate + 1), seed: mateSeed)) * 0.03
                let acrossJitter = CGFloat(SeededNoise.signed(at: CGFloat(mate + 5), seed: mateSeed &+ 7))
                let mateSize = CGFloat(SeededNoise.unit(at: Float(mate + 2), seed: mateSeed &+ 3))
                placeSpeck(
                    t: min(0.94, max(0.06, t + alongJitter)),
                    across: min(1, max(-1, across * 0.55 + acrossJitter * 0.45)),
                    size: mateSize,
                    tone: tone * 0.85,
                    radiusScale: 0.65,
                    center: center,
                    width: width,
                    brush: brush,
                    style: style,
                    strokeOpacity: strokeOpacity,
                    line: line,
                    into: &pieces
                )
            }
        }
        return pieces
    }

    /// One speck. `across` is -1...1 of the local half-width.
    private static func placeSpeck(
        t: CGFloat,
        across: CGFloat,
        size: CGFloat,
        tone: CGFloat,
        radiusScale: CGFloat,
        center: [SmoothSample],
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        strokeOpacity: CGFloat,
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        into pieces: inout [RibbonPiece]
    ) {
        let sample = sampleCenter(center, at: t)
        let located = StrokeCenterSample(point: sample.point, tangent: sample.forward, t: sample.t)
        let half = halfWidth(at: located, forward: sample.forward, width: width, brush: brush, style: style, layer: 2, line: line)
        let radius = half * (0.04 + 0.07 * size) * radiusScale
        guard radius >= 0.3 else { return }
        let normal = sample.forward + .pi / 2
        let reach = across * half * 0.62
        let dot = CGPoint(
            x: sample.point.x + cos(normal) * reach,
            y: sample.point.y + sin(normal) * reach
        )
        let fade = line.isClosed ? 1 : tipScale(sample.t)
        let profile = alongOpacity(sample.t, closed: line.isClosed, brush: brush, strokeOpacity: strokeOpacity)
        let opacity = CGFloat(style.pigment) * profile * fade * (0.12 + 0.16 * tone) * radiusScale
        pieces.append(RibbonPiece(path: ellipse(center: dot, radius: radius), opacity: min(1, opacity), t: sample.t))
    }

    /// Centreline sample at `t`, interpolated so a speck is not stuck to a station.
    private static func sampleCenter(_ center: [SmoothSample], at t: CGFloat) -> SmoothSample {
        guard center.count >= 2 else { return center[0] }
        if t <= center[0].t { return center[0] }
        if t >= center[center.count - 1].t { return center[center.count - 1] }
        var low = 0
        var high = center.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if center[mid].t < t { low = mid } else { high = mid }
        }
        let start = center[low]
        let end = center[high]
        let span = max(0.0001, end.t - start.t)
        let u = min(1, max(0, (t - start.t) / span))
        let forward = atan2(
            sin(start.forward) * (1 - u) + sin(end.forward) * u,
            cos(start.forward) * (1 - u) + cos(end.forward) * u
        )
        return SmoothSample(
            point: CGPoint(
                x: start.point.x + (end.point.x - start.point.x) * u,
                y: start.point.y + (end.point.y - start.point.y) * u
            ),
            t: t,
            forward: forward,
            curvature: start.curvature * (1 - u) + end.curvature * u,
            radius: start.radius * (1 - u) + end.radius * u
        )
    }

    /// One smoothed centreline, then a parallel ribbon.
    ///
    /// Rough jitter is averaged out before the normals are taken, so a tight
    /// bend does not throw the edge into a saw tooth. Only the inside of a
    /// real bend is shortened, and that limit follows the smoothed curvature.
    private static func stations(
        line: (samples: [StrokeCenterSample], isClosed: Bool),
        width: CGFloat,
        brush: BrushProfile,
        style: WatercolorStyle,
        layer: Int
    ) -> [Station] {
        let center = smoothedCenterline(line.samples, closed: line.isClosed)
        guard center.count >= 2 else { return [] }
        let halves = smoothScalars(
            center.map { sample in
                let located = StrokeCenterSample(point: sample.point, tangent: sample.forward, t: sample.t)
                return halfWidth(
                    at: located,
                    forward: sample.forward,
                    width: width,
                    brush: brush,
                    style: style,
                    layer: layer,
                    line: line
                )
            },
            reach: 6,
            closed: line.isClosed
        )
        var lefts = halves
        var rights = halves
        for index in center.indices {
            let half = halves[index]
            let sample = center[index]
            // Pull the inside back only where the offset would cross, then
            // smooth that pull so the peak does not fold into a dark triangle.
            guard sample.radius < half * 1.05 else { continue }
            let limit = max(half * 0.72, sample.radius * 0.92)
            if sample.curvature > 0 {
                lefts[index] = min(half, limit)
            } else if sample.curvature < 0 {
                rights[index] = min(half, limit)
            }
        }
        lefts = smoothScalars(lefts, reach: 8, closed: line.isClosed)
        rights = smoothScalars(rights, reach: 8, closed: line.isClosed)
        let built = center.enumerated().map { index, sample -> Station in
            var left = lefts[index]
            var right = rights[index]
            // Layer 0 is the ragged body. Later glazes share that edge and only
            // step a little past it on both sides, so a pale layer cannot drift
            // off and read as a drop shadow.
            let leftWobble = edgeWobble(at: sample.t, side: 1, width: width, style: style, layer: 0, closed: line.isClosed)
            let rightWobble = edgeWobble(at: sample.t, side: -1, width: width, style: style, layer: 0, closed: line.isClosed)
            if layer == 0 {
                left += leftWobble
                right += rightWobble
            } else {
                let flutter = signed(
                    sample.t,
                    cycles: 11,
                    seed: style.seed &+ UInt64(layer) &* 23,
                    closed: line.isClosed
                ) * width * 0.012
                let step = width * 0.012 * CGFloat(layer) + flutter
                left += leftWobble + step
                right += rightWobble + step
            }
            left = max(0.35, left)
            right = max(0.35, right)
            let normalAngle = sample.forward + .pi / 2
            let nx = cos(normalAngle)
            let ny = sin(normalAngle)
            let point = sample.point
            let innerScale = 1 - 0.22 * CGFloat(style.edgeDarkening)
            return Station(
                center: point,
                forward: sample.forward,
                outerLeft: CGPoint(x: point.x + nx * left, y: point.y + ny * left),
                outerRight: CGPoint(x: point.x - nx * right, y: point.y - ny * right),
                innerLeft: CGPoint(x: point.x + nx * left * innerScale, y: point.y + ny * left * innerScale),
                innerRight: CGPoint(x: point.x - nx * right * innerScale, y: point.y - ny * right * innerScale),
                outerRadius: max(left, right),
                innerRadius: max(left, right) * innerScale,
                curvature: sample.curvature,
                t: sample.t,
                cornerIncoming: sample.cornerIncoming,
                cornerOutgoing: sample.cornerOutgoing
            )
        }
        return built
    }

    /// Irregular wet edge. Low-frequency drift, a smaller ripple, and an
    /// occasional outward bleed. Amplitude follows `bleed` and `variation`
    /// and the stroke width. It fades out through the tip taper.
    private static func edgeWobble(
        at t: CGFloat,
        side: CGFloat,
        width: CGFloat,
        style: WatercolorStyle,
        layer: Int,
        closed: Bool
    ) -> CGFloat {
        let amount = CGFloat(style.bleed) * 0.7 + CGFloat(style.variation) * 0.55
        guard amount > 0.02 else { return 0 }
        let seed = style.seed &+ UInt64(layer) &* 19 &+ (side > 0 ? 5 : 31)
        // Several bumps along the stroke, not one swell that fattens a whole arm.
        let low = signed(t, cycles: 4.2, seed: seed, closed: closed)
        let mid = signed(t, cycles: 8.5, seed: seed &+ 13, closed: closed)
        let high = signed(t, cycles: 15, seed: seed &+ 27, closed: closed)
        var wobble = (low * 0.55 + mid * 0.32 + high * 0.28) * width * 0.42 * amount
        let gate = SeededNoise.unit(at: Float(t * 6.5 + (side > 0 ? 0.4 : 1.7)), seed: seed &+ 47)
        if gate > 0.66 {
            let bulge = (CGFloat(gate) - 0.66) / 0.34
            wobble += bulge * width * 0.28 * amount
        }
        let dry = SeededNoise.unit(at: Float(t * 8.4 + (side > 0 ? 0.2 : 2.4)), seed: seed &+ 90)
        if dry < 0.28 {
            wobble -= width * 0.22 * amount * CGFloat((0.28 - dry) / 0.28)
        }
        let inward = -width * 0.2 * amount
        if wobble < inward { wobble = inward }
        let fade = closed ? 1 : tipFade(t)
        return wobble * fade
    }

    /// 0 at the tip, 1 once the taper is over, so the round end stays smooth.
    private static func tipFade(_ t: CGFloat) -> CGFloat {
        let edge = min(max(0, t), max(0, 1 - t))
        let window: CGFloat = 0.2
        guard edge < window else { return 1 }
        let mix = edge / window
        return mix * mix * (3 - 2 * mix)
    }

    /// Averages the centreline in point space, then takes one stable tangent.
    private static func smoothedCenterline(
        _ samples: [StrokeCenterSample],
        closed: Bool
    ) -> [SmoothSample] {
        let pins = sharpCornerPins(samples, closed: closed)
        if !pins.isEmpty {
            return smoothPinnedCenterline(samples, pins: pins, closed: closed)
        }
        return smoothWholeCenterline(samples, closed: closed)
    }

    /// Indices where the raw polyline turns hard enough to be a join, not a curve.
    private static func sharpCornerPins(_ samples: [StrokeCenterSample], closed: Bool) -> [(index: Int, incoming: CGFloat, outgoing: CGFloat)] {
        let count = samples.count
        guard count >= 3 else { return [] }
        var pins: [(index: Int, incoming: CGFloat, outgoing: CGFloat)] = []
        let start = closed ? 0 : 1
        let end = closed ? count : count - 1
        for index in start..<end {
            let previous = samples[(index - 1 + count) % count].point
            let here = samples[index].point
            let next = samples[(index + 1) % count].point
            let incoming = atan2(here.y - previous.y, here.x - previous.x)
            let outgoing = atan2(next.y - here.y, next.x - here.x)
            if abs(StrokeJoinGeometry.signedAngleDelta(incoming, outgoing)) >= 0.45 {
                pins.append((index, incoming, outgoing))
            }
        }
        return pins
    }

    /// Smooths each arm on its own and keeps the corner point, with the real tangents.
    private static func smoothPinnedCenterline(
        _ samples: [StrokeCenterSample],
        pins: [(index: Int, incoming: CGFloat, outgoing: CGFloat)],
        closed: Bool
    ) -> [SmoothSample] {
        var anchors = pins.map(\.index)
        if !closed {
            if anchors.first != 0 { anchors.insert(0, at: 0) }
            if anchors.last != samples.count - 1 { anchors.append(samples.count - 1) }
        }
        var result: [SmoothSample] = []
        if closed {
            for pinIndex in pins.indices {
                let start = pins[pinIndex]
                let end = pins[(pinIndex + 1) % pins.count]
                let span = spanSamples(samples, from: start.index, to: end.index)
                var smoothed = smoothWholeCenterline(span, closed: false)
                snapEnds(&smoothed, first: span[0].point, last: span[span.count - 1].point)
                if pinIndex == 0, !smoothed.isEmpty {
                    smoothed[0].cornerIncoming = start.incoming
                    smoothed[0].cornerOutgoing = start.outgoing
                }
                if pinIndex < pins.count - 1, let last = smoothed.indices.last {
                    smoothed[last].cornerIncoming = end.incoming
                    smoothed[last].cornerOutgoing = end.outgoing
                }
                if pinIndex > 0 { smoothed.removeFirst() }
                result.append(contentsOf: smoothed)
            }
            if !result.isEmpty { result.removeLast() }
            return result
        }
        for index in 0..<(anchors.count - 1) {
            let start = anchors[index]
            let end = anchors[index + 1]
            let span = Array(samples[start...end])
            var smoothed = smoothWholeCenterline(span, closed: false)
            snapEnds(&smoothed, first: span[0].point, last: span[span.count - 1].point)
            if index > 0 { smoothed.removeFirst() }
            if let pin = pins.first(where: { $0.index == end }), let last = smoothed.indices.last, end != samples.count - 1 {
                smoothed[last].cornerIncoming = pin.incoming
                smoothed[last].cornerOutgoing = pin.outgoing
            }
            result.append(contentsOf: smoothed)
        }
        return result
    }

    private static func spanSamples(_ samples: [StrokeCenterSample], from start: Int, to end: Int) -> [StrokeCenterSample] {
        if start <= end { return Array(samples[start...end]) }
        return Array(samples[start...]) + Array(samples[0...end])
    }

    private static func snapEnds(_ samples: inout [SmoothSample], first: CGPoint, last: CGPoint) {
        guard !samples.isEmpty else { return }
        samples[0].point = first
        samples[samples.count - 1].point = last
        let forwards = stableForwards(samples.map(\.point), closed: false)
        let curvatures = smoothScalars(
            signedCurvatures(points: samples.map(\.point), forwards: forwards, closed: false),
            reach: 4,
            closed: false
        )
        for index in samples.indices {
            samples[index].forward = forwards[index]
            let curvature = curvatures[index]
            samples[index].curvature = curvature
            samples[index].radius = 1 / max(0.0004, abs(curvature))
        }
    }

    private static func smoothWholeCenterline(
        _ samples: [StrokeCenterSample],
        closed: Bool
    ) -> [SmoothSample] {
        guard samples.count >= 2 else { return [] }
        let spacing: CGFloat = 2
        var curve = resample(
            points: samples.map(\.point),
            times: samples.map(\.t),
            spacing: spacing,
            closed: closed
        )
        guard curve.count >= 2 else { return [] }
        for _ in 0..<3 {
            curve = averageCurve(curve, reach: 5, closed: closed)
        }
        curve = resample(points: curve.map(\.point), times: curve.map(\.t), spacing: spacing, closed: closed)
        curve = averageCurve(curve, reach: 3, closed: closed)
        guard curve.count >= 2 else { return [] }
        let forwards = stableForwards(curve.map(\.point), closed: closed)
        let curvatures = smoothScalars(
            signedCurvatures(points: curve.map(\.point), forwards: forwards, closed: closed),
            reach: 4,
            closed: closed
        )
        // Parameter `t` from the rough curve is not distance. The start of this
        // stroke packed that parameter, so the tip taper finished in a few
        // points and the cap read as a flat nub. Arc length makes both tips
        // the same length.
        let times = arcLengthParameters(curve.map(\.point), closed: closed)
        return curve.indices.map { index in
            let curvature = curvatures[index]
            return SmoothSample(
                point: curve[index].point,
                t: times[index],
                forward: forwards[index],
                curvature: curvature,
                radius: 1 / max(0.0004, abs(curvature))
            )
        }
    }

    /// `0` at the start and `1` at the end, measured along the polyline.
    private static func arcLengthParameters(_ points: [CGPoint], closed: Bool) -> [CGFloat] {
        guard points.count >= 2 else { return points.map { _ in 0 } }
        var lengths: [CGFloat] = [0]
        let segments = closed ? points.count : points.count - 1
        for index in 0..<segments {
            let next = (index + 1) % points.count
            lengths.append(lengths[lengths.count - 1] + hypot(points[next].x - points[index].x, points[next].y - points[index].y))
        }
        let total = max(lengths[lengths.count - 1], 0.0001)
        if closed {
            return (0..<points.count).map { lengths[$0] / total }
        }
        return lengths.map { $0 / total }
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
        _ = style
        _ = layer
        // The brush records a thickness wobble, but that noise is one slow
        // swell. On the catalog seed it peaks at the start and shrinks toward
        // the middle, which paints a teardrop. The wash stays an even ribbon.
        // `tipScale` is the only along-stroke width change, and it matches at
        // both ends.
        let tip = brush.tip.effectiveWidth(baseWidth: width, strokeAngle: forward)
        let end = line.isClosed ? 1 : tipScale(sample.t)
        return max(0.2, tip * 0.5 * end)
    }

    private static func neighbor(_ index: Int, count: Int, closed: Bool) -> Int {
        if closed {
            return (index % count + count) % count
        }
        return min(count - 1, max(0, index))
    }

    /// Even steps along the polyline so the smooth window is a distance, not a sample count.
    private static func resample(
        points: [CGPoint],
        times: [CGFloat],
        spacing: CGFloat,
        closed: Bool
    ) -> [CurvePoint] {
        guard points.count >= 2, points.count == times.count else { return [] }
        let segments = closed ? points.count : points.count - 1
        var lengths: [CGFloat] = [0]
        for index in 0..<segments {
            let next = (index + 1) % points.count
            lengths.append(lengths[lengths.count - 1] + hypot(points[next].x - points[index].x, points[next].y - points[index].y))
        }
        let total = lengths[lengths.count - 1]
        guard total > spacing else {
            return zip(points, times).map { CurvePoint(point: $0.0, t: $0.1) }
        }
        var result: [CurvePoint] = []
        var cursor: CGFloat = 0
        var segment = 0
        let limit = closed ? total - spacing * 0.5 : total
        while cursor <= limit + 0.001 {
            while segment < segments - 1, lengths[segment + 1] < cursor {
                segment += 1
            }
            let span = max(0.0001, lengths[segment + 1] - lengths[segment])
            let u = min(1, max(0, (cursor - lengths[segment]) / span))
            let next = (segment + 1) % points.count
            result.append(CurvePoint(
                point: CGPoint(
                    x: points[segment].x + (points[next].x - points[segment].x) * u,
                    y: points[segment].y + (points[next].y - points[segment].y) * u
                ),
                t: times[segment] + (times[next] - times[segment]) * u
            ))
            cursor += spacing
        }
        if !closed, let last = result.last {
            let end = points[points.count - 1]
            if hypot(last.point.x - end.x, last.point.y - end.y) > spacing * 0.35 {
                result.append(CurvePoint(point: end, t: times[times.count - 1]))
            } else {
                result[result.count - 1] = CurvePoint(point: end, t: times[times.count - 1])
            }
        }
        return result
    }

    /// Moving average. Mirror padding keeps a straight end from hooking, and the
    /// raw endpoint is included so a jittered start is pulled onto the stroke.
    private static func averageCurve(_ curve: [CurvePoint], reach: Int, closed: Bool) -> [CurvePoint] {
        guard curve.count >= 3, reach > 0 else { return curve }
        return curve.indices.map { index in
            var x: CGFloat = 0
            var y: CGFloat = 0
            var t: CGFloat = 0
            var weight: CGFloat = 0
            for offset in -reach...reach {
                let sample = reflected(curve, index: index + offset, closed: closed)
                let influence = 1 - abs(CGFloat(offset)) / CGFloat(reach + 1)
                x += sample.point.x * influence
                y += sample.point.y * influence
                t += sample.t * influence
                weight += influence
            }
            return CurvePoint(point: CGPoint(x: x / weight, y: y / weight), t: t / weight)
        }
    }

    private static func reflected(_ curve: [CurvePoint], index: Int, closed: Bool) -> CurvePoint {
        let count = curve.count
        if closed {
            return curve[(index % count + count) % count]
        }
        if index >= 0, index < count {
            return curve[index]
        }
        if index < 0 {
            let source = min(count - 1, -index)
            let end = curve[0]
            let other = curve[source]
            return CurvePoint(
                point: CGPoint(x: end.point.x * 2 - other.point.x, y: end.point.y * 2 - other.point.y),
                t: end.t
            )
        }
        let source = max(0, 2 * (count - 1) - index)
        let end = curve[count - 1]
        let other = curve[source]
        return CurvePoint(
            point: CGPoint(x: end.point.x * 2 - other.point.x, y: end.point.y * 2 - other.point.y),
            t: end.t
        )
    }

    /// Chord direction, averaged as a vector so the angle does not flip at ±π.
    private static func stableForwards(_ points: [CGPoint], closed: Bool) -> [CGFloat] {
        let count = points.count
        guard count >= 2 else { return [0] }
        let reach = min(6, max(1, count / 8))
        let raw = (0..<count).map { index -> CGFloat in
            let before = reflectedPoint(points, index: index - reach, closed: closed)
            let after = reflectedPoint(points, index: index + reach, closed: closed)
            return atan2(after.y - before.y, after.x - before.x)
        }
        let window = 3
        var angles = (0..<count).map { index -> CGFloat in
            var sx: CGFloat = 0
            var sy: CGFloat = 0
            for offset in -window...window {
                let sample = closed
                    ? ((index + offset) % count + count) % count
                    : min(count - 1, max(0, index + offset))
                let influence = 1 - abs(CGFloat(offset)) / CGFloat(window + 1)
                sx += cos(raw[sample]) * influence
                sy += sin(raw[sample]) * influence
            }
            if sx * sx + sy * sy < 0.0001 {
                return raw[index]
            }
            return atan2(sy, sx)
        }
        guard !closed, count > 2 else { return angles }
        // The tip direction is the chord leaving the end, not a reflected
        // neighbour. A flipped start tangent offsets the width along the
        // stroke and flattens the cap.
        let look = min(8, count - 1)
        let startAngle = atan2(points[look].y - points[0].y, points[look].x - points[0].x)
        let endIndex = count - 1
        let endAngle = atan2(
            points[endIndex].y - points[endIndex - look].y,
            points[endIndex].x - points[endIndex - look].x
        )
        for index in 0..<count {
            let startWeight = max(0, 1 - CGFloat(index) / CGFloat(look))
            let endWeight = max(0, 1 - CGFloat(endIndex - index) / CGFloat(look))
            if startWeight > 0 {
                angles[index] = blendAngle(angles[index], toward: startAngle, amount: startWeight)
            }
            if endWeight > 0 {
                angles[index] = blendAngle(angles[index], toward: endAngle, amount: endWeight)
            }
        }
        return angles
    }

    private static func blendAngle(_ angle: CGFloat, toward target: CGFloat, amount: CGFloat) -> CGFloat {
        let keep = 1 - amount
        return atan2(sin(angle) * keep + sin(target) * amount, cos(angle) * keep + cos(target) * amount)
    }

    private static func reflectedPoint(_ points: [CGPoint], index: Int, closed: Bool) -> CGPoint {
        let count = points.count
        if closed {
            return points[(index % count + count) % count]
        }
        if index >= 0, index < count {
            return points[index]
        }
        if index < 0 {
            let source = min(count - 1, -index)
            return CGPoint(x: points[0].x * 2 - points[source].x, y: points[0].y * 2 - points[source].y)
        }
        let source = max(0, 2 * (count - 1) - index)
        let end = points[count - 1]
        return CGPoint(x: end.x * 2 - points[source].x, y: end.y * 2 - points[source].y)
    }

    /// Signed turn, radians per point. Positive turns left.
    private static func signedCurvatures(
        points: [CGPoint],
        forwards: [CGFloat],
        closed: Bool
    ) -> [CGFloat] {
        let count = points.count
        let reach = min(5, max(1, count / 10))
        return (0..<count).map { index in
            let before = closed ? (index - reach + count) % count : max(0, index - reach)
            let after = closed ? (index + reach) % count : min(count - 1, index + reach)
            var delta = forwards[after] - forwards[before]
            while delta > .pi { delta -= 2 * .pi }
            while delta < -.pi { delta += 2 * .pi }
            let distance = max(1, hypot(points[after].x - points[before].x, points[after].y - points[before].y))
            return delta / distance
        }
    }

    private static func smoothScalars(_ values: [CGFloat], reach: Int, closed: Bool) -> [CGFloat] {
        guard values.count >= 3, reach > 0 else { return values }
        return values.indices.map { index in
            if !closed, index == 0 || index == values.count - 1 {
                return values[index]
            }
            var sum: CGFloat = 0
            var weight: CGFloat = 0
            for offset in -reach...reach {
                let sample = neighbor(index + offset, count: values.count, closed: closed)
                let influence = 1 - abs(CGFloat(offset)) / CGFloat(reach + 1)
                sum += values[sample] * influence
                weight += influence
            }
            return sum / weight
        }
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

    private static func ellipse(center: CGPoint, radius: CGFloat) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        return path
    }

    /// Open strokes narrow into a round tip instead of a square cut.
    private static func tipScale(_ t: CGFloat) -> CGFloat {
        let window: CGFloat = 0.2
        let edge = min(max(0, t), max(0, 1 - t))
        if edge >= window { return 1 }
        let mix = edge / window
        let smooth = mix * mix * (3 - 2 * mix)
        return 0.72 + 0.28 * smooth
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

/// One point on the smoothed centreline.
private struct CurvePoint {
    var point: CGPoint
    var t: CGFloat
}

/// Centreline sample after smoothing, with a stable tangent and turn.
private struct SmoothSample {
    var point: CGPoint
    var t: CGFloat
    var forward: CGFloat
    var curvature: CGFloat
    var radius: CGFloat
    var cornerIncoming: CGFloat? = nil
    var cornerOutgoing: CGFloat? = nil
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
        var curvature: CGFloat
        var t: CGFloat
        var cornerIncoming: CGFloat? = nil
        var cornerOutgoing: CGFloat? = nil
}
