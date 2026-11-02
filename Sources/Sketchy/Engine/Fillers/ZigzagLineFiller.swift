//
//  ZigzagLineFiller.swift
//  RoughSwift
//
//  Zigzag line fill pattern generator - each hachure line is a zigzag.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates zigzag-line fill patterns (each hachure line is itself a zigzag).
public struct ZigzagLineFiller: FillGenerator {

    private let hachureFiller = HachureFiller()

    public init() {}

    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        if options.seed != nil && !RoughRandom.isActive {
            return RoughRandom.with(seed: options.seed) {
                fillPolygon(points: points, options: options)
            }
        }
        let gap = max(options.computedHachureGap, options.strokeWidth * 4)
        var zigOptions = options
        zigOptions.fillSpacing = (gap + zigzagOffset(options: options)) / options.effectiveFillWeight

        let lines = hachureFiller.hachureLines(points: points, options: zigOptions)
        let ops = ZigzagLineGeometry.operations(
            for: lines,
            zigOffset: zigzagOffset(options: options),
            options: options,
            boundary: .polygon(points)
        )
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }

    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        if options.seed != nil && !RoughRandom.isActive {
            return RoughRandom.with(seed: options.seed) {
                fillEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
            }
        }
        let gap = max(options.computedHachureGap, options.strokeWidth * 4)
        var zigOptions = options
        zigOptions.fillSpacing = (gap + zigzagOffset(options: options)) / options.effectiveFillWeight

        let lines = hachureFiller.hachureEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: zigOptions)
        let ops = ZigzagLineGeometry.operations(
            for: lines,
            zigOffset: zigzagOffset(options: options),
            options: options,
            boundary: .ellipse(cx: cx, cy: cy, rx: rx, ry: ry)
        )
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }

    // MARK: - Zigzag Generation

    private func zigzagOffset(options: Options) -> Float {
        if options.zigzagOffset < 0 {
            return options.computedHachureGap < 0 ? options.strokeWidth * 4 : options.computedHachureGap
        }
        return options.zigzagOffset
    }
}

/// Centers a sawtooth on each hachure chord and clips it to the shape.
///
/// A tooth keeps the previous pitch of `2 * zigOffset`: a slanted ramp, then a
/// perpendicular drop. The ramp runs from `-zigOffset / 2` to `+zigOffset / 2`
/// across the chord instead of sitting a full `zigOffset` on one side. The old
/// peak was also one extra `zigOffset` along the chord, so the last tooth could
/// stick past the chord's end. Whole teeth are fitted with `floor`, and any
/// leftover length is split across the two ends.
private enum ZigzagLineGeometry {

    enum Boundary {
        case polygon([[Float]])
        case ellipse(cx: Float, cy: Float, rx: Float, ry: Float)
    }

    /// Pulls tooth spans slightly inside the solved boundary so float error
    /// cannot leave a vertex on the outside of the outline.
    private static let boundaryPad: Float = 0.2

    private struct Interval {
        var lo: Float
        var hi: Float

        var span: Float { hi - lo }
    }

    private struct LineFrame {
        var startX: Float
        var startY: Float
        var dirX: Float
        var dirY: Float
        var normalX: Float
        var normalY: Float
        var length: Float

        /// Point on the chord at `t`, shifted by `side` along the normal.
        func point(at t: Float, side: Float) -> (x: Float, y: Float) {
            (
                x: startX + t * dirX + side * normalX,
                y: startY + t * dirY + side * normalY
            )
        }

        /// Orients the chord left to right so every sawtooth leans the same way.
        init?(_ line: FillLine) {
            var start = line.start
            var end = line.end
            guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite else { return nil }
            if start.x > end.x {
                swap(&start, &end)
            }
            let dx = end.x - start.x
            let dy = end.y - start.y
            let chord = sqrt(dx * dx + dy * dy)
            guard chord > 1e-3, chord.isFinite else { return nil }
            let ux = dx / chord
            let uy = dy / chord
            startX = start.x
            startY = start.y
            dirX = ux
            dirY = uy
            normalX = -uy
            normalY = ux
            length = chord
        }
    }

    private struct Tooth {
        var start: (x: Float, y: Float)
        var peak: (x: Float, y: Float)
        var end: (x: Float, y: Float)
    }

    static func operations(
        for lines: [FillLine],
        zigOffset: Float,
        options: Options,
        boundary: Boundary
    ) -> [Operation] {
        var ops: [Operation] = []
        for line in lines {
            appendPattern(
                on: line,
                zigOffset: zigOffset,
                options: options,
                boundary: boundary,
                ops: &ops
            )
        }
        return ops
    }

    // MARK: - One chord

    /// Draws centered teeth where they fit, or the chord itself when they do not.
    private static func appendPattern(
        on line: FillLine,
        zigOffset: Float,
        options: Options,
        boundary: Boundary,
        ops: inout [Operation]
    ) {
        guard let frame = LineFrame(line) else { return }

        let center = insideIntervals(frame: frame, side: 0, boundary: boundary)
        let half = zigOffset / 2
        let pitch = zigOffset * 2
        guard zigOffset.isFinite, zigOffset > 0, pitch.isFinite else {
            appendPlain(frame: frame, intervals: center, boundary: boundary, options: options, ops: &ops)
            return
        }

        let safe = inset(
            intersection(
                insideIntervals(frame: frame, side: half, boundary: boundary),
                insideIntervals(frame: frame, side: -half, boundary: boundary)
            ),
            pad: boundaryPad
        )

        var drewTeeth = false
        for interval in safe {
            let teeth = teethFitting(
                frame: frame,
                interval: interval,
                half: half,
                pitch: pitch,
                boundary: boundary
            )
            if teeth.isEmpty { continue }
            for tooth in teeth {
                appendSegment(from: tooth.start, to: tooth.peak, options: options, ops: &ops)
                appendSegment(from: tooth.peak, to: tooth.end, options: options, ops: &ops)
            }
            drewTeeth = true
        }

        if !drewTeeth {
            appendPlain(frame: frame, intervals: center, boundary: boundary, options: options, ops: &ops)
        }
    }

    /// Straight stand-in for a chord that cannot hold one tooth.
    private static func appendPlain(
        frame: LineFrame,
        intervals: [Interval],
        boundary: Boundary,
        options: Options,
        ops: inout [Operation]
    ) {
        for interval in intervals {
            guard let clipped = containedPlain(frame: frame, interval: interval, boundary: boundary) else {
                continue
            }
            appendSegment(
                from: frame.point(at: clipped.lo, side: 0),
                to: frame.point(at: clipped.hi, side: 0),
                options: options,
                ops: &ops
            )
        }
    }

    private static func appendSegment(
        from start: (x: Float, y: Float),
        to end: (x: Float, y: Float),
        options: Options,
        ops: inout [Operation]
    ) {
        guard start.x.isFinite, start.y.isFinite, end.x.isFinite, end.y.isFinite else { return }
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx * dx + dy * dy < 1e-8 { return }
        ops.append(contentsOf: RoughMath.doubleLineOps(
            x1: start.x, y1: start.y,
            x2: end.x, y2: end.y,
            options: options
        ))
    }

    /// Whole teeth inside `interval`. Leftover length is split across the ends.
    ///
    /// If the solved interval still leaves a vertex outside (polygon clipping
    /// can sit on a vertex), both ends are pulled in until every sample fits.
    private static func teethFitting(
        frame: LineFrame,
        interval: Interval,
        half: Float,
        pitch: Float,
        boundary: Boundary
    ) -> [Tooth] {
        func placed(_ interval: Interval) -> [Tooth]? {
            let span = interval.span
            guard span > 0 else { return nil }
            let count = Int(floor(span / pitch))
            guard count >= 1 else { return nil }
            let margin = max(0, (span - Float(count) * pitch) / 2)
            var teeth: [Tooth] = []
            teeth.reserveCapacity(count)
            for index in 0..<count {
                let startT = interval.lo + margin + Float(index) * pitch
                let endT = startT + pitch
                guard endT <= interval.hi + 1e-3, endT <= frame.length + 1e-3 else { return nil }
                let tooth = Tooth(
                    start: frame.point(at: startT, side: -half),
                    peak: frame.point(at: endT, side: half),
                    end: frame.point(at: endT, side: -half)
                )
                guard samples(of: tooth, startT: startT, endT: endT, half: half, frame: frame)
                    .allSatisfy({ contains($0, boundary: boundary) }) else {
                    return nil
                }
                teeth.append(tooth)
            }
            return teeth
        }

        if let teeth = placed(interval) {
            return teeth
        }

        var insetLow: Float = 0
        var insetHigh = max(0, interval.span / 2)
        var best: [Tooth] = []
        for _ in 0..<20 {
            let mid = (insetLow + insetHigh) / 2
            let shrunk = Interval(lo: interval.lo + mid, hi: interval.hi - mid)
            if let teeth = placed(shrunk) {
                best = teeth
                insetHigh = mid
            } else {
                insetLow = mid
            }
        }
        return best
    }

    /// Vertices plus points along the ramp and the drop. Convex shapes only
    /// need the vertices; the samples also cover a concave notch.
    private static func samples(
        of tooth: Tooth,
        startT: Float,
        endT: Float,
        half: Float,
        frame: LineFrame
    ) -> [(x: Float, y: Float)] {
        let span = endT - startT
        func ramp(_ u: Float) -> (x: Float, y: Float) {
            frame.point(at: startT + span * u, side: half * (2 * u - 1))
        }
        return [
            tooth.start,
            tooth.peak,
            tooth.end,
            ramp(0.33),
            ramp(0.67),
            frame.point(at: endT, side: 0)
        ]
    }

    private static func containedPlain(
        frame: LineFrame,
        interval: Interval,
        boundary: Boundary
    ) -> Interval? {
        func fits(_ interval: Interval) -> Bool {
            let mid = (interval.lo + interval.hi) / 2
            return contains(frame.point(at: interval.lo, side: 0), boundary: boundary)
                && contains(frame.point(at: mid, side: 0), boundary: boundary)
                && contains(frame.point(at: interval.hi, side: 0), boundary: boundary)
        }
        if fits(interval) { return interval }

        var lo = interval.lo
        var hi = interval.hi
        for _ in 0..<16 {
            let span = hi - lo
            if span < 0.5 { return nil }
            lo += span * 0.08
            hi -= span * 0.08
            let shrunk = Interval(lo: lo, hi: hi)
            if fits(shrunk) { return shrunk }
        }
        return nil
    }

    // MARK: - Where a parallel stroke is inside

    /// Parameters `t` where `chord(t) + side * normal` lies inside the shape.
    private static func insideIntervals(
        frame: LineFrame,
        side: Float,
        boundary: Boundary
    ) -> [Interval] {
        let origin = frame.point(at: 0, side: side)
        let direction = (x: frame.dirX, y: frame.dirY)
        switch boundary {
        case let .ellipse(cx, cy, rx, ry):
            guard let interval = ellipseInterval(
                origin: origin,
                direction: direction,
                length: frame.length,
                cx: cx,
                cy: cy,
                rx: rx,
                ry: ry
            ) else {
                return []
            }
            return [interval]
        case let .polygon(points):
            return polygonIntervals(
                origin: origin,
                direction: direction,
                length: frame.length,
                polygon: points
            )
        }
    }

    /// Solves `((x-cx)/rx)^2 + ((y-cy)/ry)^2 <= 1` along a segment.
    ///
    /// The inside set of a line against an ellipse is one interval. Offsetting
    /// the segment by the tooth's perpendicular excursion and intersecting the
    /// two results is the span where the whole ramp stays inside.
    private static func ellipseInterval(
        origin: (x: Float, y: Float),
        direction: (x: Float, y: Float),
        length: Float,
        cx: Float,
        cy: Float,
        rx: Float,
        ry: Float
    ) -> Interval? {
        guard rx > 1e-4, ry > 1e-4, length > 1e-3 else { return nil }
        guard origin.x.isFinite, origin.y.isFinite, direction.x.isFinite, direction.y.isFinite else {
            return nil
        }

        let ox = origin.x - cx
        let oy = origin.y - cy
        let invRx2 = 1 / (rx * rx)
        let invRy2 = 1 / (ry * ry)
        let a = direction.x * direction.x * invRx2 + direction.y * direction.y * invRy2
        let b = 2 * (ox * direction.x * invRx2 + oy * direction.y * invRy2)
        let c = ox * ox * invRx2 + oy * oy * invRy2 - 1
        guard a > 1e-12, a.isFinite, b.isFinite, c.isFinite else { return nil }

        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0, discriminant.isFinite else { return nil }
        let root = sqrt(discriminant)
        let t0 = (-b - root) / (2 * a)
        let t1 = (-b + root) / (2 * a)
        let lo = max(0, min(t0, t1))
        let hi = min(length, max(t0, t1))
        guard hi - lo > 1e-3, lo.isFinite, hi.isFinite else { return nil }
        return Interval(lo: lo, hi: hi)
    }

    /// Inside portions of a segment, using edge hits plus a point-in-polygon test.
    private static func polygonIntervals(
        origin: (x: Float, y: Float),
        direction: (x: Float, y: Float),
        length: Float,
        polygon: [[Float]]
    ) -> [Interval] {
        guard length > 1e-3, polygon.count >= 3 else { return [] }
        guard origin.x.isFinite, origin.y.isFinite else { return [] }

        let end = (
            x: origin.x + direction.x * length,
            y: origin.y + direction.y * length
        )
        let hits = LineHelper.linePolygonIntersections(
            line: (start: (origin.x, origin.y), end: (end.x, end.y)),
            polygon: polygon
        )

        let mergeDistance = max(1e-4, length * 1e-5)
        var parameters: [Float] = []
        for hit in hits {
            guard hit.x.isFinite, hit.y.isFinite else { continue }
            let t = (hit.x - origin.x) * direction.x + (hit.y - origin.y) * direction.y
            guard t.isFinite else { continue }
            parameters.append(min(length, max(0, t)))
        }
        parameters.sort()
        var markers: [Float] = []
        for t in parameters {
            if let last = markers.last, t - last <= mergeDistance { continue }
            markers.append(t)
        }

        if markers.isEmpty || (markers.first ?? 0) > mergeDistance {
            markers.insert(0, at: 0)
        }
        if let last = markers.last, length - last > mergeDistance {
            markers.append(length)
        }

        var intervals: [Interval] = []
        for index in 0..<(markers.count - 1) {
            let lo = markers[index]
            let hi = markers[index + 1]
            guard hi - lo > mergeDistance else { continue }
            let midT = (lo + hi) / 2
            let mid = (
                x: origin.x + direction.x * midT,
                y: origin.y + direction.y * midT
            )
            if contains(mid, boundary: .polygon(polygon)) {
                intervals.append(Interval(lo: lo, hi: hi))
            }
        }
        return intervals
    }

    private static func intersection(_ lhs: [Interval], _ rhs: [Interval]) -> [Interval] {
        var result: [Interval] = []
        for left in lhs {
            for right in rhs {
                let lo = max(left.lo, right.lo)
                let hi = min(left.hi, right.hi)
                if hi - lo > 1e-3 {
                    result.append(Interval(lo: lo, hi: hi))
                }
            }
        }
        return merged(result)
    }

    private static func inset(_ intervals: [Interval], pad: Float) -> [Interval] {
        intervals.compactMap { interval in
            let span = interval.span
            guard span > 1e-3 else { return nil }
            let used = min(pad, span * 0.05)
            let lo = interval.lo + used
            let hi = interval.hi - used
            guard hi - lo > 1e-3 else { return nil }
            return Interval(lo: lo, hi: hi)
        }
    }

    private static func merged(_ intervals: [Interval]) -> [Interval] {
        let sorted = intervals.sorted { $0.lo < $1.lo }
        var result: [Interval] = []
        for interval in sorted {
            guard let last = result.last else {
                result.append(interval)
                continue
            }
            if interval.lo <= last.hi + 1e-3 {
                result[result.count - 1].hi = max(last.hi, interval.hi)
            } else {
                result.append(interval)
            }
        }
        return result
    }

    // MARK: - Containment

    private static func contains(_ point: (x: Float, y: Float), boundary: Boundary) -> Bool {
        guard point.x.isFinite, point.y.isFinite else { return false }
        switch boundary {
        case let .ellipse(cx, cy, rx, ry):
            guard rx > 1e-4, ry > 1e-4 else { return false }
            let nx = (point.x - cx) / rx
            let ny = (point.y - cy) / ry
            return nx * nx + ny * ny <= 1 + 1e-3
        case let .polygon(points):
            if distanceToEdges(point, polygon: points) <= 0.02 { return true }
            return pointInPolygon(point, polygon: points)
        }
    }

    /// Even-odd test. Points on an edge are handled by `distanceToEdges`.
    private static func pointInPolygon(_ point: (x: Float, y: Float), polygon: [[Float]]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var previous = polygon.count - 1
        for index in polygon.indices {
            let currentX = polygon[index][0]
            let currentY = polygon[index][1]
            let previousX = polygon[previous][0]
            let previousY = polygon[previous][1]
            let crosses = (currentY > point.y) != (previousY > point.y)
            if crosses {
                let xCross = (previousX - currentX) * (point.y - currentY) / (previousY - currentY) + currentX
                if point.x < xCross {
                    inside.toggle()
                }
            }
            previous = index
        }
        return inside
    }

    private static func distanceToEdges(_ point: (x: Float, y: Float), polygon: [[Float]]) -> Float {
        guard polygon.count >= 2 else { return .greatestFiniteMagnitude }
        var best = Float.greatestFiniteMagnitude
        for index in polygon.indices {
            let next = polygon[(index + 1) % polygon.count]
            let ax = polygon[index][0]
            let ay = polygon[index][1]
            let bx = next[0]
            let by = next[1]
            let vx = bx - ax
            let vy = by - ay
            let lengthSquared = vx * vx + vy * vy
            let t: Float
            if lengthSquared < 1e-12 {
                t = 0
            } else {
                let raw = ((point.x - ax) * vx + (point.y - ay) * vy) / lengthSquared
                t = min(1, max(0, raw))
            }
            let dx = point.x - (ax + t * vx)
            let dy = point.y - (ay + t * vy)
            best = min(best, sqrt(dx * dx + dy * dy))
        }
        return best
    }
}
