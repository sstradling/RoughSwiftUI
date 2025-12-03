import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class AdaptiveBezierSamplingCoreTests: XCTestCase {
    // MARK: - Adaptive Bezier Sampling Tests
    
    func testAdaptiveBezierSamplingWithNearlyStraightCurve() {
        // A nearly straight cubic bezier should still produce valid results
        // Control points very close to the line between start and end
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        // Control points are nearly on the straight line from (0,0) to (100,0)
        path.addCurve(to: CGPoint(x: 100, y: 0), 
                      control1: CGPoint(x: 33, y: 1),  // Very slight deviation
                      control2: CGPoint(x: 66, y: -1))
        path.closeSubpath()
        
        var options = Options()
        options.scribbleTightness = 10
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        // Should produce results even with nearly straight curves
        // (this tests that low segment counts don't cause issues)
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testAdaptiveBezierSamplingWithHighlyCurvedPath() {
        // A highly curved cubic bezier should produce more detailed results
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 50))
        // Control points far from the line, creating a very curved path
        path.addCurve(to: CGPoint(x: 100, y: 50),
                      control1: CGPoint(x: 0, y: 150),   // Far below
                      control2: CGPoint(x: 100, y: -50)) // Far above
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.addLine(to: CGPoint(x: 0, y: 100))
        path.closeSubpath()
        
        var options = Options()
        options.scribbleTightness = 15
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        // Should produce results with complex curves
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testAdaptiveBezierSamplingWithQuadraticCurve() {
        // Test with quadratic bezier curves
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        // Quadratic curve with control point far from midpoint
        path.addQuadCurve(to: CGPoint(x: 100, y: 0), control: CGPoint(x: 50, y: 80))
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.addLine(to: CGPoint(x: 0, y: 100))
        path.closeSubpath()
        
        var options = Options()
        options.scribbleTightness = 12
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testAdaptiveBezierSamplingWithMixedCurveTypes() {
        // Path with mix of lines, quadratic and cubic curves
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 50), control: CGPoint(x: 100, y: 0))
        path.addCurve(to: CGPoint(x: 50, y: 100),
                      control1: CGPoint(x: 100, y: 75),
                      control2: CGPoint(x: 75, y: 100))
        path.addLine(to: CGPoint(x: 0, y: 100))
        path.closeSubpath()
        
        var options = Options()
        options.scribbleTightness = 10
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
        
        // Should have operations in the result
        let totalOps = operationSets.flatMap { $0.operations }.count
        XCTAssertGreaterThan(totalOps, 0)
    }
    
    func testAdaptiveBezierSamplingPerformanceWithManySmallCurves() {
        // Test performance with many small curves
        // Adaptive sampling should use fewer segments for small curves
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Add many small curves
        for i in 0..<50 {
            let x = CGFloat(i * 10)
            path.addCurve(to: CGPoint(x: x + 10, y: CGFloat(i % 2) * 5),
                          control1: CGPoint(x: x + 3, y: 2),
                          control2: CGPoint(x: x + 7, y: 3))
        }
        path.addLine(to: CGPoint(x: 500, y: 50))
        path.addLine(to: CGPoint(x: 0, y: 50))
        path.closeSubpath()
        
        var options = Options()
        options.scribbleTightness = 20
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertFalse(operationSets.isEmpty)
        // Should complete in reasonable time (< 2 seconds)
        XCTAssertLessThan(elapsed, 2.0, "Adaptive sampling should handle many small curves efficiently")
    }
    
    func testAdaptiveBezierSamplingPerformanceWithLargeCurves() {
        // Test performance with large, highly curved paths
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 100))
        
        // Add large, complex curves
        for i in 0..<20 {
            let x = CGFloat(i * 100)
            let amplitude = CGFloat(50 + i * 10)
            path.addCurve(to: CGPoint(x: x + 100, y: 100),
                          control1: CGPoint(x: x + 25, y: 100 + amplitude),
                          control2: CGPoint(x: x + 75, y: 100 - amplitude))
        }
        path.addLine(to: CGPoint(x: 2000, y: 200))
        path.addLine(to: CGPoint(x: 0, y: 200))
        path.closeSubpath()
        
        var options = Options()
        options.scribbleTightness = 15
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertFalse(operationSets.isEmpty)
        // Should complete in reasonable time
        XCTAssertLessThan(elapsed, 3.0, "Adaptive sampling should handle large curves efficiently")
    }
    
    func testAdaptiveBezierSamplingAccuracyWithCircle() {
        // Circles are approximated with bezier curves
        // Test that adaptive sampling maintains accuracy
        let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)
        
        var options = Options()
        options.scribbleTightness = 15
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
        
        // Should have reasonable number of operations for a circle fill
        let totalOps = operationSets.flatMap { $0.operations }.count
        XCTAssertGreaterThan(totalOps, 5, "Circle fill should produce meaningful operations")
    }
    
}
