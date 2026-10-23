//
//  CrayonStroke.swift
//  RoughSwift
//
//  Builds layered wax-crayon strokes from engine operations.
//
//  Each pass is a fill of small wax flecks. The core is dense, with pinholes
//  where flecks are missing. The edge is torn and sheds detached crumbs.
//  A slow envelope, scaled by `segmentLength`, opens longer paper gaps between
//  wax runs. Flecks are stamped in destination space, so `width` matches a
//  normal stroke's point width even when an SVG path is fitted to the canvas.
//  A closed contour is sampled through its closing segment, so the join is
//  covered by the same flecks as the rest of the loop and does not seam.
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
        result.reserveCapacity(style.passes)
        for pass in 0..<style.passes {
            let marks = CGMutablePath()
            for (index, subpath) in subpaths.enumerated() {
                stamp(
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
            // The first pass is already a little translucent so a second pass
            // reads as another layer of wax instead of a second opaque stroke.
            let opacity = max(0.34, 0.9 - CGFloat(style.opacityVariation) * fade * 0.85)
            result.append(CrayonStrokePass(path: SwiftUI.Path(marks), opacity: opacity))
        }
        return result
    }
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

private func stamp(
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

    // Flecks stay small relative to the stroke so the core reads as paper tooth
    // rather than a row of capsules. `tooth` shrinks them further.
    let fleck = min(width * 0.24, max(0.7, width * (0.16 - 0.06 * CGFloat(style.tooth))))
    let step = max(0.8, fleck * 0.72)
    var traveled: CGFloat = 0
    var next = step * 0.45
    var serial = subpathIndex * 20_000
    let budget = serial + 12_000
    let lateralBias = (pass == 0 ? 0 : (pass % 2 == 0 ? -1 : 1)) * width * 0.1

    for index in 1..<placed.count {
        let start = placed[index - 1]
        let end = placed[index]
        let span = distance(start.point, end.point)
        guard span > 0.01 else { continue }
        while next <= traveled + span && serial < budget {
            let t = min(1, max(0, (next - traveled) / span))
            emitColumn(
                at: lerp(start.point, end.point, t),
                tangent: end.tangent,
                width: width,
                fleck: fleck,
                style: style,
                pass: pass,
                distance: next,
                serial: serial,
                lateralBias: lateralBias,
                into: path
            )
            serial += 1
            let jitter = 0.78 + 0.44 * unit(style.seed, pass, serial, 2)
            next += step * jitter
        }
        traveled += span
    }
}

/// One across-stroke slice of wax: core flecks, edge crumbs, and the slow gap envelope.
private func emitColumn(
    at point: CGPoint,
    tangent: CGFloat,
    width: CGFloat,
    fleck: CGFloat,
    style: CrayonStyle,
    pass: Int,
    distance: CGFloat,
    serial: Int,
    lateralBias: CGFloat,
    into path: CGMutablePath
) {
    let tooth = CGFloat(style.tooth)
    let period = max(width * 3.4, 8) * CGFloat(style.segmentLength)
    let wave = 0.5 + 0.5 * sin(
        distance / period * 2 * .pi
            + CGFloat(style.seed % 48) * 0.13
            + CGFloat(pass) * 1.15
    )
    let gapJitter = (unit(style.seed, pass, serial, 3) - 0.5) * 0.06
    let inGap = wave < CGFloat(style.grain) * 0.62 + gapJitter
    if inGap {
        // A few crumbs survive inside the longer paper gap.
        guard unit(style.seed, pass, serial, 19) < 0.14 * CGFloat(style.edgeRoughness) else { return }
        let normal = tangent + .pi / 2
        let side: CGFloat = unit(style.seed, pass, serial, 20) < 0.5 ? -1 : 1
        let out = width * 0.22 * side
        addEllipse(
            path,
            center: CGPoint(x: point.x + cos(normal) * out, y: point.y + sin(normal) * out),
            angle: tangent,
            length: fleck * 0.55,
            thickness: fleck * 0.4
        )
        return
    }

    let normal = tangent + .pi / 2
    let tear = (unit(style.seed, pass, serial, 4) - 0.5) * width * CGFloat(style.edgeRoughness) * 0.36
    let swell = unit(style.seed, pass, serial, 6) - 0.5
    var half = width * (0.46 + CGFloat(style.widthVariation) * swell * 0.22)
    if unit(style.seed, pass, serial, 7) < CGFloat(style.edgeRoughness) * 0.24 {
        half *= 0.58
    }
    half = min(width * 0.78, max(width * 0.2, half))
    let center = CGPoint(
        x: point.x + cos(normal) * (lateralBias + tear),
        y: point.y + sin(normal) * (lateralBias + tear)
    )
    let angle = tangent + (unit(style.seed, pass, serial, 5) - 0.5) * CGFloat(style.edgeRoughness) * 0.65
    let rows = min(8, max(3, Int((half * 2 / max(fleck * 0.85, 0.6)).rounded())))

    for row in 0..<rows {
        let span = CGFloat(max(rows - 1, 1))
        let across = (CGFloat(row) / span - 0.5) * half * 2
        let radial = abs(across) / max(half, 0.01)
        let keep: CGFloat
        if radial < 0.48 {
            // Pinholes scale with tooth. Grain opens the longer gaps, not the core.
            keep = 0.97 - CGFloat(style.grain) * 0.28 * tooth
        } else if radial < 0.8 {
            keep = 0.7 - CGFloat(style.grain) * 0.18 * tooth
        } else {
            keep = 0.2 + 0.55 * CGFloat(style.edgeRoughness) * max(tooth, 0.35)
        }
        if unit(style.seed, pass, serial &* 17 &+ row, 11) > keep { continue }
        let jAlong = (unit(style.seed, pass, serial &+ row, 12) - 0.5) * fleck
        let jAcross = (unit(style.seed, pass, serial &+ row, 13) - 0.5) * fleck * 0.85
        let fleckLength = fleck * (0.5 + 0.95 * unit(style.seed, pass, serial &+ row, 14))
        let fleckThickness = fleck * (0.38 + 0.7 * unit(style.seed, pass, serial &+ row, 15))
        let fleckAngle = angle + (unit(style.seed, pass, serial &+ row, 16) - 0.5) * 1.2
        addEllipse(
            path,
            center: CGPoint(
                x: center.x + cos(angle) * jAlong + cos(normal) * (across + jAcross),
                y: center.y + sin(angle) * jAlong + sin(normal) * (across + jAcross)
            ),
            angle: fleckAngle,
            length: max(0.6, fleckLength),
            thickness: max(0.45, fleckThickness)
        )
    }

    if unit(style.seed, pass, serial, 18) < CGFloat(style.edgeRoughness) * 0.75 * tooth {
        let side: CGFloat = unit(style.seed, pass, serial, 20) < 0.5 ? -1 : 1
        let out = half + width * (0.05 + 0.32 * unit(style.seed, pass, serial, 21))
        let crumb = max(0.55, fleck * (0.4 + 0.55 * unit(style.seed, pass, serial, 22)))
        addEllipse(
            path,
            center: CGPoint(
                x: center.x + cos(normal) * side * out,
                y: center.y + sin(normal) * side * out
            ),
            angle: angle + (unit(style.seed, pass, serial, 23) - 0.5),
            length: crumb,
            thickness: crumb * 0.65
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
