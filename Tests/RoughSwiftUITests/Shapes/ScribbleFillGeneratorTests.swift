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
    
}
