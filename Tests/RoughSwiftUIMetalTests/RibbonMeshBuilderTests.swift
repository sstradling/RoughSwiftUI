//
//  RibbonMeshBuilderTests.swift
//  RoughSwiftUIMetalTests
//
//  Verifies geometric properties of the ribbon mesh builder. These tests are
//  pure-CPU and require no Metal device, so they run identically on devices,
//  simulators, and CI without GPU access.
//

import XCTest
import simd
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

final class RibbonMeshBuilderTests: XCTestCase {

    // MARK: Basic line

    func testStraightLineProducesPairedVertices() throws {
        let ops: [Operation] = [
            Move(data: [0, 50]),
            LineTo(data: [100, 50])
        ]
        let mesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: ops, baseWidth: 4))

        XCTAssertFalse(mesh.isClosed)
        XCTAssertGreaterThanOrEqual(mesh.vertices.count, 4)
        XCTAssertEqual(mesh.vertices.count % 2, 0, "Vertices come in left/right pairs")
        XCTAssertEqual(mesh.totalLength, 100, accuracy: 0.5)
    }

    func testRibbonWidthMatchesRequestedWidth() throws {
        // A horizontal line; the perpendicular displacement at any sample
        // should equal ±halfWidth in Y.
        let ops: [Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [100, 0])
        ]
        let baseWidth: CGFloat = 6
        let mesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: ops, baseWidth: baseWidth))

        // Pick a vertex pair from the middle of the strip to avoid endpoints.
        let middle = (mesh.vertices.count / 2) & ~1 // round down to even index
        let left = mesh.vertices[middle]
        let right = mesh.vertices[middle + 1]

        let dx = Double(left.position.x - right.position.x)
        let dy = Double(left.position.y - right.position.y)
        let dist = (dx * dx + dy * dy).squareRoot()
        XCTAssertEqual(dist, Double(baseWidth), accuracy: 0.001)
    }

    func testParametricSValueIsMonotonicAndNormalized() throws {
        let ops: [Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [100, 0])
        ]
        let mesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: ops, baseWidth: 4))

        var lastS: Float = -.infinity
        for i in stride(from: 0, to: mesh.vertices.count, by: 2) {
            let s = mesh.vertices[i].parametric.x
            XCTAssertGreaterThanOrEqual(s, lastS, "s must be non-decreasing along the strip")
            XCTAssertGreaterThanOrEqual(s, 0)
            XCTAssertLessThanOrEqual(s, 1)
            lastS = s
        }
        XCTAssertEqual(mesh.vertices.first!.parametric.x, 0, accuracy: 0.001)
        XCTAssertEqual(mesh.vertices.last!.parametric.x, 1, accuracy: 0.001)
    }

    func testParametricTAlternatesBetweenLeftAndRight() throws {
        let ops: [Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [50, 0])
        ]
        let mesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: ops, baseWidth: 4))
        for i in stride(from: 0, to: mesh.vertices.count, by: 2) {
            XCTAssertEqual(mesh.vertices[i].parametric.y, 1, "Even indices are left edge (t = +1)")
            XCTAssertEqual(mesh.vertices[i + 1].parametric.y, -1, "Odd indices are right edge (t = -1)")
        }
    }

    // MARK: Curves

    func testCubicCurveProducesAdaptiveSamples() throws {
        // A cubic with significant curvature should produce more samples than
        // a same-length straight segment.
        let curveOps: [Operation] = [
            Move(data: [0, 0]),
            BezierCurveTo(data: [25, 100, 75, -100, 100, 0])
        ]
        let lineOps: [Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [100, 0])
        ]
        let curveMesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: curveOps, baseWidth: 2))
        let lineMesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: lineOps, baseWidth: 2))

        XCTAssertGreaterThan(
            curveMesh.vertices.count,
            lineMesh.vertices.count,
            "Curved paths get adaptively more samples than equal-length straight ones"
        )
    }

    // MARK: Closed paths

    func testClosedSubpathAppendsSeamClosingPair() throws {
        let ops: [Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [10, 0]),
            LineTo(data: [10, 10]),
            LineTo(data: [0, 10]),
            Close()
        ]
        let mesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: ops, baseWidth: 1))
        XCTAssertTrue(mesh.isClosed)
        // Last pair should match the first pair's position so the strip
        // closes seamlessly.
        let firstLeft = mesh.vertices.first!
        let lastLeft = mesh.vertices[mesh.vertices.count - 2]
        XCTAssertEqual(firstLeft.position.x, lastLeft.position.x, accuracy: 0.001)
        XCTAssertEqual(firstLeft.position.y, lastLeft.position.y, accuracy: 0.001)
    }

    // MARK: Multiple subpaths

    func testMultipleSubpathsConcatenateWithDegenerateSeparators() throws {
        let ops: [Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [10, 0]),
            Move(data: [50, 50]),
            LineTo(data: [60, 50])
        ]
        let mesh = try XCTUnwrap(RibbonMeshBuilder.build(operations: ops, baseWidth: 1))

        // We should have at least the per-subpath samples plus 2 degenerate
        // separator vertices between them.
        XCTAssertGreaterThanOrEqual(mesh.vertices.count, 8)

        // Verify there is at least one place where consecutive vertices
        // coincide (the degenerate seam).
        var foundDegenerate = false
        for i in 0..<(mesh.vertices.count - 1) {
            if mesh.vertices[i].position == mesh.vertices[i + 1].position {
                foundDegenerate = true
                break
            }
        }
        XCTAssertTrue(foundDegenerate, "Concatenated subpaths must contain a degenerate seam")
    }

    // MARK: Edge cases

    func testEmptyOperationsReturnsNil() {
        XCTAssertNil(RibbonMeshBuilder.build(operations: [], baseWidth: 4))
    }

    func testDegenerateZeroLengthLineReturnsNil() {
        let ops: [Operation] = [
            Move(data: [10, 10]),
            LineTo(data: [10, 10])
        ]
        XCTAssertNil(RibbonMeshBuilder.build(operations: ops, baseWidth: 4))
    }
}
