import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class RoughMathTests: XCTestCase {
    // MARK: RoughMath Tests
    
    func testRoughMathRandOffsetRespectsRoughness() {
        var options = Options()
        
        // With zero roughness, offset should be zero
        options.roughness = 0
        let zeroOffset = RoughMath.randOffset(10, options: options)
        XCTAssertEqual(zeroOffset, 0, "Zero roughness should produce zero offset")
        
        // With non-zero roughness, offset should be within bounds
        options.roughness = 1.0
        var hasNonZero = false
        for _ in 0..<100 {
            let offset = RoughMath.randOffset(10, options: options)
            XCTAssertLessThanOrEqual(abs(offset), 10, "Offset should be within bounds")
            if offset != 0 { hasNonZero = true }
        }
        XCTAssertTrue(hasNonZero, "Should produce non-zero offsets with roughness > 0")
    }
    
    func testRoughMathRandOffsetWithRange() {
        var options = Options()
        options.roughness = 1.0
        
        for _ in 0..<100 {
            let offset = RoughMath.randOffsetWithRange(5, 15, options: options)
            XCTAssertGreaterThanOrEqual(offset, 5, "Offset should be >= min")
            XCTAssertLessThanOrEqual(offset, 15, "Offset should be <= max")
        }
    }
    
    func testRoughMathDoubleLineOpsProducesOperations() {
        var options = Options()
        options.roughness = 1.0
        options.bowing = 1.0
        
        let ops = RoughMath.doubleLineOps(x1: 0, y1: 0, x2: 100, y2: 100, options: options)
        
        // Double line should produce operations for two passes
        XCTAssertGreaterThan(ops.count, 0, "Should produce operations")
        
        // Should have Move and BezierCurveTo operations
        let hasMoves = ops.contains { $0 is Move }
        let hasCurves = ops.contains { $0 is BezierCurveTo }
        XCTAssertTrue(hasMoves, "Should have Move operations")
        XCTAssertTrue(hasCurves, "Should have BezierCurveTo operations")
    }
    
    func testRoughMathLineOpsWithBowing() {
        var options = Options()
        options.roughness = 1.0
        options.bowing = 2.0  // High bowing
        
        let ops = RoughMath.lineOps(x1: 0, y1: 0, x2: 100, y2: 0, options: options, move: true, overlay: false)
        
        XCTAssertGreaterThan(ops.count, 0, "Should produce operations")
        
        // With bowing, the bezier curve control points should not be on the straight line
        if let curve = ops.first(where: { $0 is BezierCurveTo }) as? BezierCurveTo {
            // Control points should have y offset due to bowing (line is horizontal)
            let cp1y = curve.controlPoint1.y
            let cp2y = curve.controlPoint2.y
            // At least one control point should be offset from y=0 line
            XCTAssertTrue(abs(cp1y) > 0 || abs(cp2y) > 0, "Bowing should offset control points")
        }
    }
    
    func testRoughMathEllipseOpsProducesClosedShape() {
        var options = Options()
        options.roughness = 1.0
        options.curveStepCount = 9
        
        let ops = RoughMath.ellipseOps(cx: 50, cy: 50, rx: 40, ry: 30, options: options)
        
        XCTAssertGreaterThan(ops.count, 10, "Ellipse should produce many operations")
        
        // Should have moves and curves
        let hasMoves = ops.contains { $0 is Move }
        let hasCurves = ops.contains { $0 is BezierCurveTo }
        XCTAssertTrue(hasMoves, "Should have Move operations")
        XCTAssertTrue(hasCurves, "Should have BezierCurveTo operations")
    }
    
    func testRoughMathRectangleOpsProducesFourSides() {
        var options = Options()
        options.roughness = 0.5
        
        let ops = RoughMath.rectangleOps(x: 10, y: 10, width: 80, height: 60, options: options)
        
        // Rectangle has 4 sides, each with double line = 16 or more operations
        XCTAssertGreaterThanOrEqual(ops.count, 16, "Rectangle should produce operations for 4 sides")
    }
    
    func testRoughMathPolygonOps() {
        var options = Options()
        options.roughness = 1.0
        
        // Triangle
        let points: [[Float]] = [[0, 100], [50, 0], [100, 100]]
        let ops = RoughMath.polygonOps(points: points, options: options)
        
        // 3 sides with double lines
        XCTAssertGreaterThan(ops.count, 10, "Triangle should produce operations for 3 sides")
    }
    
    func testRoughMathLinearPathOpsOpen() {
        var options = Options()
        options.roughness = 1.0
        
        let points: [[Float]] = [[0, 0], [50, 50], [100, 0]]
        let ops = RoughMath.linearPathOps(points: points, close: false, options: options)
        
        // 2 segments (open path)
        XCTAssertGreaterThan(ops.count, 4, "Open path should produce operations for segments")
    }
    
    func testRoughMathLinearPathOpsClosed() {
        var options = Options()
        options.roughness = 1.0
        
        let points: [[Float]] = [[0, 0], [50, 50], [100, 0]]
        let opsOpen = RoughMath.linearPathOps(points: points, close: false, options: options)
        let opsClosed = RoughMath.linearPathOps(points: points, close: true, options: options)
        
        // Closed path should have more operations (extra closing segment)
        XCTAssertGreaterThan(opsClosed.count, opsOpen.count, "Closed path should have more operations")
    }
    
    func testRoughMathArcOps() {
        var options = Options()
        options.roughness = 1.0
        options.curveStepCount = 9
        
        let ops = RoughMath.arcOps(
            cx: 50, cy: 50, rx: 40, ry: 40,
            start: 0, stop: Float.pi,
            closed: false, roughClosure: true,
            options: options
        )
        
        XCTAssertGreaterThan(ops.count, 5, "Arc should produce operations")
    }
    
    func testRoughMathCurveOps() {
        var options = Options()
        options.roughness = 1.0
        options.curveTightness = 0
        
        let points: [[Float]] = [[0, 0], [25, 50], [50, 25], [75, 75], [100, 50]]
        let ops = RoughMath.curveOps(points: points, options: options)
        
        XCTAssertGreaterThan(ops.count, 5, "Curve should produce operations")
    }
    
    func testRoughMathPolygonCentroid() {
        // Square centered at (50, 50)
        let square: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let centroid = RoughMath.polygonCentroid(square)
        
        XCTAssertEqual(centroid[0], 50, accuracy: 0.1, "Centroid X should be center")
        XCTAssertEqual(centroid[1], 50, accuracy: 0.1, "Centroid Y should be center")
    }
    
    func testRoughMathPolygonBounds() {
        let triangle: [[Float]] = [[10, 20], [80, 30], [50, 90]]
        let bounds = RoughMath.polygonBounds(triangle)
        
        XCTAssertEqual(bounds.minX, 10, "Min X should be 10")
        XCTAssertEqual(bounds.maxX, 80, "Max X should be 80")
        XCTAssertEqual(bounds.minY, 20, "Min Y should be 20")
        XCTAssertEqual(bounds.maxY, 90, "Max Y should be 90")
    }
    
    func testRoughMathLineLength() {
        let segment: [[Float]] = [[0, 0], [3, 4]]
        let length = RoughMath.lineLength(segment)
        
        XCTAssertEqual(length, 5, accuracy: 0.001, "3-4-5 triangle hypotenuse should be 5")
    }
    
}
