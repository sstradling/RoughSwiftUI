import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class ScribbleFillGeneratorTests: XCTestCase {
    // MARK: - ScribbleFillGenerator Tests
    
    func testScribbleFillGeneratorProducesOperationSets() {
        // Create a simple rectangular path
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        
        var options = Options()
        options.scribbleTightness = 10
        options.scribbleCurvature = 0
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        // Should produce at least one operation set
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testScribbleFillGeneratorWithCurvature() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        
        var options = Options()
        options.scribbleTightness = 10
        options.scribbleCurvature = 25
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
        
        // With curvature, should have bezier curve operations
        let hasQuadCurves = operationSets.flatMap { $0.operations }.contains { $0 is QuadraticCurveTo }
        XCTAssertTrue(hasQuadCurves, "Curved scribble should contain QuadraticCurveTo operations")
    }
    
    func testScribbleFillGeneratorWithDifferentOrigins() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        
        var options0 = Options()
        options0.scribbleOrigin = 0
        options0.scribbleTightness = 10
        
        var options90 = Options()
        options90.scribbleOrigin = 90
        options90.scribbleTightness = 10
        
        let sets0 = ScribbleFillGenerator.generate(for: path, options: options0)
        let sets90 = ScribbleFillGenerator.generate(for: path, options: options90)
        
        // Both should produce results
        XCTAssertFalse(sets0.isEmpty)
        XCTAssertFalse(sets90.isEmpty)
    }
    
    func testScribbleFillGeneratorWithVariableTightness() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        
        var options = Options()
        options.scribbleTightnessPattern = [5, 20, 5]
        options.scribbleCurvature = 10
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testScribbleFillGeneratorEmptyPath() {
        let path = CGMutablePath()
        
        var options = Options()
        options.scribbleTightness = 10
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        // Empty path should produce no operation sets
        XCTAssertTrue(operationSets.isEmpty)
    }
    
    func testScribbleFillGeneratorCircularPath() {
        // Create an ellipse path
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(ellipseIn: rect, transform: nil)
        
        var options = Options()
        options.scribbleTightness = 15
        options.scribbleCurvature = 20
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testScribbleStrokesFollowOrigin() {
        let rect = CGRect(x: 0, y: 0, width: 140, height: 90)
        let path = CGPath(rect: rect, transform: nil)
        var options = Options()
        options.scribbleTightness = 8
        options.scribbleCurvature = 0
        options.scribbleOrigin = 85

        let sets = ScribbleFillGenerator.generate(for: path, options: options)
        var counted = 0
        var aligned = 0
        for set in sets {
            let points = endpoints(of: set.operations)
            for index in 1..<points.count {
                let dx = points[index].x - points[index - 1].x
                let dy = points[index].y - points[index - 1].y
                guard hypot(dx, dy) > 25 else { continue }
                counted += 1
                var bearing = atan2(dy, dx) * 180 / .pi
                if bearing < 0 { bearing += 180 }
                if abs(bearing - 85) < 8 {
                    aligned += 1
                }
            }
        }
        XCTAssertGreaterThan(counted, 3)
        XCTAssertEqual(aligned, counted)
    }

    func testScribbleFillGeneratorTightnessAffectsVertexCount() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        
        var optionsLow = Options()
        optionsLow.scribbleTightness = 5
        optionsLow.scribbleCurvature = 0
        
        var optionsHigh = Options()
        optionsHigh.scribbleTightness = 20
        optionsHigh.scribbleCurvature = 0
        
        let setsLow = ScribbleFillGenerator.generate(for: path, options: optionsLow)
        let setsHigh = ScribbleFillGenerator.generate(for: path, options: optionsHigh)
        
        // Both should produce results
        XCTAssertFalse(setsLow.isEmpty)
        XCTAssertFalse(setsHigh.isEmpty)
        
        // Higher tightness should generally produce more operations
        let opsLow = setsLow.flatMap { $0.operations }.count
        let opsHigh = setsHigh.flatMap { $0.operations }.count
        
        XCTAssertGreaterThan(opsHigh, opsLow, "Higher tightness should produce more operations")
    }

    private func endpoints(of operations: [RoughSwiftUI.Operation]) -> [CGPoint] {
        operations.compactMap { operation in
            if let move = operation as? Move {
                let point = move.point.toRoughPoint()
                return CGPoint(x: CGFloat(point[0]), y: CGFloat(point[1]))
            }
            if let line = operation as? LineTo {
                let point = line.point.toRoughPoint()
                return CGPoint(x: CGFloat(point[0]), y: CGFloat(point[1]))
            }
            return nil
        }
    }

}
