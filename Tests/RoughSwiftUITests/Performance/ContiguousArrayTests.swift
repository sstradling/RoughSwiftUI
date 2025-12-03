import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class ContiguousArrayTests: XCTestCase {
    // MARK: - Contiguous Point Array Tests (New Optimized Storage)
    
    func testContiguousPointArrayOperations() {
        // Test that ContiguousPointArray correctly stores and retrieves points
        var array = ContiguousPointArray(capacity: 3)
        
        let p1 = CGPoint(x: 10, y: 20)
        let p2 = CGPoint(x: 30, y: 40)
        let p3 = CGPoint(x: 50, y: 60)
        
        array.append(p1)
        array.append(p2)
        array.append(p3)
        
        XCTAssertEqual(array.count, 3)
        
        XCTAssertEqual(array.point(at: 0).x, p1.x, accuracy: 0.001)
        XCTAssertEqual(array.point(at: 0).y, p1.y, accuracy: 0.001)
        XCTAssertEqual(array.point(at: 1).x, p2.x, accuracy: 0.001)
        XCTAssertEqual(array.point(at: 1).y, p2.y, accuracy: 0.001)
        XCTAssertEqual(array.point(at: 2).x, p3.x, accuracy: 0.001)
        XCTAssertEqual(array.point(at: 2).y, p3.y, accuracy: 0.001)
    }
    
    func testContiguousPointArrayAddingOffsets() {
        // Test that adding offsets works correctly
        var original = ContiguousPointArray(capacity: 2)
        original.append(CGPoint(x: 10, y: 20))
        original.append(CGPoint(x: 30, y: 40))
        
        var offsets = ContiguousPointArray(capacity: 2)
        offsets.append(CGPoint(x: 5, y: -5))
        offsets.append(CGPoint(x: -10, y: 10))
        
        var result = ContiguousPointArray(capacity: 2)
        original.addingOffsets(offsets, into: &result)
        
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.point(at: 0).x, 15, accuracy: 0.001)  // 10 + 5
        XCTAssertEqual(result.point(at: 0).y, 15, accuracy: 0.001)  // 20 + (-5)
        XCTAssertEqual(result.point(at: 1).x, 20, accuracy: 0.001)  // 30 + (-10)
        XCTAssertEqual(result.point(at: 1).y, 50, accuracy: 0.001)  // 40 + 10
    }
    
    func testPrecomputedVarianceOffsetsGeneratesCorrectStepCount() {
        // Test that pre-computed offsets match step count
        let config = AnimationConfig(steps: 6, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config)
        
        var original = ContiguousPointArray(capacity: 3)
        original.append(CGPoint(x: 10, y: 10))
        original.append(CGPoint(x: 50, y: 50))
        original.append(CGPoint(x: 100, y: 100))
        
        let offsets = PrecomputedVarianceOffsets.precompute(
            pointCount: 3,
            generator: generator,
            originalPoints: original
        )
        
        XCTAssertEqual(offsets.stepCount, 6)
    }
    
}
