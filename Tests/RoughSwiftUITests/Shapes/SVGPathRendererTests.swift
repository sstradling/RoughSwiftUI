import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SVGPathRendererTests: XCTestCase {
    // MARK: SVGPathRenderer Tests
    
    func testSVGPathRendererSimplePath() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 L 100 10 L 100 100 L 10 100 Z"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 8, "Should produce operations for all segments")
    }
    
    func testSVGPathRendererCurvePath() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 C 40 10 60 40 100 100"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 2, "Should produce operations for curve")
    }
    
    func testSVGPathRendererQuadCurve() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 Q 50 100 100 10"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 2, "Should produce operations for quad curve")
    }

    func testSVGPathRendererEllipticalArc() {
        var options = Options()
        options.roughness = 0

        let svgPath = "M 0 0 A 50 50 0 0 1 50 50"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)

        // Two rough passes. Each pass should contain Move + one cubic Bezier.
        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 2)
        XCTAssertEqual(ops.filter { $0 is LineTo }.count, 0)
    }

    func testSVGPathRendererLargeEllipticalArcSplitsIntoMultipleCubics() {
        var options = Options()
        options.roughness = 0

        let svgPath = "M 0 0 A 50 50 0 1 1 100 0"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)

        // A 180° arc is split into 2 cubic segments per pass.
        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 4)
    }

    func testSVGPathRendererZeroRadiusArcFallsBackToLine() {
        var options = Options()
        options.roughness = 0

        let svgPath = "M 0 0 A 0 50 0 0 1 100 0"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)

        XCTAssertEqual(ops.filter { $0 is Move }.count, 2)
        XCTAssertEqual(ops.filter { $0 is LineTo }.count, 2)
        XCTAssertEqual(ops.filter { $0 is BezierCurveTo }.count, 0)
    }
    
}
