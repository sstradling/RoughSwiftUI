//
//  RibbonMesh.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Builds a triangle-strip mesh from a stroke path so it can be rendered by
//  a Metal fragment shader with per-pixel control over color, opacity, and
//  texture along the stroke length and width.
//

import Foundation
import CoreGraphics
import simd
import RoughSwiftUI

// MARK: - Vertex

/// A single ribbon vertex pushed to the GPU.
///
/// Layout matches the `RibbonVertex` struct in `RibbonShaders.metal`:
/// - `position`: 2D position in the canvas coordinate system (points).
/// - `parametric`: `(s, t)` — `s` is normalized along-stroke distance in
///   `[0, 1]`, `t` is across-stroke offset in `[-1, +1]` where `0` is the
///   stroke centerline.
public struct RibbonVertex: Equatable {
    public var position: SIMD2<Float>
    public var parametric: SIMD2<Float>

    public init(position: SIMD2<Float>, parametric: SIMD2<Float>) {
        self.position = position
        self.parametric = parametric
    }
}

// MARK: - Mesh

/// A triangle-strip mesh representing the visible width of one stroke.
///
/// Vertices are produced in pairs `(left[i], right[i])`. With
/// `MTLPrimitiveType.triangleStrip` this produces a continuous ribbon.
/// Open paths render with their natural endpoints; closed paths repeat
/// the first vertex pair at the end so the strip seam closes cleanly.
public struct RibbonMesh: Equatable {
    /// Interleaved vertices in the order `left[0], right[0], left[1], right[1], ...`.
    public var vertices: [RibbonVertex]

    /// Whether the underlying path is closed (informational; affects how
    /// callers might choose to clip or composite).
    public let isClosed: Bool

    /// Total un-normalized arc length of the stroke in points. Useful for
    /// shaders that want frequency in cycles-per-point rather than
    /// cycles-per-unit-`s`.
    public let totalLength: CGFloat

    public init(vertices: [RibbonVertex], isClosed: Bool, totalLength: CGFloat) {
        self.vertices = vertices
        self.isClosed = isClosed
        self.totalLength = totalLength
    }

    /// `true` if no triangles can be drawn from this mesh.
    public var isEmpty: Bool { vertices.count < 4 }
}

// MARK: - Builder

/// Constructs `RibbonMesh` instances from `OperationSet` data.
///
/// The builder is deliberately self-contained — it does not depend on any
/// SwiftUI types — so the same code can be unit-tested without a Metal
/// device. Sampling logic mirrors `StrokeToFillConverter` in the base
/// library so the visible geometry matches between the two renderers.
public enum RibbonMeshBuilder {

    /// Maximum chord length between samples in points. Smaller values
    /// produce smoother ribbons at the cost of more GPU vertices.
    static let maxSampleSpacing: CGFloat = 4.0

    /// Build a ribbon mesh from a single `OperationSet`.
    ///
    /// - Parameters:
    ///   - operations: The operations from a `.path` operation set.
    ///   - baseWidth: Stroke width in points.
    /// - Returns: A `RibbonMesh`, or `nil` if the operations describe no
    ///   drawable geometry.
    public static func build(
        operations: [Operation],
        baseWidth: CGFloat
    ) -> RibbonMesh? {
        let elements = operationsToElements(operations)
        guard !elements.isEmpty else { return nil }

        let subpaths = splitIntoSubpaths(elements)
        var meshes: [RibbonMesh] = []
        for sub in subpaths {
            if let m = buildSubpath(sub, baseWidth: baseWidth) {
                meshes.append(m)
            }
        }

        return concatenate(meshes)
    }

    // MARK: Subpath

    private static func buildSubpath(
        _ elements: [PathElement],
        baseWidth: CGFloat
    ) -> RibbonMesh? {
        let isClosed = elements.contains { if case .closeSubpath = $0 { return true } else { return false } }

        let samples = sampleSubpath(elements)
        guard samples.count >= 2 else { return nil }

        let totalLength = samples.last?.cumulativeLength ?? 0
        guard totalLength > 0 else { return nil }

        let halfWidth = baseWidth / 2

        var vertices: [RibbonVertex] = []
        vertices.reserveCapacity(samples.count * 2 + (isClosed ? 2 : 0))

        for sample in samples {
            let n = sample.tangentAngle + .pi / 2
            let dx = cos(n) * halfWidth
            let dy = sin(n) * halfWidth
            let s = Float(sample.cumulativeLength / totalLength)

            let left = SIMD2<Float>(
                Float(sample.point.x + dx),
                Float(sample.point.y + dy)
            )
            let right = SIMD2<Float>(
                Float(sample.point.x - dx),
                Float(sample.point.y - dy)
            )
            // Order: left first (t = +1), then right (t = -1). Triangle-strip
            // rasterizes (left[i], right[i], left[i+1]) and (right[i], left[i+1], right[i+1]).
            vertices.append(RibbonVertex(position: left,  parametric: SIMD2<Float>(s,  1)))
            vertices.append(RibbonVertex(position: right, parametric: SIMD2<Float>(s, -1)))
        }

        if isClosed, let firstLeft = vertices.first, vertices.count >= 2 {
            // Repeat the first pair so the seam closes without a visible gap.
            // s wraps to 1 to keep along-stroke shading continuous.
            let firstRight = vertices[1]
            vertices.append(RibbonVertex(position: firstLeft.position,  parametric: SIMD2<Float>(1,  1)))
            vertices.append(RibbonVertex(position: firstRight.position, parametric: SIMD2<Float>(1, -1)))
        }

        return RibbonMesh(vertices: vertices, isClosed: isClosed, totalLength: totalLength)
    }

    // MARK: Concatenation

    /// Joins multiple subpath meshes into one by inserting degenerate
    /// triangles between them. For triangle-strip primitives, repeating
    /// the last vertex of mesh A and the first vertex of mesh B collapses
    /// the connecting triangles to zero area, so they don't render.
    private static func concatenate(_ meshes: [RibbonMesh]) -> RibbonMesh? {
        guard let first = meshes.first else { return nil }
        guard meshes.count > 1 else { return first }

        var combined: [RibbonVertex] = []
        var totalLength: CGFloat = 0
        var anyClosed = false
        for (index, mesh) in meshes.enumerated() {
            if index > 0, let last = combined.last, let next = mesh.vertices.first {
                combined.append(last) // degenerate
                combined.append(next) // degenerate
            }
            combined.append(contentsOf: mesh.vertices)
            totalLength += mesh.totalLength
            anyClosed = anyClosed || mesh.isClosed
        }
        return RibbonMesh(vertices: combined, isClosed: anyClosed, totalLength: totalLength)
    }
}

// MARK: - Internal sampling (mirrors StrokeToFillConverter)

extension RibbonMeshBuilder {

    enum PathElement {
        case move(to: CGPoint)
        case line(to: CGPoint)
        case quadCurve(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case closeSubpath
    }

    struct Sample {
        let point: CGPoint
        let tangentAngle: CGFloat
        let cumulativeLength: CGFloat
    }

    static func operationsToElements(_ operations: [Operation]) -> [PathElement] {
        var out: [PathElement] = []
        out.reserveCapacity(operations.count)
        for op in operations {
            switch op {
            case let m as Move:
                out.append(.move(to: m.point.cgPoint))
            case let l as LineTo:
                out.append(.line(to: l.point.cgPoint))
            case let q as QuadraticCurveTo:
                out.append(.quadCurve(to: q.point.cgPoint, control: q.controlPoint.cgPoint))
            case let c as BezierCurveTo:
                out.append(.curve(
                    to: c.point.cgPoint,
                    control1: c.controlPoint1.cgPoint,
                    control2: c.controlPoint2.cgPoint
                ))
            case _ as Close:
                out.append(.closeSubpath)
            default:
                break
            }
        }
        return out
    }

    static func splitIntoSubpaths(_ elements: [PathElement]) -> [[PathElement]] {
        var out: [[PathElement]] = []
        var current: [PathElement] = []
        for el in elements {
            if case .move = el {
                if !current.isEmpty { out.append(current) }
                current = [el]
            } else {
                current.append(el)
            }
        }
        if !current.isEmpty { out.append(current) }
        return out
    }

    static func sampleSubpath(_ elements: [PathElement]) -> [Sample] {
        var samples: [Sample] = []
        samples.reserveCapacity(elements.count * 4)

        var current = CGPoint.zero
        var subpathStart: CGPoint? = nil
        var acc: CGFloat = 0

        @inline(__always) func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            let dx = b.x - a.x; let dy = b.y - a.y
            return (dx * dx + dy * dy).squareRoot()
        }

        for (i, element) in elements.enumerated() {
            switch element {
            case .move(let to):
                current = to
                subpathStart = to
                let tan = initialTangent(elements: elements, startIndex: i)
                samples.append(Sample(point: to, tangentAngle: tan, cumulativeLength: 0))

            case .line(let to):
                let len = dist(current, to)
                guard len > 0 else { current = to; continue }
                let n = max(2, Int((len / maxSampleSpacing).rounded(.up)))
                let tan = atan2(to.y - current.y, to.x - current.x)
                for k in 1...n {
                    let t = CGFloat(k) / CGFloat(n)
                    let p = lerp(current, to, t)
                    samples.append(Sample(point: p, tangentAngle: tan, cumulativeLength: acc + len * t))
                }
                acc += len
                current = to

            case .quadCurve(let to, let control):
                let len = quadLength(from: current, to: to, control: control)
                guard len > 0 else { current = to; continue }
                let n = adaptiveQuadCount(from: current, to: to, control: control, length: len)
                for k in 1...n {
                    let t = CGFloat(k) / CGFloat(n)
                    let p = quadPoint(from: current, to: to, control: control, t: t)
                    let tan = quadTangent(from: current, to: to, control: control, t: t)
                    samples.append(Sample(point: p, tangentAngle: tan, cumulativeLength: acc + len * t))
                }
                acc += len
                current = to

            case .curve(let to, let c1, let c2):
                let len = cubicLength(from: current, to: to, c1: c1, c2: c2)
                guard len > 0 else { current = to; continue }
                let n = adaptiveCubicCount(from: current, to: to, c1: c1, c2: c2, length: len)
                for k in 1...n {
                    let t = CGFloat(k) / CGFloat(n)
                    let p = cubicPoint(from: current, to: to, c1: c1, c2: c2, t: t)
                    let tan = cubicTangent(from: current, to: to, c1: c1, c2: c2, t: t)
                    samples.append(Sample(point: p, tangentAngle: tan, cumulativeLength: acc + len * t))
                }
                acc += len
                current = to

            case .closeSubpath:
                guard let start = subpathStart else { continue }
                let len = dist(current, start)
                guard len > 0 else { continue }
                let n = max(2, Int((len / maxSampleSpacing).rounded(.up)))
                let tan = atan2(start.y - current.y, start.x - current.x)
                for k in 1...n {
                    let t = CGFloat(k) / CGFloat(n)
                    let p = lerp(current, start, t)
                    samples.append(Sample(point: p, tangentAngle: tan, cumulativeLength: acc + len * t))
                }
                acc += len
                current = start
            }
        }
        return samples
    }

    static func initialTangent(elements: [PathElement], startIndex: Int) -> CGFloat {
        guard startIndex < elements.count, case .move(let from) = elements[startIndex] else { return 0 }
        for i in (startIndex + 1)..<elements.count {
            switch elements[i] {
            case .line(let to):           return atan2(to.y - from.y, to.x - from.x)
            case .quadCurve(_, let c):    return atan2(c.y - from.y, c.x - from.x)
            case .curve(_, let c1, _):    return atan2(c1.y - from.y, c1.x - from.x)
            case .move:                   return 0
            case .closeSubpath:           continue
            }
        }
        return 0
    }

    @inline(__always)
    static func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    static func quadPoint(from a: CGPoint, to b: CGPoint, control c: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * a.x + 2 * u * t * c.x + t * t * b.x,
            y: u * u * a.y + 2 * u * t * c.y + t * t * b.y
        )
    }

    static func quadTangent(from a: CGPoint, to b: CGPoint, control c: CGPoint, t: CGFloat) -> CGFloat {
        let u = 1 - t
        let dx = 2 * u * (c.x - a.x) + 2 * t * (b.x - c.x)
        let dy = 2 * u * (c.y - a.y) + 2 * t * (b.y - c.y)
        return atan2(dy, dx)
    }

    static func quadLength(from a: CGPoint, to b: CGPoint, control c: CGPoint) -> CGFloat {
        var prev = a
        var len: CGFloat = 0
        for k in 1...8 {
            let t = CGFloat(k) / 8
            let p = quadPoint(from: a, to: b, control: c, t: t)
            let dx = p.x - prev.x; let dy = p.y - prev.y
            len += (dx * dx + dy * dy).squareRoot()
            prev = p
        }
        return len
    }

    static func cubicPoint(from a: CGPoint, to b: CGPoint, c1: CGPoint, c2: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        let uu = u * u, uuu = uu * u
        let tt = t * t, ttt = tt * t
        return CGPoint(
            x: uuu * a.x + 3 * uu * t * c1.x + 3 * u * tt * c2.x + ttt * b.x,
            y: uuu * a.y + 3 * uu * t * c1.y + 3 * u * tt * c2.y + ttt * b.y
        )
    }

    static func cubicTangent(from a: CGPoint, to b: CGPoint, c1: CGPoint, c2: CGPoint, t: CGFloat) -> CGFloat {
        let u = 1 - t
        let uu = u * u, tt = t * t
        let dx = 3 * uu * (c1.x - a.x) + 6 * u * t * (c2.x - c1.x) + 3 * tt * (b.x - c2.x)
        let dy = 3 * uu * (c1.y - a.y) + 6 * u * t * (c2.y - c1.y) + 3 * tt * (b.y - c2.y)
        return atan2(dy, dx)
    }

    static func cubicLength(from a: CGPoint, to b: CGPoint, c1: CGPoint, c2: CGPoint) -> CGFloat {
        var prev = a
        var len: CGFloat = 0
        for k in 1...8 {
            let t = CGFloat(k) / 8
            let p = cubicPoint(from: a, to: b, c1: c1, c2: c2, t: t)
            let dx = p.x - prev.x; let dy = p.y - prev.y
            len += (dx * dx + dy * dy).squareRoot()
            prev = p
        }
        return len
    }

    static func adaptiveQuadCount(from a: CGPoint, to b: CGPoint, control c: CGPoint, length: CGFloat) -> Int {
        let chord = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
        let polygon = ((c.x - a.x) * (c.x - a.x) + (c.y - a.y) * (c.y - a.y)).squareRoot()
                    + ((b.x - c.x) * (b.x - c.x) + (b.y - c.y) * (b.y - c.y)).squareRoot()
        let curviness = chord > 0.001 ? polygon / chord : 1
        let raw = Int((curviness - 1) * 4 + (length / maxSampleSpacing).rounded(.up))
        return max(4, min(64, raw))
    }

    static func adaptiveCubicCount(from a: CGPoint, to b: CGPoint, c1: CGPoint, c2: CGPoint, length: CGFloat) -> Int {
        let chord = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
        let polygon = ((c1.x - a.x) * (c1.x - a.x) + (c1.y - a.y) * (c1.y - a.y)).squareRoot()
                    + ((c2.x - c1.x) * (c2.x - c1.x) + (c2.y - c1.y) * (c2.y - c1.y)).squareRoot()
                    + ((b.x - c2.x) * (b.x - c2.x) + (b.y - c2.y) * (b.y - c2.y)).squareRoot()
        let curviness = chord > 0.001 ? polygon / chord : 1
        let raw = Int((curviness - 1) * 4.8 + (length / maxSampleSpacing).rounded(.up))
        return max(4, min(64, raw))
    }
}

// MARK: - CGPoint helpers

private extension Point {
    var cgPoint: CGPoint { CGPoint(x: CGFloat(x), y: CGFloat(y)) }
}
