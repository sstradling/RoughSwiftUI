import XCTest
import SwiftUI
@testable import Sketchy

/// Endpoint-to-center checks for SVG elliptical arcs.
///
/// Expected centres, radii, and angles are the SVG 1.1 F.6.5 / F.6.6 results
/// for these endpoints. Sampled cubics are compared with those values, not
/// with a second call into `SVGArcConverter`.
@MainActor
final class SVGArcConverterTests: XCTestCase {
    private let kappa = (4.0 / 3.0) * tan(CGFloat.pi / 8)

    func testQuarterCircleHasOneCubicOnTheKnownCircle() {
        let start = CGPoint(x: 50, y: 0)
        let end = CGPoint(x: 0, y: 50)
        let geometry = expectCubic(
            from: start,
            to: end,
            rx: 50,
            ry: 50,
            rotation: 0,
            largeArc: false,
            sweep: true,
            center: .zero,
            correctedRx: 50,
            correctedRy: 50,
            deltaDegrees: 90,
            curveCount: 1
        )

        let curve = geometry.curves[0]
        XCTAssertEqual(curve.control1.x, 50, accuracy: 0.001)
        XCTAssertEqual(curve.control1.y, 50 * kappa, accuracy: 0.001)
        XCTAssertEqual(curve.control2.x, 50 * kappa, accuracy: 0.001)
        XCTAssertEqual(curve.control2.y, 50, accuracy: 0.001)
        assertSample(
            cubicPoint(start: start, curve: curve, t: 0.5),
            near: CGPoint(x: 50 * cos(CGFloat.pi / 4), y: 50 * sin(CGFloat.pi / 4)),
            tolerance: 0.2
        )
    }

    func testSemicircleSweepFlagSplitsThroughNegativeY() {
        let geometry = expectCubic(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            rx: 50,
            ry: 50,
            rotation: 0,
            largeArc: false,
            sweep: true,
            center: CGPoint(x: 50, y: 0),
            correctedRx: 50,
            correctedRy: 50,
            deltaDegrees: 180,
            curveCount: 2
        )

        // Sweep flag 1 increases the eccentric angle. From the left endpoint
        // that passes through negative y, (50, -50).
        assertSample(geometry.curves[0].point, near: CGPoint(x: 50, y: -50), tolerance: 0.05)
    }

    func testOppositeSweepSemicircleSplitsThroughPositiveY() {
        let geometry = expectCubic(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            rx: 50,
            ry: 50,
            rotation: 0,
            largeArc: false,
            sweep: false,
            center: CGPoint(x: 50, y: 0),
            correctedRx: 50,
            correctedRy: 50,
            deltaDegrees: -180,
            curveCount: 2
        )

        assertSample(geometry.curves[0].point, near: CGPoint(x: 50, y: 50), tolerance: 0.05)
    }

    func testLargeArcAndSweepFlagsSelectTheFourArcs() {
        let start = CGPoint(x: 100, y: 0)
        let end = CGPoint(x: 0, y: 100)
        let cases: [(large: Bool, sweep: Bool, center: CGPoint, degrees: CGFloat, curves: Int)] = [
            (false, true, .zero, 90, 1),
            (false, false, CGPoint(x: 100, y: 100), -90, 1),
            (true, true, CGPoint(x: 100, y: 100), 270, 3),
            (true, false, .zero, -270, 3)
        ]

        for item in cases {
            _ = expectCubic(
                from: start,
                to: end,
                rx: 100,
                ry: 100,
                rotation: 0,
                largeArc: item.large,
                sweep: item.sweep,
                center: item.center,
                correctedRx: 100,
                correctedRy: 100,
                deltaDegrees: item.degrees,
                curveCount: item.curves
            )
        }
    }

    func testTooSmallRadiiScaleOntoTheSemicircle() {
        let geometry = expectCubic(
            from: .zero,
            to: CGPoint(x: 100, y: 0),
            rx: 10,
            ry: 20,
            rotation: 0,
            largeArc: false,
            sweep: true,
            center: CGPoint(x: 50, y: 0),
            correctedRx: 50,
            correctedRy: 100,
            deltaDegrees: 180,
            curveCount: 2
        )

        assertSample(geometry.curves[0].point, near: CGPoint(x: 50, y: -100), tolerance: 0.05)
    }

    func testXAxisRotationMovesTheCentre() {
        _ = expectCubic(
            from: .zero,
            to: CGPoint(x: 60, y: 0),
            rx: 40,
            ry: 15,
            rotation: 0,
            largeArc: false,
            sweep: true,
            center: CGPoint(x: 30, y: 3.75 * sqrt(7)),
            correctedRx: 40,
            correctedRy: 15,
            deltaDegrees: 2 * asin(0.75) * 180 / .pi,
            curveCount: 2
        )

        let turned = expectCubic(
            from: .zero,
            to: CGPoint(x: 60, y: 0),
            rx: 40,
            ry: 15,
            rotation: 90,
            largeArc: false,
            sweep: true,
            center: CGPoint(x: 30, y: 0),
            correctedRx: 80,
            correctedRy: 30,
            deltaDegrees: 180,
            curveCount: 2
        )
        assertSample(turned.curves[0].point, near: CGPoint(x: 30, y: -80), tolerance: 0.05)
    }

    func testRotatedEllipseArcKeepsItsCentreAndJoin() {
        let start = CGPoint(x: 136.595389311789, y: 124.101445320185)
        let end = CGPoint(x: 55.683651114451, y: 72.814167995012)
        let geometry = expectCubic(
            from: start,
            to: end,
            rx: 60,
            ry: 30,
            rotation: 40,
            largeArc: false,
            sweep: true,
            center: CGPoint(x: 100, y: 80),
            correctedRx: 60,
            correctedRy: 30,
            deltaDegrees: 110,
            curveCount: 2
        )

        assertSample(
            geometry.curves[0].point,
            near: CGPoint(x: 93.269458886003, y: 112.180203871384),
            tolerance: 0.05
        )
    }

    func testRotationPastAFullTurnMatchesTheReducedAngle() {
        let start = CGPoint(x: 136.595389311789, y: 124.101445320185)
        let end = CGPoint(x: 55.683651114451, y: 72.814167995012)
        let base = SVGArcConverter.convert(
            from: start, to: end, rx: 60, ry: 30,
            xAxisRotation: 40, largeArc: false, sweep: true
        )
        let wrapped = SVGArcConverter.convert(
            from: start, to: end, rx: 60, ry: 30,
            xAxisRotation: 400, largeArc: false, sweep: true
        )
        guard case let .cubic(baseArc) = base, case let .cubic(wrappedArc) = wrapped else {
            return XCTFail("expected cubics")
        }
        XCTAssertEqual(baseArc.center.x, wrappedArc.center.x, accuracy: 1e-6)
        XCTAssertEqual(baseArc.center.y, wrappedArc.center.y, accuracy: 1e-6)
        XCTAssertEqual(baseArc.curves[0].point.x, wrappedArc.curves[0].point.x, accuracy: 1e-6)
        XCTAssertEqual(baseArc.curves[0].point.y, wrappedArc.curves[0].point.y, accuracy: 1e-6)
    }

    func testNegativeRadiiMatchTheAbsoluteRadii() {
        let positive = SVGArcConverter.cubicCurves(
            from: CGPoint(x: 50, y: 0), to: CGPoint(x: 0, y: 50),
            rx: 50, ry: 50, xAxisRotation: 0, largeArc: false, sweep: true
        )
        let negative = SVGArcConverter.cubicCurves(
            from: CGPoint(x: 50, y: 0), to: CGPoint(x: 0, y: 50),
            rx: -50, ry: -50, xAxisRotation: 0, largeArc: false, sweep: true
        )
        XCTAssertEqual(positive, negative)
    }

    func testZeroRadiusIsALineAndCoincidentEndpointsAreOmitted() {
        let zero = SVGArcConverter.convert(
            from: .zero, to: CGPoint(x: 100, y: 0),
            rx: 0, ry: 50, xAxisRotation: 0, largeArc: false, sweep: true
        )
        let bothZero = SVGArcConverter.convert(
            from: .zero, to: CGPoint(x: 40, y: 10),
            rx: 0, ry: 0, xAxisRotation: 30, largeArc: true, sweep: false
        )
        let samePoint = SVGArcConverter.convert(
            from: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 10),
            rx: 25, ry: 40, xAxisRotation: 15, largeArc: true, sweep: false
        )
        let samePointAndZeroRadius = SVGArcConverter.convert(
            from: CGPoint(x: 10, y: 10), to: CGPoint(x: 10, y: 10),
            rx: 0, ry: 0, xAxisRotation: 0, largeArc: false, sweep: true
        )

        XCTAssertEqual(zero, .line)
        XCTAssertEqual(bothZero, .line)
        XCTAssertEqual(samePoint, .omitted)
        XCTAssertEqual(samePointAndZeroRadius, .omitted)
        XCTAssertTrue(SVGArcConverter.cubicCurves(
            from: .zero, to: CGPoint(x: 100, y: 0),
            rx: 0, ry: 50, xAxisRotation: 0, largeArc: false, sweep: true
        ).isEmpty)
    }

    func testLongArcUsesFourCubicsOfAtMostNinetyDegrees() {
        let start = CGPoint(x: 98.480775301221, y: 17.364817766693)
        let end = CGPoint(x: 64.278760968654, y: -76.604444311898)
        _ = expectCubic(
            from: start,
            to: end,
            rx: 100,
            ry: 100,
            rotation: 0,
            largeArc: true,
            sweep: true,
            center: .zero,
            correctedRx: 100,
            correctedRy: 100,
            deltaDegrees: 300,
            curveCount: 4
        )
    }

    func testUIBezierPathDrawsCurvesLinesOrNothing() {
        let quarter = UIBezierPath(svgPath: "M50 0 A50 50 0 0 1 0 50")
        XCTAssertEqual(elementKinds(quarter.cgPath), [.moveToPoint, .addCurveToPoint])
        XCTAssertEqual(quarter.currentPoint.x, 0, accuracy: 0.001)
        XCTAssertEqual(quarter.currentPoint.y, 50, accuracy: 0.001)

        let semicircle = UIBezierPath(svgPath: "M0 0 A50 50 0 0 1 100 0")
        XCTAssertEqual(
            elementKinds(semicircle.cgPath),
            [.moveToPoint, .addCurveToPoint, .addCurveToPoint]
        )

        let line = UIBezierPath(svgPath: "M0 0 A0 50 0 0 1 100 0")
        XCTAssertEqual(elementKinds(line.cgPath), [.moveToPoint, .addLineToPoint])
        XCTAssertEqual(line.currentPoint.x, 100, accuracy: 0.001)

        let omitted = UIBezierPath(svgPath: "M10 10 A40 25 15 1 0 10 10")
        XCTAssertEqual(elementKinds(omitted.cgPath), [.moveToPoint])
        XCTAssertEqual(omitted.currentPoint.x, 10, accuracy: 0.001)
        XCTAssertEqual(omitted.currentPoint.y, 10, accuracy: 0.001)
    }

    // MARK: - Expectations

    @discardableResult
    private func expectCubic(
        from start: CGPoint,
        to end: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotation: CGFloat,
        largeArc: Bool,
        sweep: Bool,
        center: CGPoint,
        correctedRx: CGFloat,
        correctedRy: CGFloat,
        deltaDegrees: CGFloat,
        curveCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> SVGArcConverter.Geometry {
        let conversion = SVGArcConverter.convert(
            from: start,
            to: end,
            rx: rx,
            ry: ry,
            xAxisRotation: rotation,
            largeArc: largeArc,
            sweep: sweep
        )
        guard case let .cubic(geometry) = conversion else {
            XCTFail("expected cubics", file: file, line: line)
            return SVGArcConverter.Geometry(
                center: .zero, rx: 0, ry: 0, deltaAngle: 0, curves: []
            )
        }

        XCTAssertEqual(geometry.center.x, center.x, accuracy: 1e-4, file: file, line: line)
        XCTAssertEqual(geometry.center.y, center.y, accuracy: 1e-4, file: file, line: line)
        XCTAssertEqual(geometry.rx, correctedRx, accuracy: 1e-4, file: file, line: line)
        XCTAssertEqual(geometry.ry, correctedRy, accuracy: 1e-4, file: file, line: line)
        XCTAssertEqual(geometry.deltaAngle * 180 / .pi, deltaDegrees, accuracy: 1e-3, file: file, line: line)
        XCTAssertEqual(geometry.curves.count, curveCount, file: file, line: line)
        XCTAssertLessThanOrEqual(
            abs(geometry.deltaAngle) / CGFloat(geometry.curves.count),
            .pi / 2 + 1e-6,
            file: file,
            line: line
        )

        let endPoint = geometry.curves.last?.point ?? CGPoint(x: -999, y: -999)
        XCTAssertEqual(endPoint.x, end.x, accuracy: 1e-6, file: file, line: line)
        XCTAssertEqual(endPoint.y, end.y, accuracy: 1e-6, file: file, line: line)

        var segmentStart = start
        let tolerance = max(0.05, 0.002 * max(correctedRx, correctedRy))
        for curve in geometry.curves {
            for t in [CGFloat(0.25), 0.5, 0.75] {
                let sample = cubicPoint(start: segmentStart, curve: curve, t: t)
                let error = ellipseError(
                    sample,
                    center: geometry.center,
                    rx: geometry.rx,
                    ry: geometry.ry,
                    rotationDegrees: rotation
                )
                XCTAssertLessThan(error, tolerance, "sample off the ellipse by \(error)", file: file, line: line)
            }
            let joinError = ellipseError(
                curve.point,
                center: geometry.center,
                rx: geometry.rx,
                ry: geometry.ry,
                rotationDegrees: rotation
            )
            XCTAssertLessThan(joinError, tolerance, file: file, line: line)
            segmentStart = curve.point
        }
        return geometry
    }

    private func assertSample(
        _ point: CGPoint,
        near expected: CGPoint,
        tolerance: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(point.x, expected.x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(point.y, expected.y, accuracy: tolerance, file: file, line: line)
    }

    private func cubicPoint(start: CGPoint, curve: SVGArcConverter.CubicCurve, t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * u * start.x
                + 3 * u * u * t * curve.control1.x
                + 3 * u * t * t * curve.control2.x
                + t * t * t * curve.point.x,
            y: u * u * u * start.y
                + 3 * u * u * t * curve.control1.y
                + 3 * u * t * t * curve.control2.y
                + t * t * t * curve.point.y
        )
    }

    /// Distance from `point` to the ellipse, approximated in the larger radius.
    private func ellipseError(
        _ point: CGPoint,
        center: CGPoint,
        rx: CGFloat,
        ry: CGFloat,
        rotationDegrees: CGFloat
    ) -> CGFloat {
        let phi = rotationDegrees * .pi / 180
        let dx = point.x - center.x
        let dy = point.y - center.y
        let x = cos(phi) * dx + sin(phi) * dy
        let y = -sin(phi) * dx + cos(phi) * dy
        return abs(hypot(x / rx, y / ry) - 1) * max(rx, ry)
    }

    private func elementKinds(_ path: CGPath) -> [CGPathElementType] {
        var kinds: [CGPathElementType] = []
        path.applyWithBlock { element in
            kinds.append(element.pointee.type)
        }
        return kinds
    }
}
