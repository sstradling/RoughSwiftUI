//
//  RibbonMeshWidthJitterTests.swift
//  RoughSwiftUIMetalTests
//
//  Verifies that RibbonMeshBuilder honors WidthJitter at vertex generation
//  time, producing a triangle strip whose cross-stroke width visibly
//  varies along the path.
//

import XCTest
import simd
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

final class RibbonMeshWidthJitterTests: XCTestCase {

    private func longHorizontalLineOps() -> [Operation] {
        [Move(data: [0, 50]), LineTo(data: [1000, 50])]
    }

    /// Computes the cross-stroke width at a vertex pair (left, right).
    private func widthAt(_ mesh: RibbonMesh, pairIndex: Int) -> Float {
        let left = mesh.vertices[pairIndex * 2]
        let right = mesh.vertices[pairIndex * 2 + 1]
        let dx = left.position.x - right.position.x
        let dy = left.position.y - right.position.y
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: - Geometry

    func testNoJitterProducesUniformWidth() {
        guard let mesh = RibbonMeshBuilder.build(
            operations: longHorizontalLineOps(),
            baseWidth: 8
        ) else { return XCTFail() }

        // Sample 5 well-spaced vertex pairs and assert all widths are
        // approximately baseWidth.
        let pairCount = mesh.vertices.count / 2
        for i in stride(from: 0, to: pairCount, by: max(1, pairCount / 5)) {
            XCTAssertEqual(widthAt(mesh, pairIndex: i), 8.0, accuracy: 0.001,
                           "Width at pair \(i) should equal baseWidth without jitter")
        }
    }

    func testJitterProducesVisiblyVaryingWidth() {
        let jitter = WidthJitter(amount: 0.3, frequency: 0.2, seed: 0)
        guard let mesh = RibbonMeshBuilder.build(
            operations: longHorizontalLineOps(),
            baseWidth: 8,
            widthJitter: jitter
        ) else { return XCTFail() }

        let pairCount = mesh.vertices.count / 2
        var widths: [Float] = []
        for i in 0..<pairCount {
            widths.append(widthAt(mesh, pairIndex: i))
        }
        let minW = widths.min() ?? 8
        let maxW = widths.max() ?? 8
        XCTAssertGreaterThan(maxW - minW, 0.5,
                             "Jittered ribbon should have a visible width range; got [\(minW), \(maxW)]")
        // All widths must stay within the configured envelope.
        let baseHalf = Float(8 * 0.7)
        let baseFull = Float(8 * 1.3)
        for (i, w) in widths.enumerated() {
            XCTAssertGreaterThanOrEqual(w, baseHalf - 0.05,
                                        "Width \(w) at pair \(i) below 0.7*base")
            XCTAssertLessThanOrEqual(w, baseFull + 0.05,
                                     "Width \(w) at pair \(i) above 1.3*base")
        }
    }

    func testJitterIsDeterministicAcrossBuilds() {
        let jitter = WidthJitter(amount: 0.25, frequency: 0.1, seed: 7)
        guard let m1 = RibbonMeshBuilder.build(
                operations: longHorizontalLineOps(),
                baseWidth: 8,
                widthJitter: jitter),
              let m2 = RibbonMeshBuilder.build(
                operations: longHorizontalLineOps(),
                baseWidth: 8,
                widthJitter: jitter)
        else { return XCTFail() }

        // The two meshes should be vertex-identical.
        XCTAssertEqual(m1.vertices.count, m2.vertices.count)
        for i in 0..<m1.vertices.count {
            XCTAssertEqual(m1.vertices[i].position.x, m2.vertices[i].position.x, accuracy: 0.001)
            XCTAssertEqual(m1.vertices[i].position.y, m2.vertices[i].position.y, accuracy: 0.001)
        }
    }

    func testZeroAmountJitterMatchesNoJitter() {
        let zero = WidthJitter(amount: 0)
        guard let withZero = RibbonMeshBuilder.build(
                operations: longHorizontalLineOps(),
                baseWidth: 8,
                widthJitter: zero),
              let withNil = RibbonMeshBuilder.build(
                operations: longHorizontalLineOps(),
                baseWidth: 8)
        else { return XCTFail() }

        XCTAssertEqual(withZero.vertices.count, withNil.vertices.count)
        for i in 0..<withZero.vertices.count {
            XCTAssertEqual(withZero.vertices[i].position.x, withNil.vertices[i].position.x, accuracy: 0.001)
            XCTAssertEqual(withZero.vertices[i].position.y, withNil.vertices[i].position.y, accuracy: 0.001)
        }
    }

    func testParametricCoordinatesUnaffectedByJitter() {
        // Width jitter should change vertex *positions* but not the
        // (s, t) parametric coordinates — those still need to span [0,1]
        // along the path and ±1 across.
        let jitter = WidthJitter(amount: 0.4, frequency: 0.1, seed: 9)
        guard let mesh = RibbonMeshBuilder.build(
            operations: longHorizontalLineOps(),
            baseWidth: 8,
            widthJitter: jitter
        ) else { return XCTFail() }

        let pairCount = mesh.vertices.count / 2
        for i in stride(from: 0, to: pairCount, by: max(1, pairCount / 5)) {
            let leftT = mesh.vertices[i * 2].parametric.y
            let rightT = mesh.vertices[i * 2 + 1].parametric.y
            XCTAssertEqual(leftT, 1, accuracy: 0.001,
                           "Left vertex t should be +1 regardless of jitter")
            XCTAssertEqual(rightT, -1, accuracy: 0.001,
                           "Right vertex t should be -1 regardless of jitter")
        }
    }
}
