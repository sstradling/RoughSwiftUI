//
//  CrayonStroke.swift
//  RoughSwift
//
//  Builds layered wax-crayon strokes from engine operations.
//
//  The first passes are a continuous greasy base: a wide soft halo and a
//  firmer core, with no breaks along the stroke. Later passes lay denser,
//  larger flakes and edge crumbs on top of that base. Marks are stamped in
//  destination space, so `width` matches a normal stroke's point width even
//  when an SVG path is fitted to the canvas. A closed contour is sampled
//  through its closing segment, so the join is covered and does not seam.
//

import CoreGraphics
import SwiftUI

/// One filled layer of a crayon stroke.
public struct CrayonStrokePass: Equatable, Sendable {
    /// Wax marks for this pass. Fill with the winding rule so overlaps union.
    public var path: SwiftUI.Path

    /// Opacity multiplier in 0...1, applied on top of the stroke color.
    public var opacity: CGFloat
}

/// Generates stable crayon geometry from rough-engine operations.
public enum CrayonStroke {
    /// Builds crayon passes for `operations`.
    ///
    /// - Parameters:
    ///   - operations: Centerline in source space (a line, an open path, or a closed contour).
    ///   - width: Wax width in the destination space, in points. Scales every mark.
    ///   - style: Grain, edge, layering, and seed.
    ///   - transform: Maps source points into the destination. Width is not scaled.
    /// - Returns: One pass per wax layer. Empty when the path has no length.
    public static func passes(
        operations: [Operation],
        width: CGFloat,
        style: CrayonStyle,
        transform: CGAffineTransform = .identity
    ) -> [CrayonStrokePass] {
        guard width >= 0.25 else { return [] }
        let subpaths = subpaths(from: operations)
        guard !subpaths.isEmpty else { return [] }

        var result: [CrayonStrokePass] = []
        result.reserveCapacity(style.passes + 2)
        result.append(contentsOf: basePasses(
            subpaths: subpaths,
            width: width,
            style: style,
            transform: transform
        ))
        for pass in 0..<style.passes {
            let marks = CGMutablePath()
            for (index, subpath) in subpaths.enumerated() {
                stampGrit(
                    subpath,
                    into: marks,
                    width: width,
                    style: style,
                    transform: transform,
                    pass: pass,
                    subpathIndex: index
                )
            }
            guard !marks.isEmpty else { continue }
            let fade = style.passes == 1 ? 0 : CGFloat(pass) / CGFloat(style.passes - 1)
            let opacity = max(0.72, 0.96 - CGFloat(style.opacityVariation) * fade * 0.28)
            result.append(CrayonStrokePass(path: SwiftUI.Path(marks), opacity: opacity))
        }
        return result
    }
}

private func basePasses(
    subpaths: [CrayonSubpath],
    width: CGFloat,
    style: CrayonStyle,
    transform: CGAffineTransform
) -> [CrayonStrokePass] {
    let halo = CGMutablePath()
    let core = CGMutablePath()
    for (index, subpath) in subpaths.enumerated() {
        stampBase(
            subpath,
            halo: halo,
            core: core,
            width: width,
            style: style,
            transform: transform,
            subpathIndex: index
        )
    }
    let baseOpacity = CGFloat(style.baseOpacity)
    let haloOpacity = max(0.14, baseOpacity * (0.22 + 0.12 * CGFloat(style.baseSoftness)))
    var passes: [CrayonStrokePass] = []
    if !halo.isEmpty {
        passes.append(CrayonStrokePass(path: SwiftUI.Path(halo), opacity: haloOpacity))
    }
    if !core.isEmpty {
        passes.append(CrayonStrokePass(path: SwiftUI.Path(core), opacity: baseOpacity))
    }
    return passes
}

// MARK: - Sampling

private struct CrayonSample {
    var point: CGPoint
    var tangent: CGFloat
}

private struct CrayonSubpath {
    var samples: [CrayonSample]
    var isClosed: Bool
}

private func subpaths(from operations: [Operation]) -> [CrayonSubpath] {
    var result: [CrayonSubpath] = []
    var current: [CrayonSample] = []
    var start: CGPoint?
    var cursor = CGPoint.zero
    var closed = false

    func flush() {
        guard current.count >= 2 else {
            current.removeAll()
            start = nil
            closed = false
            return
        }
        result.append(CrayonSubpath(samples: current, isClosed: closed))
        current.removeAll()
        start = nil
        closed = false
    }

    for operation in operations {
        switch operation {
        case let move as Move:
            flush()
            cursor = move.point.cgPoint
            start = cursor
            current = [CrayonSample(point: cursor, tangent: 0)]
        case let line as LineTo:
            appendLine(from: &cursor, to: line.point.cgPoint, into: &current)
        case let curve as BezierCurveTo:
            appendCubic(
                from: &cursor,
                to: curve.point.cgPoint,
                control1: curve.controlPoint1.cgPoint,
                control2: curve.controlPoint2.cgPoint,
                into: &current
            )
        case let curve as QuadraticCurveTo:
            appendQuad(
                from: &cursor,
                to: curve.point.cgPoint,
                control: curve.controlPoint.cgPoint,
                into: &current
            )
        case is Close:
            if let start, distance(cursor, start) > 0.01 {
                appendLine(from: &cursor, to: start, into: &current)
            }
            closed = true
        default:
            break
        }
    }
    flush()
    return result
}

private func appendLine(from cursor: inout CGPoint, to end: CGPoint, into samples: inout [CrayonSample]) {
    let length = distance(cursor, end)
    guard length > 0.01 else {
        cursor = end
        return
    }
    let tangent = atan2(end.y - cursor.y, end.x - cursor.x)
    let startsHere = samples.count == 1
    let steps = max(1, Int(ceil(length / 2)))
    for step in 1...steps {
        let t = CGFloat(step) / CGFloat(steps)
        samples.append(CrayonSample(point: lerp(cursor, end, t), tangent: tangent))
    }
    if startsHere {
        samples[0].tangent = tangent
    }
    cursor = end
}

private func appendCubic(
    from cursor: inout CGPoint,
    to end: CGPoint,
    control1: CGPoint,
    control2: CGPoint,
    into samples: inout [CrayonSample]
) {
    let length = distance(cursor, control1) + distance(control1, control2) + distance(control2, end)
    guard length > 0.01 else {
        cursor = end
        return
    }
    let startsHere = samples.count == 1
    let steps = min(48, max(2, Int(ceil(length / 2))))
    let origin = cursor
    for step in 1...steps {
        let t = CGFloat(step) / CGFloat(steps)
        let point = cubic(origin, control1, control2, end, t)
        let tangentPoint = cubic(origin, control1, control2, end, max(0, t - 0.02))
        let tangent = atan2(point.y - tangentPoint.y, point.x - tangentPoint.x)
        samples.append(CrayonSample(point: point, tangent: tangent))
    }
    if startsHere, samples.count > 1 {
        samples[0].tangent = samples[1].tangent
    }
    cursor = end
}

private func appendQuad(
    from cursor: inout CGPoint,
    to end: CGPoint,
    control: CGPoint,
    into samples: inout [CrayonSample]
) {
    let length = distance(cursor, control) + distance(control, end)
    guard length > 0.01 else {
        cursor = end
        return
    }
    let startsHere = samples.count == 1
    let steps = min(32, max(2, Int(ceil(length / 2))))
    let origin = cursor
    for step in 1...steps {
        let t = CGFloat(step) / CGFloat(steps)
        let point = quad(origin, control, end, t)
        let previous = quad(origin, control, end, max(0, t - 0.02))
        samples.append(CrayonSample(
            point: point,
            tangent: atan2(point.y - previous.y, point.x - previous.x)
        ))
    }
    if startsHere, samples.count > 1 {
        samples[0].tangent = samples[1].tangent
    }
    cursor = end
}

// MARK: - Stamping

/// Continuous greasy base. Overlapping ellipses leave no paper break along the stroke.
private func stampBase(
    _ subpath: CrayonSubpath,
    halo: CGMutablePath,
    core: CGMutablePath,
    width: CGFloat,
    style: CrayonStyle,
    transform: CGAffineTransform,
    subpathIndex: Int
) {
    let placed = transformed(subpath.samples, by: transform)
    guard placed.count >= 2 else { return }

    let softness = CGFloat(style.baseSoftness)
    let step = max(1.05, width * 0.2)
    var traveled: CGFloat = 0
    var next: CGFloat = 0
    var serial = subpathIndex * 20_000
    let budget = serial + 8_000

    for index in 1..<placed.count {
        let start = placed[index - 1]
        let end = placed[index]
        let span = distance(start.point, end.point)
        guard span > 0.01 else { continue }
        while next <= traveled + span && serial < budget {
            let t = min(1, max(0, (next - traveled) / span))
            let point = lerp(start.point, end.point, t)
            let tangent = end.tangent
            let normal = tangent + .pi / 2
            let swell = unit(style.seed, 0, serial, 6) - 0.5
            let wobble = 1 + CGFloat(style.widthVariation) * swell * 0.22
            // A small sideways drift softens the edge. It stays well inside the
            // ellipse thickness, so the wax still overlaps and does not break.
            let drift = (unit(style.seed, 1, serial, 8) - 0.5) * width * softness * 0.1
            let center = CGPoint(
                x: point.x + cos(normal) * drift,
                y: point.y + sin(normal) * drift
            )
            let along = max(step * 2.4, width * 0.9)
            addEllipse(
                halo,
                center: center,
                angle: tangent,
                length: along,
                thickness: width * (1.08 + softness * 0.28) * wobble
            )
            addEllipse(
                core,
                center: center,
                angle: tangent,
                length: along * 0.96,
                thickness: width * (0.88 + softness * 0.06) * wobble
            )
            serial += 1
            next += step
        }
        traveled += span
    }
}

/// Dark clumps, smaller paper-tooth specks, and detached edge flakes. Never opens a gap in the base.
private func stampGrit(
    _ subpath: CrayonSubpath,
    into path: CGMutablePath,
    width: CGFloat,
    style: CrayonStyle,
    transform: CGAffineTransform,
    pass: Int,
    subpathIndex: Int
) {
    let placed = transformed(subpath.samples, by: transform)
    guard placed.count >= 2 else { return }

    let flake = max(1.35, width * (0.16 + 0.15 * CGFloat(style.flakeSize)))
    let speck = max(0.8, flake * 0.34)
    let step = max(1.05, flake * 0.62)
    let rows = min(4, max(2, Int((width * 0.55 / flake).rounded(.up))))
    var traveled: CGFloat = 0
    var next = step * 0.35
    var serial = subpathIndex * 20_000 + pass * 3_000
    let budget = serial + 10_000
    let lateralBias = (pass == 0 ? 0 : (pass % 2 == 0 ? -1 : 1)) * width * 0.06

    for index in 1..<placed.count {
        let start = placed[index - 1]
        let end = placed[index]
        let span = distance(start.point, end.point)
        guard span > 0.01 else { continue }
        while next <= traveled + span && serial < budget {
            let t = min(1, max(0, (next - traveled) / span))
            emitGrit(
                at: lerp(start.point, end.point, t),
                tangent: end.tangent,
                width: width,
                flake: flake,
                speck: speck,
                rows: rows,
                style: style,
                pass: pass,
                serial: serial,
                lateralBias: lateralBias,
                into: path
            )
            serial += 1
            next += step * (0.82 + 0.36 * unit(style.seed, pass, serial, 2))
        }
        traveled += span
    }
}

private func emitGrit(
    at point: CGPoint,
    tangent: CGFloat,
    width: CGFloat,
    flake: CGFloat,
    speck: CGFloat,
    rows: Int,
    style: CrayonStyle,
    pass: Int,
    serial: Int,
    lateralBias: CGFloat,
    into path: CGMutablePath
) {
    let normal = tangent + .pi / 2
    let edge = CGFloat(style.edgeRoughness)
    let tear = (unit(style.seed, pass, serial, 4) - 0.5) * width * edge * 0.34
    let center = CGPoint(
        x: point.x + cos(normal) * (lateralBias + tear),
        y: point.y + sin(normal) * (lateralBias + tear)
    )
    let angle = tangent + (unit(style.seed, pass, serial, 5) - 0.5) * edge * 0.9
    // The dark band wanders. The greasy base stays wider and smooth under it,
    // so the torn edge is the grit, not a break in the wax.
    let band = width * (0.34 + 0.16 * unit(style.seed, pass, serial, 30) * (0.35 + edge))
    let clumpScale: CGFloat = pass == 0 ? 1 : 0.62
    let clumpKeep = min(0.97, 0.58 + CGFloat(style.grit) * 0.38 - CGFloat(style.grain) * 0.18)
    let speckKeep = min(0.7, 0.1 + CGFloat(style.grit) * 0.4 - CGFloat(style.grain) * 0.16)

    for row in 0..<rows {
        let span = CGFloat(max(rows - 1, 1))
        let across = (CGFloat(row) / span - 0.5) * band * 2
        let radial = abs(across) / max(band, 0.01)
        let keep = radial < 0.8 ? clumpKeep : clumpKeep * (0.55 + 0.35 * edge)
        if unit(style.seed, pass, serial &* 17 &+ row, 11) <= keep {
            let jAlong = (unit(style.seed, pass, serial &+ row, 12) - 0.5) * flake * 0.85
            let jAcross = (unit(style.seed, pass, serial &+ row, 13) - 0.5) * flake * 0.55
            let length = flake * clumpScale * (0.9 + 0.85 * unit(style.seed, pass, serial &+ row, 14))
            let thickness = flake * clumpScale * (0.48 + 0.55 * unit(style.seed, pass, serial &+ row, 15))
            addEllipse(
                path,
                center: CGPoint(
                    x: center.x + cos(angle) * jAlong + cos(normal) * (across + jAcross),
                    y: center.y + sin(angle) * jAlong + sin(normal) * (across + jAcross)
                ),
                angle: angle + (unit(style.seed, pass, serial &+ row, 16) - 0.5) * 1.1,
                length: length,
                thickness: thickness
            )
        }
        if unit(style.seed, pass, serial &* 13 &+ row, 17) <= speckKeep {
            let acrossSpeck = (unit(style.seed, pass, serial &+ row, 18) - 0.5) * band * 1.7
            addEllipse(
                path,
                center: CGPoint(
                    x: center.x + cos(normal) * acrossSpeck,
                    y: center.y + sin(normal) * acrossSpeck
                ),
                angle: angle + (unit(style.seed, pass, serial &+ row, 19) - 0.5),
                length: speck * (0.65 + 0.8 * unit(style.seed, pass, serial &+ row, 20)),
                thickness: speck * (0.4 + 0.45 * unit(style.seed, pass, serial &+ row, 21))
            )
        }
    }

    // Crumbs sit outside the soft halo so they read as detached flakes.
    let haloHalf = width * (1.08 + CGFloat(style.baseSoftness) * 0.28) / 2
    if unit(style.seed, pass, serial, 22) < edge * (0.42 + CGFloat(style.grit) * 0.28) {
        let side: CGFloat = unit(style.seed, pass, serial, 23) < 0.5 ? -1 : 1
        let out = haloHalf + width * (0.01 + 0.06 * unit(style.seed, pass, serial, 24))
        let crumb = flake * (0.36 + 0.4 * unit(style.seed, pass, serial, 25))
        addEllipse(
            path,
            center: CGPoint(
                x: center.x + cos(normal) * side * out,
                y: center.y + sin(normal) * side * out
            ),
            angle: angle + (unit(style.seed, pass, serial, 26) - 0.5) * 1.4,
            length: crumb,
            thickness: crumb * 0.58
        )
    }
    if unit(style.seed, pass, serial, 27) < edge * 0.42 {
        let side: CGFloat = unit(style.seed, pass, serial, 28) < 0.5 ? -1 : 1
        let out = haloHalf + width * (0.05 + 0.1 * unit(style.seed, pass, serial, 29))
        let crumb = flake * 0.36 * (0.7 + unit(style.seed, pass, serial, 31))
        addEllipse(
            path,
            center: CGPoint(
                x: center.x + cos(normal) * side * out + cos(angle) * flake * 0.2,
                y: center.y + sin(normal) * side * out + sin(angle) * flake * 0.2
            ),
            angle: angle,
            length: crumb,
            thickness: crumb * 0.7
        )
    }
}

private func addEllipse(
    _ path: CGMutablePath,
    center: CGPoint,
    angle: CGFloat,
    length: CGFloat,
    thickness: CGFloat
) {
    let rect = CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness)
    var placement = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle)
    path.addPath(CGPath(ellipseIn: rect, transform: &placement))
}

private func transformed(_ samples: [CrayonSample], by transform: CGAffineTransform) -> [CrayonSample] {
    samples.map { sample in
        CrayonSample(
            point: sample.point.applying(transform),
            tangent: transformedAngle(sample.tangent, transform)
        )
    }
}

private func transformedAngle(_ angle: CGFloat, _ transform: CGAffineTransform) -> CGFloat {
    let dx = cos(angle)
    let dy = sin(angle)
    let x = transform.a * dx + transform.c * dy
    let y = transform.b * dx + transform.d * dy
    if abs(x) < 0.000_01 && abs(y) < 0.000_01 {
        return angle
    }
    return atan2(y, x)
}

// MARK: - Hash and geometry

/// Deterministic value in 0...1. The same inputs always return the same value.
private func unit(_ seed: UInt64, _ pass: Int, _ index: Int, _ channel: Int) -> CGFloat {
    var x = seed &+ 0x9E3779B97F4A7C15
    x ^= UInt64(bitPattern: Int64(pass)) &* 0xBF58476D1CE4E5B9
    x ^= UInt64(bitPattern: Int64(index)) &* 0x94D049BB133111EB
    x ^= UInt64(bitPattern: Int64(channel)) &* 0xD1B54A32D192ED03
    x = (x ^ (x >> 30)) &* 0xBF58476D1CE4E5B9
    x = (x ^ (x >> 27)) &* 0x94D049BB133111EB
    x = x ^ (x >> 31)
    return CGFloat(x % 10_000) / 9_999
}

private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    hypot(a.x - b.x, a.y - b.y)
}

private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

private func cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let uu = u * u
    let tt = t * t
    let a = uu * u
    let b = 3 * uu * t
    let c = 3 * u * tt
    let d = tt * t
    return CGPoint(
        x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
        y: a * p0.y + b * p1.y + c * p2.y + d * p3.y
    )
}

private func quad(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    return CGPoint(
        x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
        y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
    )
}
