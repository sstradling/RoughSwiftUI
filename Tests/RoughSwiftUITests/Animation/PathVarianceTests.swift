import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class PathVarianceTests: XCTestCase {
    // MARK: - Optimized Pre-computed Variance Tests
    
    func testPrecomputedPathVarianceWithNewOffsetSystem() {
        // Test that PrecomputedPathVariance correctly uses offset-based storage
        var testPath = SwiftUI.Path()
        testPath.move(to: CGPoint(x: 0, y: 0))
        testPath.addLine(to: CGPoint(x: 100, y: 100))
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .low)
        let generator = PathVarianceGenerator(config: config)
        
        var precomputed = PrecomputedPathVariance(from: testPath, generator: generator)
        
        // Build paths for all steps
        for step in 0..<config.steps {
            let variedPath = precomputed.buildPath(forStep: step)
            XCTAssertFalse(variedPath.isEmpty, "Varied path should not be empty")
            
            let bounds = variedPath.boundingRect
            // Bounds should be near the original (0,0) to (100,100) with some variance
            XCTAssertGreaterThan(bounds.width, 50, "Path width should be substantial")
            XCTAssertGreaterThan(bounds.height, 50, "Path height should be substantial")
        }
    }
    
    func testOptimizedAnimationFrameCacheMemoryEfficiency() {
        // Test that OptimizedAnimationFrameCache uses offset storage
        let config = AnimationConfig(steps: 8, speed: .fast, variance: .high)
        let generator = PathVarianceGenerator(config: config)
        
        // Create a more complex path
        var testPath = SwiftUI.Path()
        testPath.move(to: CGPoint(x: 0, y: 0))
        for i in 1...20 {
            testPath.addLine(to: CGPoint(x: Double(i * 10), y: Double((i % 2) * 50)))
        }
        
        let command = RoughRenderCommand(
            path: testPath,
            style: .fill(SwiftUI.Color.red)
        )
        
        var optimizedCache = OptimizedAnimationFrameCache.precompute(
            commands: [command],
            generator: generator,
            size: CGSize(width: 300, height: 100)
        )
        
        XCTAssertEqual(optimizedCache.stepCount, 8)
        XCTAssertFalse(optimizedCache.isEmpty)
        
        // Get commands for each step
        for step in 0..<optimizedCache.stepCount {
            let commands = optimizedCache.commands(forStep: step)
            XCTAssertEqual(commands.count, 1)
            XCTAssertFalse(commands[0].path.isEmpty)
        }
    }
    
    func testComputeOffsetProducesSameResultAsApplyVariance() {
        // Test that computeOffset + original = applyVariance
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config)
        
        let testPoint = CGPoint(x: 75, y: 125)
        
        for step in 0..<config.steps {
            let offset = generator.computeOffset(for: testPoint, step: step, index: 5)
            let direct = generator.applyVariance(to: testPoint, step: step, index: 5)
            
            let reconstructed = CGPoint(x: testPoint.x + offset.x, y: testPoint.y + offset.y)
            
            XCTAssertEqual(reconstructed.x, direct.x, accuracy: 0.001, "Reconstructed X should match direct variance")
            XCTAssertEqual(reconstructed.y, direct.y, accuracy: 0.001, "Reconstructed Y should match direct variance")
        }
    }
    
}
