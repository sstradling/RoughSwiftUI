import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SVGArcConverterTests: XCTestCase {
    func testQuarterCircleArcDecomposesToOneCubic() {
        let curves = SVGArcConverter.cubicCurves(
            from: CGPoint(x: 50, y: 0),
            to: CGPoint(x: 0, y: 50),
            rx: 50,
            ry: 50,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true
        )

        XCTAssertEqual(curves.count, 1)
        XCTAssertEqual(curves[0].point.x, 0, accuracy: 0.001)
        XCTAssertEqual(curves[0].point.y, 50, accuracy: 0.001)
    }

    func testHalfCircleArcDecomposesToTwoCubics() {
        let curves = SVGArcConverter.cubicCurves(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            rx: 50,
            ry: 50,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true
        )

        XCTAssertEqual(curves.count, 2)
        XCTAssertEqual(curves.last?.point.x ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(curves.last?.point.y ?? -1, 0, accuracy: 0.001)
    }

    func testArcWithTooSmallRadiiScalesRadiiAndStillReachesEndpoint() {
        let curves = SVGArcConverter.cubicCurves(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            rx: 10,
            ry: 10,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true
        )

        XCTAssertFalse(curves.isEmpty)
        XCTAssertEqual(curves.last?.point.x ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(curves.last?.point.y ?? -1, 0, accuracy: 0.001)
    }

    func testZeroRadiusArcReturnsNoCubicsForLineFallback() {
        let curves = SVGArcConverter.cubicCurves(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            rx: 0,
            ry: 50,
            xAxisRotation: 0,
            largeArc: false,
            sweep: true
        )

        XCTAssertTrue(curves.isEmpty)
    }

    func testUIBezierPathAppliesArcAndEndsAtEndpoint() {
        let bezier = UIBezierPath(svgPath: "M0 0 A50 50 0 0 1 50 50")

        XCTAssertEqual(bezier.currentPoint.x, 50, accuracy: 0.001)
        XCTAssertEqual(bezier.currentPoint.y, 50, accuracy: 0.001)
        XCTAssertGreaterThan(bezier.cgPath.boundingBox.width, 0)
        XCTAssertGreaterThan(bezier.cgPath.boundingBox.height, 0)
    }
}
