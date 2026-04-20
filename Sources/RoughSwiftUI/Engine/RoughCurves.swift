//
//  RoughCurves.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Continuous-Bezier replacements for the sampled-point stroke generators
//  in `RoughMath`. Used when `Options.strokeContinuity == .continuous`.
//
//  Design principles:
//
//  - Every curved shape is expressed as a small fixed number of cubic
//    Bezier segments that match the underlying parametric geometry. A
//    circle is 4 cubics per pass, not N small cubics derived from N
//    sampled points.
//
//  - Endpoints shared between neighboring segments are jittered ONCE and
//    reused. This preserves C⁰ continuity at the seam while still letting
//    each segment's interior wobble independently via control-handle
//    jitter.
//
//  - Polygon/line generators emit one continuous subpath per pass so the
//    corners of a "rough rectangle" actually share endpoints rather than
//    being eight independent disjoint passes.
//
//  - Two passes are emitted per shape (matching rough.js's signature
//    double-stroke look) but each pass is itself a single continuous
//    subpath.
//

import Foundation
import CoreGraphics

/// Continuous-Bezier shape generators. Public entry points are static and
/// pure (no shared state); they receive the same `Options` as the legacy
/// generators in `RoughMath`.
public enum RoughCurves {

    // MARK: - Constants

    /// Cubic Bezier approximation constant for a quarter-circle:
    /// `c = 4·(√2 − 1) / 3`. With endpoints at the cardinal axes, control
    /// points offset by `c·r` along the tangent produce a quarter circle
    /// accurate to ~0.027% of `r`.
    @usableFromInline
    static let quarterCircleHandle: Float = 0.5522847498307933

    // MARK: - Random helpers

    /// Returns a small jittered offset suitable for endpoint or handle
    /// perturbation. Magnitude scales with `options.maxRandomnessOffset`
    /// and `options.roughness` via `RoughMath.randOffset`.
    @inline(__always)
    static func jitter(_ amount: Float, options: Options) -> Float {
        RoughMath.randOffset(amount, options: options)
    }

    /// Jitters a single point in both X and Y by up to `amount` (scaled by
    /// roughness). The point is returned by value; the input is unchanged.
    @inline(__always)
    static func jitter(_ point: SIMD2<Float>, by amount: Float, options: Options) -> SIMD2<Float> {
        SIMD2<Float>(
            point.x + jitter(amount, options: options),
            point.y + jitter(amount, options: options)
        )
    }

    // MARK: - Ellipse / Circle

    /// Generates continuous-Bezier operations for an ellipse using the
    /// 4-cubic construction. Two passes are produced (matching
    /// `RoughMath.ellipseOps`); each pass is a single subpath of one
    /// `Move` plus 4 `BezierCurveTo` operations.
    public static func ellipseOps(
        cx: Float, cy: Float,
        rx: Float, ry: Float,
        options: Options
    ) -> [Operation] {
        let pass1 = ellipsePass(cx: cx, cy: cy, rx: rx, ry: ry,
                                jitterScale: 1.0, options: options)
        let pass2 = ellipsePass(cx: cx, cy: cy, rx: rx, ry: ry,
                                jitterScale: 1.5, options: options)
        return pass1 + pass2
    }

    /// Generates a single ellipse pass.
    ///
    /// `jitterScale` controls how much endpoint/handle jitter is applied
    /// (the second pass uses 1.5× to give visible variation between the
    /// two passes).
    private static func ellipsePass(
        cx: Float, cy: Float,
        rx: Float, ry: Float,
        jitterScale: Float,
        options: Options
    ) -> [Operation] {
        let endpointJitter = options.maxRandomnessOffset * jitterScale
        let handleJitter = options.maxRandomnessOffset * jitterScale * 0.6

        // Four cardinal endpoints (right, bottom, left, top in screen-y-down).
        let east  = jitter(SIMD2<Float>(cx + rx, cy), by: endpointJitter, options: options)
        let south = jitter(SIMD2<Float>(cx, cy + ry), by: endpointJitter, options: options)
        let west  = jitter(SIMD2<Float>(cx - rx, cy), by: endpointJitter, options: options)
        let north = jitter(SIMD2<Float>(cx, cy - ry), by: endpointJitter, options: options)

        // Handle distances along the tangent at each cardinal.
        let kx = quarterCircleHandle * rx
        let ky = quarterCircleHandle * ry

        // East→South quadrant: handle1 leaves east heading +y; handle2
        // arrives at south heading −x.
        let h_es_1 = jitter(SIMD2<Float>(cx + rx,        cy + ky), by: handleJitter, options: options)
        let h_es_2 = jitter(SIMD2<Float>(cx + kx,        cy + ry), by: handleJitter, options: options)

        // South→West: handle1 leaves south heading −x; handle2 arrives at west heading −y.
        let h_sw_1 = jitter(SIMD2<Float>(cx - kx,        cy + ry), by: handleJitter, options: options)
        let h_sw_2 = jitter(SIMD2<Float>(cx - rx,        cy + ky), by: handleJitter, options: options)

        // West→North: handle1 leaves west heading −y; handle2 arrives at north heading +x.
        let h_wn_1 = jitter(SIMD2<Float>(cx - rx,        cy - ky), by: handleJitter, options: options)
        let h_wn_2 = jitter(SIMD2<Float>(cx - kx,        cy - ry), by: handleJitter, options: options)

        // North→East: handle1 leaves north heading +x; handle2 arrives at east heading +y.
        let h_ne_1 = jitter(SIMD2<Float>(cx + kx,        cy - ry), by: handleJitter, options: options)
        let h_ne_2 = jitter(SIMD2<Float>(cx + rx,        cy - ky), by: handleJitter, options: options)

        var ops: [Operation] = []
        ops.reserveCapacity(5)
        ops.append(Move(data: [east.x, east.y]))
        ops.append(BezierCurveTo(data: [h_es_1.x, h_es_1.y, h_es_2.x, h_es_2.y, south.x, south.y]))
        ops.append(BezierCurveTo(data: [h_sw_1.x, h_sw_1.y, h_sw_2.x, h_sw_2.y, west.x, west.y]))
        ops.append(BezierCurveTo(data: [h_wn_1.x, h_wn_1.y, h_wn_2.x, h_wn_2.y, north.x, north.y]))
        ops.append(BezierCurveTo(data: [h_ne_1.x, h_ne_1.y, h_ne_2.x, h_ne_2.y, east.x, east.y]))
        return ops
    }

    // MARK: - Arc

    /// Generates continuous-Bezier operations for an arc spanning
    /// `[start, stop]` (radians, screen-y-down). The arc is split into at
    /// most 4 cubic segments at quadrant boundaries; the final segment may
    /// span less than a quadrant and uses the analytical handle-distance
    /// formula `(4/3)·tan(Δ/4)·r`.
    public static func arcOps(
        cx: Float, cy: Float,
        rx: Float, ry: Float,
        start: Float, stop: Float,
        closed: Bool,
        options: Options
    ) -> [Operation] {
        let pass1 = arcPass(cx: cx, cy: cy, rx: rx, ry: ry,
                            start: start, stop: stop,
                            closed: closed,
                            jitterScale: 1.0, options: options)
        let pass2 = arcPass(cx: cx, cy: cy, rx: rx, ry: ry,
                            start: start, stop: stop,
                            closed: closed,
                            jitterScale: 1.5, options: options)
        return pass1 + pass2
    }

    /// Generates a single arc pass split at quadrant boundaries.
    private static func arcPass(
        cx: Float, cy: Float,
        rx: Float, ry: Float,
        start: Float, stop: Float,
        closed: Bool,
        jitterScale: Float,
        options: Options
    ) -> [Operation] {
        // Normalize so start ≤ stop and span ≤ 2π.
        var s = start
        var e = stop
        while e < s { e += 2 * .pi }
        if e - s > 2 * .pi { e = s + 2 * .pi }

        let endpointJitter = options.maxRandomnessOffset * jitterScale
        let handleJitter = options.maxRandomnessOffset * jitterScale * 0.6

        // Split the arc at quadrant boundaries (multiples of π/2 above s).
        var splits: [Float] = [s]
        let firstBoundary = (s / (.pi / 2)).rounded(.down) * (.pi / 2) + (.pi / 2)
        var b = firstBoundary
        while b < e {
            if b > s { splits.append(b) }
            b += .pi / 2
        }
        splits.append(e)

        // Compute jittered endpoints at each split, and segment-by-segment
        // emit a bowed cubic.
        var endpoints: [SIMD2<Float>] = []
        endpoints.reserveCapacity(splits.count)
        for angle in splits {
            let p = SIMD2<Float>(cx + rx * cos(angle), cy + ry * sin(angle))
            endpoints.append(jitter(p, by: endpointJitter, options: options))
        }

        var ops: [Operation] = []
        ops.reserveCapacity(splits.count + (closed ? 2 : 0))
        ops.append(Move(data: [endpoints[0].x, endpoints[0].y]))

        for i in 0..<(splits.count - 1) {
            let a0 = splits[i]
            let a1 = splits[i + 1]
            let delta = a1 - a0
            // Analytical control-handle distance for a unit-radius arc of
            // angular span `delta`: (4/3)·tan(delta/4). Multiply by the
            // local radius along each axis.
            let alpha = (4.0 / 3.0) * tan(delta / 4)
            let c1x = cx + rx * (cos(a0) - alpha * sin(a0))
            let c1y = cy + ry * (sin(a0) + alpha * cos(a0))
            let c2x = cx + rx * (cos(a1) + alpha * sin(a1))
            let c2y = cy + ry * (sin(a1) - alpha * cos(a1))
            let h1 = jitter(SIMD2<Float>(c1x, c1y), by: handleJitter, options: options)
            let h2 = jitter(SIMD2<Float>(c2x, c2y), by: handleJitter, options: options)
            let p1 = endpoints[i + 1]
            ops.append(BezierCurveTo(data: [h1.x, h1.y, h2.x, h2.y, p1.x, p1.y]))
        }

        if closed {
            // Pie-slice closure: line to center, then back to start.
            ops.append(LineTo(data: [cx, cy]))
            ops.append(LineTo(data: [endpoints[0].x, endpoints[0].y]))
        }

        return ops
    }

    // MARK: - Rounded rectangle

    /// Generates a continuous-Bezier rounded rectangle as a single subpath:
    /// `Move` → 4 sides as bowed cubics, with quarter-circle cubics at
    /// each corner, terminated by `Close`. Two passes are produced for the
    /// double-stroke effect.
    public static func roundedRectangleOps(
        x: Float, y: Float,
        width: Float, height: Float,
        cornerRadius: Float,
        options: Options
    ) -> [Operation] {
        let maxR = min(width, height) / 2
        let r = max(0, min(cornerRadius, maxR))
        if r <= 0 {
            // No corners — fall through to polygon construction.
            let points: [SIMD2<Float>] = [
                SIMD2<Float>(x,         y),
                SIMD2<Float>(x + width, y),
                SIMD2<Float>(x + width, y + height),
                SIMD2<Float>(x,         y + height)
            ]
            return polygonPass(points: points, close: true, jitterScale: 1.0, options: options)
                 + polygonPass(points: points, close: true, jitterScale: 1.5, options: options)
        }

        let pass1 = roundedRectanglePass(x: x, y: y, width: width, height: height,
                                         cornerRadius: r, jitterScale: 1.0, options: options)
        let pass2 = roundedRectanglePass(x: x, y: y, width: width, height: height,
                                         cornerRadius: r, jitterScale: 1.5, options: options)
        return pass1 + pass2
    }

    private static func roundedRectanglePass(
        x: Float, y: Float,
        width: Float, height: Float,
        cornerRadius r: Float,
        jitterScale: Float,
        options: Options
    ) -> [Operation] {
        let endpointJitter = options.maxRandomnessOffset * jitterScale
        let handleJitter = options.maxRandomnessOffset * jitterScale * 0.6
        let k = quarterCircleHandle * r

        // 8 corner-endpoint positions (start and end of each quarter
        // circle), labeled clockwise from the top-left edge.
        let p_tl_v = jitter(SIMD2<Float>(x,             y + r),          by: endpointJitter, options: options) // top-left, bottom of arc (start of left edge going up)
        let p_tl_h = jitter(SIMD2<Float>(x + r,         y),              by: endpointJitter, options: options) // top-left, right of arc (end of arc, start of top edge)
        let p_tr_h = jitter(SIMD2<Float>(x + width - r, y),              by: endpointJitter, options: options) // top-right, left of arc (end of top edge)
        let p_tr_v = jitter(SIMD2<Float>(x + width,     y + r),          by: endpointJitter, options: options) // top-right, bottom of arc (start of right edge)
        let p_br_v = jitter(SIMD2<Float>(x + width,     y + height - r), by: endpointJitter, options: options) // bottom-right, top of arc (end of right edge)
        let p_br_h = jitter(SIMD2<Float>(x + width - r, y + height),     by: endpointJitter, options: options) // bottom-right, left of arc (start of bottom edge)
        let p_bl_h = jitter(SIMD2<Float>(x + r,         y + height),     by: endpointJitter, options: options) // bottom-left, right of arc (end of bottom edge)
        let p_bl_v = jitter(SIMD2<Float>(x,             y + height - r), by: endpointJitter, options: options) // bottom-left, top of arc (start of left edge)

        // Bowed-cubic helper: emits a single cubic from `a` to `b` using
        // perpendicular bowing scaled by `options.bowing` (matches the
        // `lineOps` math in `RoughMath` so visual character is consistent).
        func bowedCubic(from a: SIMD2<Float>, to b: SIMD2<Float>) -> Operation {
            let mid1 = SIMD2<Float>(a.x + (b.x - a.x) * (1.0 / 3.0),
                                    a.y + (b.y - a.y) * (1.0 / 3.0))
            let mid2 = SIMD2<Float>(a.x + (b.x - a.x) * (2.0 / 3.0),
                                    a.y + (b.y - a.y) * (2.0 / 3.0))
            // Perpendicular displacement.
            let bow = options.bowing * options.maxRandomnessOffset / 200
            let dispX = bow * (b.y - a.y)
            let dispY = bow * (a.x - b.x)
            let h1 = SIMD2<Float>(mid1.x + dispX + jitter(handleJitter, options: options),
                                  mid1.y + dispY + jitter(handleJitter, options: options))
            let h2 = SIMD2<Float>(mid2.x + dispX + jitter(handleJitter, options: options),
                                  mid2.y + dispY + jitter(handleJitter, options: options))
            return BezierCurveTo(data: [h1.x, h1.y, h2.x, h2.y, b.x, b.y])
        }

        // Quarter-circle cubic helper.
        func quarterArc(from a: SIMD2<Float>, to b: SIMD2<Float>,
                        cornerCenter cc: SIMD2<Float>) -> Operation {
            // Tangent at `a` points toward `b` along the arc; we offset
            // perpendicular to the radius vector (cc → a).
            let r1 = SIMD2<Float>(a.x - cc.x, a.y - cc.y)  // radius vector to a
            let r2 = SIMD2<Float>(b.x - cc.x, b.y - cc.y)  // radius vector to b
            // Tangent at `a`: rotate r1 by +90° (clockwise screen-y-down).
            let t1 = SIMD2<Float>(-r1.y, r1.x)
            // Tangent at `b`: rotate r2 by −90°.
            let t2 = SIMD2<Float>(r2.y, -r2.x)
            // Determine the orientation: if going clockwise around the
            // rectangle, t1 should point toward b and t2 away from a.
            // Check sign by comparing t1 with (b - a).
            let toward = SIMD2<Float>(b.x - a.x, b.y - a.y)
            let sign: Float = (t1.x * toward.x + t1.y * toward.y) >= 0 ? 1 : -1

            // `t1` and `t2` are perpendicular to the radius vectors and
            // already scaled by `r` (since they were rotations of vectors
            // of length r). Multiply by the standard quarter-circle handle
            // constant to land at the correct control-point distance.
            let h1 = SIMD2<Float>(a.x + sign * t1.x * quarterCircleHandle + jitter(handleJitter, options: options),
                                  a.y + sign * t1.y * quarterCircleHandle + jitter(handleJitter, options: options))
            let h2 = SIMD2<Float>(b.x + sign * t2.x * quarterCircleHandle + jitter(handleJitter, options: options),
                                  b.y + sign * t2.y * quarterCircleHandle + jitter(handleJitter, options: options))
            return BezierCurveTo(data: [h1.x, h1.y, h2.x, h2.y, b.x, b.y])
        }

        // Corner centers.
        let cc_tl = SIMD2<Float>(x + r,         y + r)
        let cc_tr = SIMD2<Float>(x + width - r, y + r)
        let cc_br = SIMD2<Float>(x + width - r, y + height - r)
        let cc_bl = SIMD2<Float>(x + r,         y + height - r)

        var ops: [Operation] = []
        ops.reserveCapacity(10)
        ops.append(Move(data: [p_tl_h.x, p_tl_h.y]))
        ops.append(bowedCubic(from: p_tl_h, to: p_tr_h))            // top edge
        ops.append(quarterArc(from: p_tr_h, to: p_tr_v, cornerCenter: cc_tr))
        ops.append(bowedCubic(from: p_tr_v, to: p_br_v))            // right edge
        ops.append(quarterArc(from: p_br_v, to: p_br_h, cornerCenter: cc_br))
        ops.append(bowedCubic(from: p_br_h, to: p_bl_h))            // bottom edge
        ops.append(quarterArc(from: p_bl_h, to: p_bl_v, cornerCenter: cc_bl))
        ops.append(bowedCubic(from: p_bl_v, to: p_tl_v))            // left edge
        ops.append(quarterArc(from: p_tl_v, to: p_tl_h, cornerCenter: cc_tl))
        ops.append(Close())
        return ops
    }

    // MARK: - Egg

    /// Generates a continuous-Bezier egg shape: an ellipse whose horizontal
    /// radius is modulated as `rx · (1 − tilt · sin(angle))`. Built from
    /// 4 cubic Beziers between the four cardinal points, with handle
    /// distances scaled along each axis by the local effective radius.
    public static func eggOps(
        cx: Float, cy: Float,
        width: Float, height: Float,
        tilt: Float,
        options: Options
    ) -> [Operation] {
        let pass1 = eggPass(cx: cx, cy: cy, width: width, height: height,
                            tilt: tilt, jitterScale: 1.0, options: options)
        let pass2 = eggPass(cx: cx, cy: cy, width: width, height: height,
                            tilt: tilt, jitterScale: 1.5, options: options)
        return pass1 + pass2
    }

    private static func eggPass(
        cx: Float, cy: Float,
        width: Float, height: Float,
        tilt: Float,
        jitterScale: Float,
        options: Options
    ) -> [Operation] {
        let rx = width / 2
        let ry = height / 2
        let endpointJitter = options.maxRandomnessOffset * jitterScale
        let handleJitter = options.maxRandomnessOffset * jitterScale * 0.6

        // Effective horizontal radius at each cardinal angle. With
        // angle = 0 (east, sin=0) the modulation factor is 1; at south
        // (sin=+1) it is (1 − tilt); at north (sin=−1) it is (1 + tilt).
        let rxEast  = rx * (1 - tilt * 0)   // = rx
        let rxSouth = rx * (1 - tilt * 1)
        let rxWest  = rx * (1 - tilt * 0)   // = rx
        let rxNorth = rx * (1 - tilt * -1)  // = rx · (1 + tilt)

        let east  = jitter(SIMD2<Float>(cx + rxEast,  cy),       by: endpointJitter, options: options)
        let south = jitter(SIMD2<Float>(cx,           cy + ry),  by: endpointJitter, options: options)
        let west  = jitter(SIMD2<Float>(cx - rxWest,  cy),       by: endpointJitter, options: options)
        let north = jitter(SIMD2<Float>(cx,           cy - ry),  by: endpointJitter, options: options)

        // Per-quadrant handle distances. Each handle is offset from its
        // endpoint along the local tangent by `quarterCircleHandle ·
        // (axis radius)`.
        let ky = quarterCircleHandle * ry

        // East→South: leave east heading +y (handle distance ky), arrive
        // south heading -x (handle distance using rxSouth on the South
        // quadrant's x-extent).
        let h_es_1 = jitter(SIMD2<Float>(cx + rxEast,                    cy + ky),
                            by: handleJitter, options: options)
        let h_es_2 = jitter(SIMD2<Float>(cx + quarterCircleHandle * rxSouth, cy + ry),
                            by: handleJitter, options: options)

        // South→West.
        let h_sw_1 = jitter(SIMD2<Float>(cx - quarterCircleHandle * rxSouth, cy + ry),
                            by: handleJitter, options: options)
        let h_sw_2 = jitter(SIMD2<Float>(cx - rxWest,                    cy + ky),
                            by: handleJitter, options: options)

        // West→North.
        let h_wn_1 = jitter(SIMD2<Float>(cx - rxWest,                    cy - ky),
                            by: handleJitter, options: options)
        let h_wn_2 = jitter(SIMD2<Float>(cx - quarterCircleHandle * rxNorth, cy - ry),
                            by: handleJitter, options: options)

        // North→East.
        let h_ne_1 = jitter(SIMD2<Float>(cx + quarterCircleHandle * rxNorth, cy - ry),
                            by: handleJitter, options: options)
        let h_ne_2 = jitter(SIMD2<Float>(cx + rxEast,                    cy - ky),
                            by: handleJitter, options: options)

        var ops: [Operation] = []
        ops.reserveCapacity(5)
        ops.append(Move(data: [east.x, east.y]))
        ops.append(BezierCurveTo(data: [h_es_1.x, h_es_1.y, h_es_2.x, h_es_2.y, south.x, south.y]))
        ops.append(BezierCurveTo(data: [h_sw_1.x, h_sw_1.y, h_sw_2.x, h_sw_2.y, west.x, west.y]))
        ops.append(BezierCurveTo(data: [h_wn_1.x, h_wn_1.y, h_wn_2.x, h_wn_2.y, north.x, north.y]))
        ops.append(BezierCurveTo(data: [h_ne_1.x, h_ne_1.y, h_ne_2.x, h_ne_2.y, east.x, east.y]))
        return ops
    }

    // MARK: - Rectangle / Polygon / Linear path / Line

    /// Generates a continuous-Bezier rectangle outline as one subpath per
    /// pass (two passes total).
    public static func rectangleOps(
        x: Float, y: Float,
        width: Float, height: Float,
        options: Options
    ) -> [Operation] {
        let points: [SIMD2<Float>] = [
            SIMD2<Float>(x,         y),
            SIMD2<Float>(x + width, y),
            SIMD2<Float>(x + width, y + height),
            SIMD2<Float>(x,         y + height)
        ]
        return polygonPass(points: points, close: true, jitterScale: 1.0, options: options)
             + polygonPass(points: points, close: true, jitterScale: 1.5, options: options)
    }

    /// Generates a continuous-Bezier polygon outline.
    public static func polygonOps(points: [[Float]], options: Options) -> [Operation] {
        let pts = points.map { SIMD2<Float>($0[0], $0[1]) }
        return polygonPass(points: pts, close: true, jitterScale: 1.0, options: options)
             + polygonPass(points: pts, close: true, jitterScale: 1.5, options: options)
    }

    /// Generates a continuous-Bezier open linear path.
    public static func linearPathOps(points: [[Float]], close: Bool, options: Options) -> [Operation] {
        let pts = points.map { SIMD2<Float>($0[0], $0[1]) }
        return polygonPass(points: pts, close: close, jitterScale: 1.0, options: options)
             + polygonPass(points: pts, close: close, jitterScale: 1.5, options: options)
    }

    /// Single-pass polygon/linear-path generator: emits one continuous
    /// subpath where each edge is a bowed cubic and adjacent edges share
    /// jittered endpoints.
    private static func polygonPass(
        points: [SIMD2<Float>],
        close: Bool,
        jitterScale: Float,
        options: Options
    ) -> [Operation] {
        guard points.count >= 2 else { return [] }
        let endpointJitter = options.maxRandomnessOffset * jitterScale
        let handleJitter = options.maxRandomnessOffset * jitterScale * 0.6

        // Jitter each input vertex once; reuse for adjacent edges.
        let jittered = points.map { jitter($0, by: endpointJitter, options: options) }

        var ops: [Operation] = []
        ops.reserveCapacity(jittered.count + (close ? 2 : 1))
        ops.append(Move(data: [jittered[0].x, jittered[0].y]))

        let edgeCount = close ? jittered.count : jittered.count - 1
        for i in 0..<edgeCount {
            let a = jittered[i]
            let b = jittered[(i + 1) % jittered.count]
            ops.append(bowedCubic(from: a, to: b, handleJitter: handleJitter, options: options))
        }

        if close {
            ops.append(Close())
        }
        return ops
    }

    /// Emits a single bowed cubic from `a` to `b`. Bowing math mirrors
    /// `RoughMath.lineOps` so the visual character matches the legacy
    /// generator: control points at 1/3 and 2/3 along the chord, displaced
    /// perpendicularly by `bowing · maxRandomnessOffset / 200` plus
    /// per-handle jitter.
    @inline(__always)
    private static func bowedCubic(
        from a: SIMD2<Float>,
        to b: SIMD2<Float>,
        handleJitter: Float,
        options: Options
    ) -> Operation {
        let mid1 = SIMD2<Float>(a.x + (b.x - a.x) * (1.0 / 3.0),
                                a.y + (b.y - a.y) * (1.0 / 3.0))
        let mid2 = SIMD2<Float>(a.x + (b.x - a.x) * (2.0 / 3.0),
                                a.y + (b.y - a.y) * (2.0 / 3.0))
        let bow = options.bowing * options.maxRandomnessOffset / 200
        let dispX = bow * (b.y - a.y)
        let dispY = bow * (a.x - b.x)
        let h1 = SIMD2<Float>(mid1.x + dispX + jitter(handleJitter, options: options),
                              mid1.y + dispY + jitter(handleJitter, options: options))
        let h2 = SIMD2<Float>(mid2.x + dispX + jitter(handleJitter, options: options),
                              mid2.y + dispY + jitter(handleJitter, options: options))
        return BezierCurveTo(data: [h1.x, h1.y, h2.x, h2.y, b.x, b.y])
    }

    /// Generates continuous-Bezier line operations: two passes, each a
    /// single bowed cubic between the (independently jittered) endpoints.
    public static func doubleLineOps(
        x1: Float, y1: Float,
        x2: Float, y2: Float,
        options: Options
    ) -> [Operation] {
        var ops: [Operation] = []
        ops.reserveCapacity(4)
        for jitterScale in [Float(1.0), Float(1.5)] {
            let endpointJitter = options.maxRandomnessOffset * jitterScale
            let handleJitter = options.maxRandomnessOffset * jitterScale * 0.6
            let a = jitter(SIMD2<Float>(x1, y1), by: endpointJitter, options: options)
            let b = jitter(SIMD2<Float>(x2, y2), by: endpointJitter, options: options)
            ops.append(Move(data: [a.x, a.y]))
            ops.append(bowedCubic(from: a, to: b, handleJitter: handleJitter, options: options))
        }
        return ops
    }
}
