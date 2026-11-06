//
//  FillGeometry.swift
//  Sketchy
//
//  Insets and shifts the region a fill is drawn into, without moving the outline.
//

import CoreGraphics
import UIKit

/// Fill region after `fillPadding` and `fillOffset`.
///
/// Padding is applied first, then the offset. A positive padding shrinks the
/// region (polygon edges move inward, ellipse radii shrink). A negative
/// padding grows it. The result is `nil` when the padding eats the shape.
enum FillGeometry {

    /// Ellipse the fill should use. `nil` when either radius collapses.
    static func ellipse(
        cx: Float,
        cy: Float,
        rx: Float,
        ry: Float,
        padding: CGFloat,
        offset: CGSize
    ) -> (cx: Float, cy: Float, rx: Float, ry: Float)? {
        let pad = Float(padding)
        let adjustedRx = rx - pad
        let adjustedRy = ry - pad
        guard adjustedRx > 0, adjustedRy > 0, adjustedRx.isFinite, adjustedRy.isFinite else {
            return nil
        }
        return (
            cx + Float(offset.width),
            cy + Float(offset.height),
            adjustedRx,
            adjustedRy
        )
    }

    /// Polygon the fill should use. `nil` when the inset collapses.
    ///
    /// Zero padding returns the same vertices. A non-zero padding offsets each
    /// edge along the fill normal and joins them with a miter.
    static func polygon(
        _ points: [[Float]],
        padding: CGFloat,
        offset: CGSize
    ) -> [[Float]]? {
        let pad = Float(padding)
        let inset: [[Float]]
        if abs(pad) < 1e-4 {
            inset = points
        } else {
            guard let offsetPoints = offsetPolygon(points, by: pad) else { return nil }
            inset = offsetPoints
        }
        guard inset.count >= 3 else { return nil }
        guard offset != .zero else { return inset }
        let dx = Float(offset.width)
        let dy = Float(offset.height)
        return inset.map { [$0[0] + dx, $0[1] + dy] }
    }

    /// Path the scribble filler should cross.
    ///
    /// Zero padding and a zero offset return `path` unchanged. A translation
    /// alone keeps the curves. A non-zero padding flattens, offsets each
    /// contour, then shifts. `nil` means every contour collapsed.
    static func adjustedPath(_ path: CGPath, padding: CGFloat, offset: CGSize) -> CGPath? {
        if padding == 0 && offset == .zero {
            return path
        }
        if padding == 0 {
            var transform = CGAffineTransform(translationX: offset.width, y: offset.height)
            return path.copy(using: &transform)
        }
        let contours = flatten(path)
        guard !contours.isEmpty else { return nil }
        guard let adjusted = offsetContours(contours, by: Float(padding)) else { return nil }
        let shifted = polygon(joining: adjusted, padding: 0, offset: offset)
        return cgPath(from: shifted)
    }

    /// Closed contours of an SVG path, offset for a pattern or solid fill.
    ///
    /// `nil` when nothing is left to fill. The caller keeps the original path
    /// when padding and offset are both zero so seeded SVG output stays put.
    /// The largest ring is first so a pattern fill can hatch that outline and
    /// clip the rest (holes) with `svgPath(from:)`.
    static func svgContours(
        _ pathString: String,
        padding: CGFloat,
        offset: CGSize
    ) -> [[[Float]]]? {
        let bezier = UIBezierPath(svgPath: pathString)
        let contours = flatten(bezier.cgPath)
        guard !contours.isEmpty else { return nil }
        let pad = Float(padding)
        let adjusted: [[[Float]]]
        if abs(pad) < 1e-4 {
            adjusted = contours
        } else {
            guard let offsetContours = offsetContours(contours, by: pad) else { return nil }
            adjusted = offsetContours
        }
        let dx = Float(offset.width)
        let dy = Float(offset.height)
        let shifted = adjusted.map { contour in
            contour.map { [$0[0] + dx, $0[1] + dy] }
        }
        return shifted.sorted { abs(signedArea($0)) > abs(signedArea($1)) }
    }

    /// SVG path of one or more rings, for a solid fill of an offset path.
    static func svgPath(from contours: [[[Float]]]) -> String {
        contours.map { contour -> String in
            guard let first = contour.first else { return "" }
            var text = "M \(first[0]) \(first[1])"
            for point in contour.dropFirst() {
                text += " L \(point[0]) \(point[1])"
            }
            text += " Z"
            return text
        }.joined(separator: " ")
    }

    // MARK: - Polygon offset

    /// Moves `points` inward by `padding`. Negative `padding` grows the ring.
    ///
    /// `nil` when the offset reverses the winding, self-intersects, or the
    /// edge midpoints no longer sit about `padding` inside the original.
    private static func offsetPolygon(_ points: [[Float]], by padding: Float) -> [[Float]]? {
        let ring = cleaned(points)
        guard ring.count >= 3 else { return nil }
        let area = signedArea(ring)
        guard abs(area) > 1e-3 else { return nil }

        let sign: Float = area > 0 ? 1 : -1
        var edges: [Edge] = []
        edges.reserveCapacity(ring.count)
        for index in 0..<ring.count {
            let start = ring[index]
            let end = ring[(index + 1) % ring.count]
            let dx = end[0] - start[0]
            let dy = end[1] - start[1]
            let length = hypot(dx, dy)
            guard length > 1e-4 else { continue }
            // Left of a screen-clockwise ring points into the shape.
            let nx = (-dy / length) * sign
            let ny = (dx / length) * sign
            let ox = nx * padding
            let oy = ny * padding
            edges.append(Edge(
                start: (start[0] + ox, start[1] + oy),
                end: (end[0] + ox, end[1] + oy)
            ))
        }
        guard edges.count >= 3 else { return nil }

        var result: [[Float]] = []
        result.reserveCapacity(edges.count)
        for index in 0..<edges.count {
            let previous = edges[(index + edges.count - 1) % edges.count]
            let current = edges[index]
            let point = intersection(previous, current) ?? previous.end
            guard point.x.isFinite, point.y.isFinite else { return nil }
            result.append([point.x, point.y])
        }

        guard accepts(result, original: ring, padding: padding, originalArea: area) else {
            return nil
        }
        return result
    }

    /// Offsets every contour of a filled region.
    ///
    /// The largest ring is the outside. Opposite-winding rings are holes, so
    /// they move the other way: insetting the fill grows a hole.
    private static func offsetContours(_ contours: [[[Float]]], by padding: Float) -> [[[Float]]]? {
        let rings = contours.map { cleaned($0) }.filter { $0.count >= 3 }
        guard let outer = rings.max(by: { abs(signedArea($0)) < abs(signedArea($1)) }) else {
            return nil
        }
        let outerSign = signedArea(outer) >= 0
        var result: [[[Float]]] = []
        for ring in rings {
            let isHole = (signedArea(ring) >= 0) != outerSign
            let local = isHole ? -padding : padding
            if abs(local) < 1e-4 {
                result.append(ring)
            } else if let offset = offsetPolygon(ring, by: local) {
                result.append(offset)
            }
        }
        return result.isEmpty ? nil : result
    }

    private static func polygon(joining contours: [[[Float]]], padding: CGFloat, offset: CGSize) -> [[[Float]]] {
        contours.compactMap { polygon($0, padding: padding, offset: offset) }
    }

    private static func accepts(
        _ result: [[Float]],
        original: [[Float]],
        padding: Float,
        originalArea: Float
    ) -> Bool {
        guard result.count >= 3 else { return false }
        let area = signedArea(result)
        guard abs(area) > 1, area * originalArea > 0 else { return false }
        if segmentsIntersect(result) { return false }
        guard padding > 0 else { return true }

        for index in 0..<result.count {
            let start = result[index]
            let end = result[(index + 1) % result.count]
            let mid = ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2)
            guard contains(mid, polygon: original) else { return false }
            let distance = distanceToBoundary(mid, polygon: original)
            if distance + 0.75 < padding { return false }
        }
        return true
    }

    // MARK: - Flatten

    private static func flatten(_ path: CGPath) -> [[[Float]]] {
        let builder = ContourBuilder()
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                builder.move(points[0])
            case .addLineToPoint:
                builder.line(points[0])
            case .addQuadCurveToPoint:
                builder.quad(control: points[0], end: points[1])
            case .addCurveToPoint:
                builder.cubic(control1: points[0], control2: points[1], end: points[2])
            case .closeSubpath:
                builder.close()
            @unknown default:
                break
            }
        }
        builder.finish()
        return builder.contours
    }

    private static func cgPath(from contours: [[[Float]]]) -> CGPath {
        let path = CGMutablePath()
        for contour in contours where contour.count >= 3 {
            path.move(to: CGPoint(x: CGFloat(contour[0][0]), y: CGFloat(contour[0][1])))
            for point in contour.dropFirst() {
                path.addLine(to: CGPoint(x: CGFloat(point[0]), y: CGFloat(point[1])))
            }
            path.closeSubpath()
        }
        return path
    }

    // MARK: - Geometry

    private struct Edge {
        var start: (x: Float, y: Float)
        var end: (x: Float, y: Float)
    }

    private static func cleaned(_ points: [[Float]]) -> [[Float]] {
        var ring: [[Float]] = []
        for point in points where point.count >= 2 {
            if let last = ring.last, hypot(point[0] - last[0], point[1] - last[1]) < 1e-3 {
                continue
            }
            ring.append([point[0], point[1]])
        }
        if ring.count >= 2, let first = ring.first, let last = ring.last,
           hypot(first[0] - last[0], first[1] - last[1]) < 1e-3 {
            ring.removeLast()
        }
        return ring
    }

    /// Positive when the ring is clockwise on screen (y down).
    static func signedArea(_ points: [[Float]]) -> Float {
        guard points.count >= 3 else { return 0 }
        var sum: Float = 0
        for index in 0..<points.count {
            let next = points[(index + 1) % points.count]
            sum += points[index][0] * next[1] - next[0] * points[index][1]
        }
        return sum / 2
    }

    private static func intersection(_ a: Edge, _ b: Edge) -> (x: Float, y: Float)? {
        let dax = a.end.x - a.start.x
        let day = a.end.y - a.start.y
        let dbx = b.end.x - b.start.x
        let dby = b.end.y - b.start.y
        let denom = dax * dby - day * dbx
        if abs(denom) < 1e-5 {
            return nil
        }
        let t = ((b.start.x - a.start.x) * dby - (b.start.y - a.start.y) * dbx) / denom
        return (a.start.x + t * dax, a.start.y + t * day)
    }

    private static func contains(_ point: (x: Float, y: Float), polygon: [[Float]]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let yi = polygon[i][1]
            let yj = polygon[j][1]
            let xi = polygon[i][0]
            let xj = polygon[j][0]
            let crosses = (yi > point.y) != (yj > point.y)
            if crosses {
                let x = (xj - xi) * (point.y - yi) / (yj - yi) + xi
                if point.x < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    private static func distanceToBoundary(_ point: (x: Float, y: Float), polygon: [[Float]]) -> Float {
        var best = Float.greatestFiniteMagnitude
        for index in 0..<polygon.count {
            let start = polygon[index]
            let end = polygon[(index + 1) % polygon.count]
            best = min(best, distance(point, to: (start[0], start[1]), (end[0], end[1])))
        }
        return best
    }

    private static func distance(
        _ point: (x: Float, y: Float),
        to start: (x: Float, y: Float),
        _ end: (x: Float, y: Float)
    ) -> Float {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-8 else {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let x = start.x + t * dx
        let y = start.y + t * dy
        return hypot(point.x - x, point.y - y)
    }

    /// True when non-adjacent edges cross. Adjacent edges share a vertex.
    private static func segmentsIntersect(_ points: [[Float]]) -> Bool {
        let count = points.count
        guard count >= 4 else { return false }
        for i in 0..<count {
            for j in (i + 1)..<count {
                let gap = min(abs(i - j), count - abs(i - j))
                if gap <= 1 { continue }
                let a1 = points[i]
                let a2 = points[(i + 1) % count]
                let b1 = points[j]
                let b2 = points[(j + 1) % count]
                if segmentsCross(a1, a2, b1, b2) { return true }
            }
        }
        return false
    }

    private static func segmentsCross(_ a: [Float], _ b: [Float], _ c: [Float], _ d: [Float]) -> Bool {
        func side(_ p: [Float], _ q: [Float], _ r: [Float]) -> Float {
            (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0])
        }
        let ab = side(a, b, c) * side(a, b, d)
        let cd = side(c, d, a) * side(c, d, b)
        return ab < 0 && cd < 0
    }
}

/// Collects flattened contours while `CGPath.applyWithBlock` walks a path.
private final class ContourBuilder {
    var contours: [[[Float]]] = []
    private var current: [[Float]] = []
    private var pen: (x: Float, y: Float)?

    func move(_ point: CGPoint) {
        finishOpen()
        let sample = (Float(point.x), Float(point.y))
        pen = sample
        current = [[sample.0, sample.1]]
    }

    func line(_ point: CGPoint) {
        add(Float(point.x), Float(point.y))
    }

    func quad(control: CGPoint, end: CGPoint) {
        guard let start = pen else {
            line(end)
            return
        }
        sample { t in
            let u = 1 - t
            let x = u * u * start.0 + 2 * u * t * Float(control.x) + t * t * Float(end.x)
            let y = u * u * start.1 + 2 * u * t * Float(control.y) + t * t * Float(end.y)
            return (x, y)
        }
        add(Float(end.x), Float(end.y))
    }

    func cubic(control1: CGPoint, control2: CGPoint, end: CGPoint) {
        guard let start = pen else {
            line(end)
            return
        }
        sample { t in
            let u = 1 - t
            let x = u * u * u * start.0
                + 3 * u * u * t * Float(control1.x)
                + 3 * u * t * t * Float(control2.x)
                + t * t * t * Float(end.x)
            let y = u * u * u * start.1
                + 3 * u * u * t * Float(control1.y)
                + 3 * u * t * t * Float(control2.y)
                + t * t * t * Float(end.y)
            return (x, y)
        }
        add(Float(end.x), Float(end.y))
    }

    func close() {
        guard current.count >= 3 else {
            current = []
            pen = nil
            return
        }
        contours.append(current)
        current = []
        pen = nil
    }

    func finish() {
        finishOpen()
    }

    private func finishOpen() {
        if current.count >= 3 {
            contours.append(current)
        }
        current = []
    }

    private func sample(_ point: (Float) -> (Float, Float)) {
        let steps = 6
        for step in 1..<steps {
            let sample = point(Float(step) / Float(steps))
            add(sample.0, sample.1)
        }
    }

    private func add(_ x: Float, _ y: Float) {
        if let last = current.last, hypot(x - last[0], y - last[1]) < 1e-3 {
            pen = (x, y)
            return
        }
        current.append([x, y])
        pen = (x, y)
    }
}
