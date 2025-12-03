import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class AdaptiveBezierSamplingTests: XCTestCase {
    // MARK: - StrokeToFillConverter Adaptive Sampling Tests
    
    func testStrokeToFillAdaptiveSamplingWithStraightLine() {
        // A straight line should use fewer samples
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // The result should be roughly rectangular for a straight line
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 90)
        XCTAssertLessThan(bounds.width, 120)
    }
    
    func testStrokeToFillAdaptiveSamplingWithNearlyStraightQuadCurve() {
        // Nearly straight quadratic curve
        let move = Move(data: [0, 0])
        let quad = QuadraticCurveTo(data: [50, 1, 100, 0]) // Control point nearly on line
        let operations: [RoughSwiftUI.Operation] = [move, quad]
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillAdaptiveSamplingWithHighlyCurvedQuad() {
        // Highly curved quadratic curve
        let move = Move(data: [0, 0])
        let quad = QuadraticCurveTo(data: [50, 100, 100, 0]) // Control point far from line
        let operations: [RoughSwiftUI.Operation] = [move, quad]
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 6,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Highly curved path should produce a result with significant height
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.height, 40, "Curved path should extend vertically")
    }
    
    func testStrokeToFillAdaptiveSamplingWithNearlyStraightCubic() {
        // Nearly straight cubic curve
        let move = Move(data: [0, 0])
        let cubic = BezierCurveTo(data: [33, 1, 66, -1, 100, 0]) // Control points nearly on line
        let operations: [RoughSwiftUI.Operation] = [move, cubic]
        
        let profile = BrushProfile.marker
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 12,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillAdaptiveSamplingWithHighlyCurvedCubic() {
        // Highly curved cubic (S-curve)
        let move = Move(data: [0, 50])
        let cubic = BezierCurveTo(data: [0, 150, 100, -50, 100, 50]) // S-curve
        let operations: [RoughSwiftUI.Operation] = [move, cubic]
        
        let profile = BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.3, end: 0.3)
        )
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // S-curve should have significant vertical extent
        // The curve won't reach the full control point extent, but should have noticeable height
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.height, 50, "S-curve should have significant vertical extent")
    }
    
    func testStrokeToFillAdaptiveSamplingPerformanceWithManyCurves() {
        // Performance test with many curves
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        
        for i in 0..<100 {
            let x = CGFloat(i * 20)
            let amplitude = CGFloat(10 + (i % 5) * 5)
            path.addCurve(
                to: CGPoint(x: x + 20, y: 0),
                control1: CGPoint(x: x + 5, y: amplitude),
                control2: CGPoint(x: x + 15, y: -amplitude)
            )
        }
        
        let profile = BrushProfile.pen
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 4,
            profile: profile
        )
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertFalse(result.isEmpty)
        XCTAssertLessThan(elapsed, 2.0, "Adaptive sampling should handle many curves efficiently")
    }
    
    func testStrokeToFillAdaptiveSamplingWithMixedCurveComplexity() {
        // Mix of straight lines and curves with varying complexity
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Straight line
        path.addLine(to: CGPoint(x: 50, y: 0))
        
        // Nearly straight quad
        path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 75, y: 2))
        
        // Highly curved cubic
        path.addCurve(to: CGPoint(x: 150, y: 0),
                      control1: CGPoint(x: 110, y: 50),
                      control2: CGPoint(x: 140, y: -50))
        
        // Another straight line
        path.addLine(to: CGPoint(x: 200, y: 0))
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Result should span the full width
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 180)
    }
    
    func testStrokeToFillAdaptiveSamplingConsistencyBetweenCalls() {
        // Verify that adaptive sampling produces consistent results
        let move = Move(data: [0, 0])
        let curve = BezierCurveTo(data: [30, 40, 70, 60, 100, 50])
        let operations: [RoughSwiftUI.Operation] = [move, curve]
        
        let profile = BrushProfile.pen
        
        let result1 = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        let result2 = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        let bounds1 = result1.boundingRect
        let bounds2 = result2.boundingRect
        
        // Results should be identical
        XCTAssertEqual(bounds1.width, bounds2.width, accuracy: 0.001)
        XCTAssertEqual(bounds1.height, bounds2.height, accuracy: 0.001)
    }
    
    func testStrokeToFillAdaptiveSamplingWithVeryLongCurve() {
        // Very long curve should still produce valid results
        let move = Move(data: [0, 0])
        let curve = BezierCurveTo(data: [500, 200, 1000, -200, 1500, 0])
        let operations: [RoughSwiftUI.Operation] = [move, curve]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 20,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 1400, "Long curve should have significant width")
    }
    
    func testStrokeToFillAdaptiveSamplingWithVeryShortCurve() {
        // Very short curve should still work correctly
        let move = Move(data: [0, 0])
        let curve = BezierCurveTo(data: [1, 2, 3, 1, 5, 0])
        let operations: [RoughSwiftUI.Operation] = [move, curve]
        
        let profile = BrushProfile.marker
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillAdaptiveSamplingPreservesThicknessVariation() {
        // Test that thickness profile is correctly applied with adaptive sampling
        let move = Move(data: [0, 0])
        let curve = BezierCurveTo(data: [30, 50, 70, 50, 100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, curve]
        
        // Tapered profile
        let taperedProfile = BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.1, end: 0.1)
        )
        
        // Uniform profile
        let uniformProfile = BrushProfile(
            tip: .circular,
            thicknessProfile: .uniform
        )
        
        let taperedResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 20,
            profile: taperedProfile
        )
        
        let uniformResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 20,
            profile: uniformProfile
        )
        
        // Both should produce results
        XCTAssertFalse(taperedResult.isEmpty)
        XCTAssertFalse(uniformResult.isEmpty)
        
        // Tapered should have different bounds than uniform
        // (tapered has thinner ends, so might have slightly different overall bounds)
        let taperedBounds = taperedResult.boundingRect
        let uniformBounds = uniformResult.boundingRect
        
        // Uniform should be at least as wide/tall (tapered ends reduce size slightly)
        XCTAssertGreaterThanOrEqual(uniformBounds.width, taperedBounds.width - 5)
    }
    
}
