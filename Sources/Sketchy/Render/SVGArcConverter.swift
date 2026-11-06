//
//  SVGArcConverter.swift
//  Sketchy
//
//  Endpoint-parameterized SVG elliptical arcs, converted with the SVG 1.1
//  implementation notes (F.6.5 and F.6.6) and drawn as cubic Béziers.
//

import CoreGraphics
import Foundation

/// Converts an SVG elliptical arc into cubic Bézier segments.
///
/// SVG stores an arc as the current point, radii, x-axis rotation, the
/// large-arc and sweep flags, and the endpoint. CoreGraphics has no matching
/// primitive, so each arc becomes one to four cubics of at most 90°.
public enum SVGArcConverter {
    /// One cubic from the previous point to `point`.
    public struct CubicCurve: Equatable {
        public let control1: CGPoint
        public let control2: CGPoint
        public let point: CGPoint
    }

    /// Center-form arc after the SVG out-of-range adjustments.
    struct Geometry: Equatable {
        /// Ellipse center in the same coordinate space as the endpoints.
        let center: CGPoint
        /// Radii after the absolute-value and scale-up corrections.
        let rx: CGFloat
        let ry: CGFloat
        /// Signed sweep from the start angle to the end angle, in radians.
        /// Positive follows sweep flag 1.
        let deltaAngle: CGFloat
        let curves: [CubicCurve]
    }

    /// What an arc command should draw.
    enum Conversion: Equatable {
        /// The endpoints are the same point. F.6.2 omits the segment.
        case omitted
        /// `rx` or `ry` is zero. F.6.2 draws a straight line to the endpoint.
        case line
        case cubic(Geometry)
    }

    /// Classifies `start` → `end` using the SVG endpoint-to-center conversion.
    ///
    /// Identical endpoints are omitted even when a radius is zero. Otherwise a
    /// zero radius is a line. Negative radii use their absolute value. Radii
    /// that cannot reach the endpoint are scaled by the same factor until the
    /// ellipse passes through both points (F.6.6).
    static func convert(
        from start: CGPoint,
        to end: CGPoint,
        rx inputRx: CGFloat,
        ry inputRy: CGFloat,
        xAxisRotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) -> Conversion {
        // F.6.2: identical endpoints omit the segment, before the zero-radius rule.
        guard start != end else { return .omitted }

        var rx = abs(inputRx)
        var ry = abs(inputRy)
        guard rx > 0, ry > 0 else { return .line }

        // φ is taken mod 360°. cos/sin are already 360° periodic.
        let phi = xAxisRotation * .pi / 180
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)

        // F.6.5.1. Translate to the midpoint, then rotate into ellipse axes.
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        let x1Prime = cosPhi * dx + sinPhi * dy
        let y1Prime = -sinPhi * dx + cosPhi * dy

        // F.6.6.2–3. Scale both radii when the endpoints lie outside the ellipse.
        let radiiCheck = (x1Prime * x1Prime) / (rx * rx) + (y1Prime * y1Prime) / (ry * ry)
        if radiiCheck > 1 {
            let factor = sqrt(radiiCheck)
            rx *= factor
            ry *= factor
        }

        let rx2 = rx * rx
        let ry2 = ry * ry
        let x1p2 = x1Prime * x1Prime
        let y1p2 = y1Prime * y1Prime

        // F.6.5.2. The sign is negative when the flags are equal.
        let numerator = max(0, rx2 * ry2 - rx2 * y1p2 - ry2 * x1p2)
        let denominator = rx2 * y1p2 + ry2 * x1p2
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = denominator == 0 ? 0 : sign * sqrt(numerator / denominator)
        let cxPrime = coefficient * (rx * y1Prime / ry)
        let cyPrime = coefficient * (-ry * x1Prime / rx)

        // F.6.5.3.
        let center = CGPoint(
            x: cosPhi * cxPrime - sinPhi * cyPrime + (start.x + end.x) / 2,
            y: sinPhi * cxPrime + cosPhi * cyPrime + (start.y + end.y) / 2
        )

        let ux = (x1Prime - cxPrime) / rx
        let uy = (y1Prime - cyPrime) / ry
        let vx = (-x1Prime - cxPrime) / rx
        let vy = (-y1Prime - cyPrime) / ry

        // F.6.5.5–6. Δθ has the sign of the sweep flag and lies in (−360°, 360°).
        let startAngle = vectorAngle(ux: 1, uy: 0, vx: ux, vy: uy)
        var deltaAngle = vectorAngle(ux: ux, uy: uy, vx: vx, vy: vy)
        if !sweep && deltaAngle > 0 {
            deltaAngle -= 2 * .pi
        } else if sweep && deltaAngle < 0 {
            deltaAngle += 2 * .pi
        }

        let segmentCount = max(1, Int(ceil(abs(deltaAngle) / (.pi / 2) - 1e-12)))
        let segmentDelta = deltaAngle / CGFloat(segmentCount)
        var curves: [CubicCurve] = []
        curves.reserveCapacity(segmentCount)
        for segmentIndex in 0..<segmentCount {
            let theta1 = startAngle + CGFloat(segmentIndex) * segmentDelta
            let theta2 = theta1 + segmentDelta
            let isLast = segmentIndex == segmentCount - 1
            curves.append(
                cubicCurve(
                    center: center,
                    rx: rx,
                    ry: ry,
                    phi: phi,
                    theta1: theta1,
                    theta2: theta2,
                    end: isLast ? end : nil
                )
            )
        }

        return .cubic(Geometry(center: center, rx: rx, ry: ry, deltaAngle: deltaAngle, curves: curves))
    }

    /// Cubics for one arc. Empty when the segment is omitted or is a straight line.
    ///
    /// Callers that need to tell those two cases apart use `convert`.
    public static func cubicCurves(
        from start: CGPoint,
        to end: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        xAxisRotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) -> [CubicCurve] {
        guard case let .cubic(geometry) = convert(
            from: start,
            to: end,
            rx: rx,
            ry: ry,
            xAxisRotation: xAxisRotation,
            largeArc: largeArc,
            sweep: sweep
        ) else {
            return []
        }
        return geometry.curves
    }

    /// Signed angle from `(ux, uy)` to `(vx, vy)`, in (−π, π].
    ///
    /// F.6.5.4. The sign is the sign of the cross product. A zero cross product
    /// (exactly 0° or 180°) stays non-negative, and the sweep adjustment in
    /// `convert` turns a positive 180° into −180° when the sweep flag is 0.
    private static func vectorAngle(ux: CGFloat, uy: CGFloat, vx: CGFloat, vy: CGFloat) -> CGFloat {
        let dot = ux * vx + uy * vy
        let length = sqrt((ux * ux + uy * uy) * (vx * vx + vy * vy))
        guard length > 0 else { return 0 }

        let clamped = max(-1, min(1, dot / length))
        let sign: CGFloat = (ux * vy - uy * vx) < 0 ? -1 : 1
        return sign * acos(clamped)
    }

    /// One cubic of at most 90°. `end` replaces the parametric endpoint so the
    /// last segment lands on the SVG point instead of a reconstructed one.
    private static func cubicCurve(
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        phi: CGFloat,
        theta1: CGFloat,
        theta2: CGFloat,
        end: CGPoint?
    ) -> CubicCurve {
        let delta = theta2 - theta1
        // Floating-point division. The unit-circle handle is (4/3) tan(Δθ/4),
        // carried through the ellipse by the parametric derivative.
        let alpha = (4.0 / 3.0) * tan(delta / 4)

        let p1 = point(center: center, rx: rx, ry: ry, phi: phi, theta: theta1)
        let p2 = point(center: center, rx: rx, ry: ry, phi: phi, theta: theta2)
        let d1 = derivative(rx: rx, ry: ry, phi: phi, theta: theta1)
        let d2 = derivative(rx: rx, ry: ry, phi: phi, theta: theta2)

        return CubicCurve(
            control1: CGPoint(x: p1.x + alpha * d1.dx, y: p1.y + alpha * d1.dy),
            control2: CGPoint(x: p2.x - alpha * d2.dx, y: p2.y - alpha * d2.dy),
            point: end ?? p2
        )
    }

    /// Point on the ellipse at eccentric angle `theta`. F.6.3.1.
    private static func point(
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        phi: CGFloat,
        theta: CGFloat
    ) -> CGPoint {
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)

        return CGPoint(
            x: center.x + rx * cosTheta * cosPhi - ry * sinTheta * sinPhi,
            y: center.y + rx * cosTheta * sinPhi + ry * sinTheta * cosPhi
        )
    }

    /// Derivative of `point` with respect to the eccentric angle.
    private static func derivative(
        rx: CGFloat,
        ry: CGFloat,
        phi: CGFloat,
        theta: CGFloat
    ) -> CGVector {
        let cosPhi = cos(phi)
        let sinPhi = sin(phi)
        let cosTheta = cos(theta)
        let sinTheta = sin(theta)

        return CGVector(
            dx: -rx * sinTheta * cosPhi - ry * cosTheta * sinPhi,
            dy: -rx * sinTheta * sinPhi + ry * cosTheta * cosPhi
        )
    }
}
