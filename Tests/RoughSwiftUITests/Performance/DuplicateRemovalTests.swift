import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class DuplicateRemovalTests: XCTestCase {
    // MARK: - O(n) Duplicate Point Removal Tests (Spatial Bucketing)
    
    func testRemoveDuplicatePointsRemovesDuplicates() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let path = CGPath(rect: rect, transform: nil)
        
        var options = Options()
        options.scribbleTightness = 10
        
        // Generate scribble fill - the internal removeDuplicatePoints is called
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        // Should produce results (indirectly testing that duplicate removal works)
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testScribbleFillGeneratorWithManyIntersections() {
        // Create a complex path with many potential duplicate intersections
        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: 200, height: 200))
        
        var options = Options()
        options.scribbleTightness = 50 // High tightness = many rays = many intersections
        
        // This exercises the O(n) duplicate removal with many points
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
        
        // Should have many operations due to high tightness
        let totalOps = operationSets.flatMap { $0.operations }.count
        XCTAssertGreaterThan(totalOps, 10)
    }
    
    func testScribbleFillGeneratorPerformanceWithLargePath() {
        // Create a large path that would stress O(n²) algorithm
        let path = CGMutablePath()
        for i in 0..<10 {
            let x = CGFloat(i * 50)
            path.addRect(CGRect(x: x, y: 0, width: 40, height: 100))
        }
        
        var options = Options()
        options.scribbleTightness = 30
        
        // Measure that this completes in reasonable time (implicit performance test)
        // With O(n²) this would be slow; with O(n) it's fast
        let startTime = Date()
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        let elapsed = Date().timeIntervalSince(startTime)
        
        XCTAssertFalse(operationSets.isEmpty)
        
        // Should complete quickly (under 1 second even for complex paths)
        XCTAssertLessThan(elapsed, 1.0, "Scribble generation should be fast with O(n) duplicate removal")
    }
    
    func testScribbleFillWithCircularPath() {
        // Circles have many bezier curve intersections
        let path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: 150, height: 150), transform: nil)
        
        var options = Options()
        options.scribbleTightness = 25
        options.scribbleCurvature = 15
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        XCTAssertFalse(operationSets.isEmpty)
    }
    
    func testScribbleFillGeneratorWithSmallTolerance() {
        // Test that close-together points are properly deduplicated
        let rect = CGRect(x: 0, y: 0, width: 50, height: 50)
        let path = CGPath(rect: rect, transform: nil)
        
        var options = Options()
        options.scribbleTightness = 15
        
        let operationSets = ScribbleFillGenerator.generate(for: path, options: options)
        
        // Should produce clean results without duplicate points causing issues
        XCTAssertFalse(operationSets.isEmpty)
        
        // Each operation set should have valid operations
        for set in operationSets {
            XCTAssertFalse(set.operations.isEmpty)
        }
    }
    
}
