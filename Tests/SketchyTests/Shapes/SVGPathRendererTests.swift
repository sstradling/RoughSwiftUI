import XCTest
import SwiftUI
@testable import Sketchy

@MainActor
final class SVGPathRendererTests: XCTestCase {
    // MARK: SVGPathRenderer Tests
    
    func testSVGPathRendererSimplePath() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 L 100 10 L 100 100 L 10 100 Z"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 8, "Should produce operations for all segments")
    }
    
    func testSVGPathRendererCurvePath() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 C 40 10 60 40 100 100"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 2, "Should produce operations for curve")
    }
    
    func testSVGPathRendererQuadCurve() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 Q 50 100 100 10"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 2, "Should produce operations for quad curve")
    }

    func testSVGPathRendererEllipticalArc() {
        var options = Options()
        options.roughness = 0

        let svgPath = "M 0 0 A 50 50 0 0 1 50 50"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)

        // Two rough passes. Each pass should contain Move + one cubic Bezier.
        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 2)
        XCTAssertEqual(ops.filter { $0 is LineTo }.count, 0)
    }

    func testSVGPathRendererLargeEllipticalArcSplitsIntoMultipleCubics() {
        var options = Options()
        options.roughness = 0

        let svgPath = "M 0 0 A 50 50 0 1 1 100 0"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)

        // A 180° arc is split into 2 cubic segments per pass.
        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 4)
    }

    func testSVGPathRendererZeroRadiusArcFallsBackToLine() {
        var options = Options()
        options.roughness = 0

        let svgPath = "M 0 0 A 0 50 0 0 1 100 0"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)

        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is LineTo }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 0)
    }

    func testSVGPathRendererSkipsCoincidentArc() {
        var options = Options()
        options.roughness = 0

        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(
            svgPath: "M 10 10 A 40 25 15 1 0 10 10 L 30 10",
            options: options
        )

        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 0)
        let lines = ops.compactMap { $0 as? LineTo }
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].point.x, 30, accuracy: 0.01)
        XCTAssertEqual(lines[0].point.y, 10, accuracy: 0.01)
    }

    func testRelativeArcMatchesTheAbsoluteArc() {
        var options = Options()
        options.roughness = 0
        options.seed = 3

        let relative: [Sketchy.Operation] = SVGPathRenderer.pathOps(
            svgPath: "M10 10 a20 30 25 0 1 40 -10",
            options: options
        )
        let absolute: [Sketchy.Operation] = SVGPathRenderer.pathOps(
            svgPath: "M10 10 A20 30 25 0 1 50 0",
            options: options
        )

        XCTAssertEqual(curvePoints(relative), curvePoints(absolute))
        XCTAssertFalse(curvePoints(relative).isEmpty)
    }

    func testArcAfterASecondCloseStartsAtTheMoveto() {
        var options = Options()
        options.roughness = 0

        let chained: [Sketchy.Operation] = SVGPathRenderer.pathOps(
            svgPath: "M 0 0 L 40 0 Z A 20 20 0 0 1 0 20 Z A 10 10 0 0 1 10 0",
            options: options
        )
        let alone: [Sketchy.Operation] = SVGPathRenderer.pathOps(
            svgPath: "M 0 0 A 10 10 0 0 1 10 0",
            options: options
        )

        let chainedCurves = curves(in: firstPass(chained))
        let aloneCurves = curves(in: firstPass(alone))
        XCTAssertGreaterThanOrEqual(chainedCurves.count, aloneCurves.count)
        let tail = chainedCurves.suffix(aloneCurves.count)
        for (lhs, rhs) in zip(tail, aloneCurves) {
            XCTAssertEqual(lhs.point.x, rhs.point.x, accuracy: 0.01)
            XCTAssertEqual(lhs.point.y, rhs.point.y, accuracy: 0.01)
            XCTAssertEqual(lhs.controlPoint1.x, rhs.controlPoint1.x, accuracy: 0.01)
            XCTAssertEqual(lhs.controlPoint1.y, rhs.controlPoint1.y, accuracy: 0.01)
        }
    }

    func testRoughArcIsDrawnAsJitteredCubics() {
        var options = Options()
        options.roughness = 1.4
        options.seed = 9

        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(
            svgPath: "M 0 0 A 50 50 0 0 1 50 50",
            options: options
        )
        let cubics = ops.compactMap { $0 as? BezierCurveTo }

        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(cubics.count, 2)
        XCTAssertEqual(ops.filter { $0 is LineTo }.count, 0)
        XCTAssertNotEqual(cubics[0].controlPoint1.x, cubics[1].controlPoint1.x)
        XCTAssertNotEqual(cubics[0].point.y, cubics[1].point.y)
    }

    func testRoundedBadgeCornerArcsEndOnTheirCircles() {
        var options = Options()
        options.roughness = 0

        let badge = "M15 0 H85 A15 15 0 0 1 100 15 V45 A15 15 0 0 1 85 60 H15 A15 15 0 0 1 0 45 V15 A15 15 0 0 1 15 0 Z"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: badge, options: options)
        let drawn = sampledCurves(in: firstPass(ops))

        let expected: [(end: CGPoint, center: CGPoint)] = [
            (CGPoint(x: 100, y: 15), CGPoint(x: 85, y: 15)),
            (CGPoint(x: 85, y: 60), CGPoint(x: 85, y: 45)),
            (CGPoint(x: 0, y: 45), CGPoint(x: 15, y: 45)),
            (CGPoint(x: 15, y: 0), CGPoint(x: 15, y: 15))
        ]
        XCTAssertEqual(drawn.count, expected.count)
        for (curve, target) in zip(drawn, expected) {
            XCTAssertEqual(curve.end.x, target.end.x, accuracy: 0.02)
            XCTAssertEqual(curve.end.y, target.end.y, accuracy: 0.02)
            XCTAssertEqual(hypot(curve.mid.x - target.center.x, curve.mid.y - target.center.y), 15, accuracy: 0.2)
        }
    }

    func testHeartLobesAreSemicircles() {
        var options = Options()
        options.roughness = 0

        let heart = "M10 40 A20 20 0 0 1 50 40 A20 20 0 0 1 90 40 L50 90 Z"
        let ops: [Sketchy.Operation] = SVGPathRenderer.pathOps(svgPath: heart, options: options)
        let drawn = sampledCurves(in: firstPass(ops))

        XCTAssertEqual(drawn.count, 4)
        XCTAssertEqual(drawn[1].end.x, 50, accuracy: 0.02)
        XCTAssertEqual(drawn[1].end.y, 40, accuracy: 0.02)
        XCTAssertEqual(drawn[3].end.x, 90, accuracy: 0.02)
        XCTAssertEqual(drawn[3].end.y, 40, accuracy: 0.02)
        XCTAssertEqual(hypot(drawn[0].end.x - 30, drawn[0].end.y - 40), 20, accuracy: 0.05)
        XCTAssertEqual(drawn[0].end.y, 20, accuracy: 0.05)
        XCTAssertEqual(hypot(drawn[2].end.x - 70, drawn[2].end.y - 40), 20, accuracy: 0.05)
        XCTAssertEqual(drawn[2].end.y, 20, accuracy: 0.05)
    }

    private func firstPass(_ ops: [Sketchy.Operation]) -> [Sketchy.Operation] {
        var seenMove = false
        var pass: [Sketchy.Operation] = []
        for op in ops {
            if op is Move {
                if seenMove { break }
                seenMove = true
            }
            pass.append(op)
        }
        return pass
    }

    private func curves(in ops: [Sketchy.Operation]) -> [BezierCurveTo] {
        ops.compactMap { $0 as? BezierCurveTo }
    }

    private func curvePoints(_ ops: [Sketchy.Operation]) -> [Point] {
        ops.compactMap { op -> [Point]? in
            guard let curve = op as? BezierCurveTo else { return nil }
            return [curve.controlPoint1, curve.controlPoint2, curve.point]
        }.flatMap { $0 }
    }

    private struct SampledCurve {
        let end: CGPoint
        let mid: CGPoint
    }

    private func sampledCurves(in ops: [Sketchy.Operation]) -> [SampledCurve] {
        var pen = CGPoint.zero
        var samples: [SampledCurve] = []
        for op in ops {
            if let move = op as? Move {
                pen = CGPoint(x: CGFloat(move.point.x), y: CGFloat(move.point.y))
            } else if let line = op as? LineTo {
                pen = CGPoint(x: CGFloat(line.point.x), y: CGFloat(line.point.y))
            } else if let curve = op as? BezierCurveTo {
                let end = CGPoint(x: CGFloat(curve.point.x), y: CGFloat(curve.point.y))
                let c1 = CGPoint(x: CGFloat(curve.controlPoint1.x), y: CGFloat(curve.controlPoint1.y))
                let c2 = CGPoint(x: CGFloat(curve.controlPoint2.x), y: CGFloat(curve.controlPoint2.y))
                let mid = cubic(pen, c1, c2, end, 0.5)
                samples.append(SampledCurve(end: end, mid: mid))
                pen = end
            }
        }
        return samples
    }

    private func cubic(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p1: CGPoint, _ t: CGFloat) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p1.x,
            y: u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p1.y
        )
    }
}
