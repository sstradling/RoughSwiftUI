//
//  RoughCurvesTests.swift
//  RoughSwiftUITests
//
//  Geometric and structural tests for the continuous-Bezier shape
//  generators in `RoughCurves.swift`. These tests assert properties that
//  are *invariant* under the random jitter (operation counts, types,
//  endpoint sharing, approximate placement) rather than exact coordinate
//  values, so they are stable run-to-run.
//

import XCTest
@testable import RoughSwiftUI

@MainActor
final class RoughCurvesTests: XCTestCase {

    // MARK: Helpers

    private var quietOptions: Options {
        var o = Options()
        // Zero roughness eliminates jitter, making coordinate assertions
        // exact. Most tests use this; a few use the default to verify the
        // jittered path produces structurally-correct output.
        o.roughness = 0
        o.bowing = 0
        o.maxRandomnessOffset = 0
        return o
    }

    private func cubicCount(_ ops: [Operation]) -> Int {
        ops.filter { $0 is BezierCurveTo }.count
    }

    private func moveCount(_ ops: [Operation]) -> Int {
        ops.filter { $0 is Move }.count
    }

    private func lineCount(_ ops: [Operation]) -> Int {
        ops.filter { $0 is LineTo }.count
    }

    // MARK: - Ellipse / Circle

    func testEllipseEmits4CubicsPerPassWithSharedEndpoints() {
        let ops = RoughCurves.ellipseOps(
            cx: 100, cy: 100, rx: 50, ry: 50,
            options: quietOptions
        )
        // Two passes × (1 Move + 4 BezierCurveTo) = 2 Moves + 8 cubics.
        XCTAssertEqual(moveCount(ops), 2)
        XCTAssertEqual(cubicCount(ops), 8)
        XCTAssertEqual(lineCount(ops), 0,
                       "Continuous ellipse must not contain LineTo operations")
    }

    func testEllipseFirstAndLastPointsCoincideWithinPass() {
        // With zero jitter, each pass starts at east and ends at east
        // (the loop closes via the 4 cubics). Verify the first Move and
        // the last cubic's endpoint of pass 1 match.
        let ops = RoughCurves.ellipseOps(
            cx: 200, cy: 100, rx: 30, ry: 20,
            options: quietOptions
        )
        guard let firstMove = ops.first as? Move else {
            return XCTFail("Expected leading Move")
        }
        // The 4th BezierCurveTo (pass 1) is at index 4 (1 Move + 4 cubics).
        guard let pass1End = ops[4] as? BezierCurveTo else {
            return XCTFail("Expected BezierCurveTo at index 4")
        }
        XCTAssertEqual(firstMove.point.x, pass1End.point.x, accuracy: 0.001)
        XCTAssertEqual(firstMove.point.y, pass1End.point.y, accuracy: 0.001)
    }

    func testEllipseCardinalsLandOnExpectedAxes() {
        // With zero jitter, the four cardinal endpoints of the first pass
        // should land exactly on (cx±rx, cy) and (cx, cy±ry).
        let cx: Float = 50, cy: Float = 60, rx: Float = 40, ry: Float = 30
        let ops = RoughCurves.ellipseOps(
            cx: cx, cy: cy, rx: rx, ry: ry,
            options: quietOptions
        )
        // Pass 1: Move=east, then south, west, north, east.
        guard let move = ops.first as? Move else { return XCTFail() }
        XCTAssertEqual(move.point.x, cx + rx, accuracy: 0.001)
        XCTAssertEqual(move.point.y, cy,      accuracy: 0.001)

        guard let south = ops[1] as? BezierCurveTo else { return XCTFail() }
        XCTAssertEqual(south.point.x, cx,      accuracy: 0.001)
        XCTAssertEqual(south.point.y, cy + ry, accuracy: 0.001)

        guard let west = ops[2] as? BezierCurveTo else { return XCTFail() }
        XCTAssertEqual(west.point.x, cx - rx, accuracy: 0.001)
        XCTAssertEqual(west.point.y, cy,      accuracy: 0.001)

        guard let north = ops[3] as? BezierCurveTo else { return XCTFail() }
        XCTAssertEqual(north.point.x, cx,      accuracy: 0.001)
        XCTAssertEqual(north.point.y, cy - ry, accuracy: 0.001)
    }

    func testCircleStillProducesCorrectShapeViaEllipseGenerator() {
        // The native generator routes circles through ellipseOps with
        // rx == ry; verify the public surface produces the same structural
        // result.
        let ops = RoughCurves.ellipseOps(
            cx: 0, cy: 0, rx: 25, ry: 25,
            options: quietOptions
        )
        XCTAssertEqual(cubicCount(ops), 8)
        XCTAssertEqual(moveCount(ops), 2)
    }

    // MARK: - Polygon / Rectangle

    func testRectangleIsOneSubpathPerPass() {
        // 4 edges per pass + Close. Two passes total.
        let ops = RoughCurves.rectangleOps(
            x: 0, y: 0, width: 100, height: 50,
            options: quietOptions
        )
        XCTAssertEqual(moveCount(ops), 2,
                       "Two passes, each one continuous subpath beginning with Move")
        XCTAssertEqual(cubicCount(ops), 8,
                       "Each pass: 4 edges as bowed cubics")
        XCTAssertEqual(ops.filter { $0 is Close }.count, 2,
                       "Each pass terminates with Close")
    }

    func testRectangleSharesEndpointsBetweenAdjacentEdges() {
        // The endpoint of edge N (cubic.point) must equal the endpoint
        // recorded by the next cubic's prior Move/cubic. We test this by
        // tracing pass 1 and verifying each cubic ends where the next
        // begins (i.e., each successive cubic's start is the previous
        // cubic's end — implicit in the sequential drawing model).
        let ops = RoughCurves.rectangleOps(
            x: 10, y: 20, width: 80, height: 40,
            options: quietOptions
        )
        // Pass 1: ops[0] = Move, ops[1..4] = cubics, ops[5] = Close.
        guard let move = ops.first as? Move else { return XCTFail() }
        let cubics = ops.prefix(5).compactMap { $0 as? BezierCurveTo }
        XCTAssertEqual(cubics.count, 4)
        // The final cubic's endpoint should equal the leading Move
        // (closing the loop before the Close op).
        XCTAssertEqual(cubics[3].point.x, move.point.x, accuracy: 0.001)
        XCTAssertEqual(cubics[3].point.y, move.point.y, accuracy: 0.001)
    }

    func testRectangleCornerEndpointsAreAtRequestedBounds() {
        let ops = RoughCurves.rectangleOps(
            x: 0, y: 0, width: 100, height: 50,
            options: quietOptions
        )
        // With zero jitter, the four endpoints are exactly the rect
        // corners visited in input order: (0,0)→(100,0)→(100,50)→(0,50).
        guard let move = ops.first as? Move else { return XCTFail() }
        XCTAssertEqual(move.point.x, 0, accuracy: 0.001)
        XCTAssertEqual(move.point.y, 0, accuracy: 0.001)
        let cubics = ops.prefix(5).compactMap { $0 as? BezierCurveTo }
        XCTAssertEqual(cubics[0].point.x, 100, accuracy: 0.001)
        XCTAssertEqual(cubics[0].point.y, 0,   accuracy: 0.001)
        XCTAssertEqual(cubics[1].point.x, 100, accuracy: 0.001)
        XCTAssertEqual(cubics[1].point.y, 50,  accuracy: 0.001)
        XCTAssertEqual(cubics[2].point.x, 0,   accuracy: 0.001)
        XCTAssertEqual(cubics[2].point.y, 50,  accuracy: 0.001)
    }

    func testPolygonOpenLinearPathHasNoClose() {
        let points: [[Float]] = [[0, 0], [10, 0], [10, 10]]
        let ops = RoughCurves.linearPathOps(
            points: points, close: false,
            options: quietOptions
        )
        XCTAssertEqual(ops.filter { $0 is Close }.count, 0)
        // Two passes × 2 edges each.
        XCTAssertEqual(cubicCount(ops), 4)
    }

    // MARK: - Line

    func testDoubleLineEmitsTwoSubpathsEachOneCubic() {
        let ops = RoughCurves.doubleLineOps(
            x1: 0, y1: 0, x2: 100, y2: 100,
            options: quietOptions
        )
        XCTAssertEqual(moveCount(ops), 2,
                       "Each pass starts with its own Move")
        XCTAssertEqual(cubicCount(ops), 2,
                       "Each pass is a single bowed cubic")
        XCTAssertEqual(lineCount(ops), 0,
                       "Continuous line must not emit LineTo operations")
    }

    func testDoubleLineEndpointsLandOnRequestedCoordinates() {
        let ops = RoughCurves.doubleLineOps(
            x1: 5, y1: 5, x2: 95, y2: 75,
            options: quietOptions
        )
        guard let move = ops.first as? Move else { return XCTFail() }
        guard let cubic = ops.dropFirst().first as? BezierCurveTo else { return XCTFail() }
        XCTAssertEqual(move.point.x, 5,  accuracy: 0.001)
        XCTAssertEqual(move.point.y, 5,  accuracy: 0.001)
        XCTAssertEqual(cubic.point.x, 95, accuracy: 0.001)
        XCTAssertEqual(cubic.point.y, 75, accuracy: 0.001)
    }

    // MARK: - Rounded rectangle

    func testRoundedRectangleIsOneSubpathPerPass() {
        let ops = RoughCurves.roundedRectangleOps(
            x: 0, y: 0, width: 100, height: 60, cornerRadius: 10,
            options: quietOptions
        )
        XCTAssertEqual(moveCount(ops), 2)
        XCTAssertEqual(ops.filter { $0 is Close }.count, 2)
        // Each pass: 4 edges + 4 corner arcs = 8 cubics.
        XCTAssertEqual(cubicCount(ops), 16)
        XCTAssertEqual(lineCount(ops), 0)
    }

    func testRoundedRectangleZeroRadiusFallsBackToRectangle() {
        // With cornerRadius == 0, the structure should match a plain
        // rectangle: 4 cubics per pass and 2 Close ops.
        let ops = RoughCurves.roundedRectangleOps(
            x: 0, y: 0, width: 100, height: 60, cornerRadius: 0,
            options: quietOptions
        )
        XCTAssertEqual(cubicCount(ops), 8)
        XCTAssertEqual(ops.filter { $0 is Close }.count, 2)
    }

    func testRoundedRectangleClampsRadiusToHalfMinExtent() {
        // cornerRadius = 1000 with a 100×60 rect should clamp to 30 and
        // still produce a valid 8-cubic-per-pass structure.
        let ops = RoughCurves.roundedRectangleOps(
            x: 0, y: 0, width: 100, height: 60, cornerRadius: 1000,
            options: quietOptions
        )
        XCTAssertEqual(cubicCount(ops), 16,
                       "Clamped radius should still produce the rounded structure")
    }

    // MARK: - Arc

    func testFullCircleArcMatchesEllipseStructure() {
        // A full-circle arc (start 0, stop 2π) should produce the same
        // cubic-count structure as an ellipse.
        let ops = RoughCurves.arcOps(
            cx: 0, cy: 0, rx: 50, ry: 50,
            start: 0, stop: 2 * .pi,
            closed: false,
            options: quietOptions
        )
        // 2 passes × 4 quadrant cubics.
        XCTAssertEqual(cubicCount(ops), 8)
        XCTAssertEqual(moveCount(ops), 2)
    }

    func testQuarterArcEmitsOneCubicPerPass() {
        let ops = RoughCurves.arcOps(
            cx: 100, cy: 100, rx: 40, ry: 40,
            start: 0, stop: .pi / 2,
            closed: false,
            options: quietOptions
        )
        // 2 passes × 1 cubic.
        XCTAssertEqual(cubicCount(ops), 2)
        XCTAssertEqual(moveCount(ops), 2)
        XCTAssertEqual(lineCount(ops), 0)
    }

    func testClosedArcAddsPieClosure() {
        // A closed arc adds two LineTo ops per pass (to center and back).
        let ops = RoughCurves.arcOps(
            cx: 0, cy: 0, rx: 20, ry: 20,
            start: 0, stop: .pi,
            closed: true,
            options: quietOptions
        )
        XCTAssertEqual(lineCount(ops), 4, "Two Lines per pass × 2 passes")
    }

    // MARK: - Egg

    func testEggEmits4CubicsPerPass() {
        let ops = RoughCurves.eggOps(
            cx: 0, cy: 0, width: 60, height: 80, tilt: 0.3,
            options: quietOptions
        )
        XCTAssertEqual(cubicCount(ops), 8)
        XCTAssertEqual(moveCount(ops), 2)
        XCTAssertEqual(lineCount(ops), 0)
    }

    func testEggSymmetricWhenTiltIsZero() {
        // tilt=0 collapses to a regular ellipse: east and west endpoints
        // should be mirror images about cx, north and south about cy.
        let ops = RoughCurves.eggOps(
            cx: 100, cy: 100, width: 60, height: 80, tilt: 0,
            options: quietOptions
        )
        guard let move = ops.first as? Move else { return XCTFail() }
        let cubics = ops.prefix(5).compactMap { $0 as? BezierCurveTo }
        // east at (cx + rx, cy), west at (cx − rx, cy)
        XCTAssertEqual(move.point.x, 130, accuracy: 0.001)  // 100 + 30
        XCTAssertEqual(cubics[1].point.x, 70, accuracy: 0.001)  // 100 − 30
        // north at (cx, cy − ry), south at (cx, cy + ry)
        XCTAssertEqual(cubics[0].point.y, 140, accuracy: 0.001)  // 100 + 40
        XCTAssertEqual(cubics[2].point.y, 60,  accuracy: 0.001)  // 100 − 40
    }

    // MARK: - Jitter behavior

    func testJitterPreservesStructuralCounts() {
        // Even with default (jittered) options, op counts must be stable.
        var noisy = Options()
        noisy.roughness = 2
        noisy.bowing = 2
        noisy.maxRandomnessOffset = 4

        let ellipse = RoughCurves.ellipseOps(
            cx: 0, cy: 0, rx: 50, ry: 50, options: noisy
        )
        XCTAssertEqual(cubicCount(ellipse), 8)

        let rect = RoughCurves.rectangleOps(
            x: 0, y: 0, width: 100, height: 50, options: noisy
        )
        XCTAssertEqual(cubicCount(rect), 8)

        let line = RoughCurves.doubleLineOps(
            x1: 0, y1: 0, x2: 100, y2: 100, options: noisy
        )
        XCTAssertEqual(cubicCount(line), 2)
    }

    func testJitteredEndpointsStayWithinMaxOffset() {
        var noisy = Options()
        noisy.roughness = 1
        noisy.maxRandomnessOffset = 3

        let ops = RoughCurves.ellipseOps(
            cx: 100, cy: 100, rx: 50, ry: 50, options: noisy
        )
        guard let move = ops.first as? Move else { return XCTFail() }
        // The east endpoint should be near (150, 100) within the
        // configured jitter budget. We allow a generous bound to absorb
        // the second-pass scale (1.5×) and randomness.
        let dx = abs(move.point.x - 150)
        let dy = abs(move.point.y - 100)
        XCTAssertLessThan(dx, noisy.maxRandomnessOffset * 2,
                          "East endpoint should be near (cx+rx, cy)")
        XCTAssertLessThan(dy, noisy.maxRandomnessOffset * 2)
    }
}
