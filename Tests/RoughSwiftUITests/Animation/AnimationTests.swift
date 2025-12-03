import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class AnimationTests: XCTestCase {
    // MARK: - Animation Tests
    
    func testAnimationSpeedDurations() {
        XCTAssertEqual(AnimationSpeed.slow.duration, 0.6)
        XCTAssertEqual(AnimationSpeed.medium.duration, 0.3)
        XCTAssertEqual(AnimationSpeed.fast.duration, 0.1)
    }
    
    func testAnimationVarianceFactors() {
        XCTAssertEqual(AnimationVariance.veryLow.factor, 0.005)
        XCTAssertEqual(AnimationVariance.low.factor, 0.01)
        XCTAssertEqual(AnimationVariance.medium.factor, 0.05)
        XCTAssertEqual(AnimationVariance.high.factor, 0.10)
    }
    
    func testAnimationConfigDefaults() {
        let config = AnimationConfig()
        
        XCTAssertEqual(config.steps, 4)
        XCTAssertEqual(config.speed, .medium)
        XCTAssertEqual(config.variance, .medium)
    }
    
    func testAnimationConfigCustomValues() {
        let config = AnimationConfig(steps: 8, speed: .slow, variance: .high)
        
        XCTAssertEqual(config.steps, 8)
        XCTAssertEqual(config.speed, .slow)
        XCTAssertEqual(config.variance, .high)
    }
    
    func testAnimationConfigMinimumSteps() {
        // Steps should be clamped to minimum of 2
        let config = AnimationConfig(steps: 1, speed: .fast, variance: .low)
        
        XCTAssertEqual(config.steps, 2)
    }
    
    func testAnimationConfigDefaultStatic() {
        let defaultConfig = AnimationConfig.default
        
        XCTAssertEqual(defaultConfig.steps, 4)
        XCTAssertEqual(defaultConfig.speed, .medium)
        XCTAssertEqual(defaultConfig.variance, .medium)
    }
    
    func testPathVarianceGeneratorCreatesCorrectNumberOfSeeds() {
        let config = AnimationConfig(steps: 6, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config)
        
        XCTAssertEqual(generator.stepSeeds.count, 6)
        XCTAssertEqual(generator.variance, 0.05)
    }
    
    func testPathVarianceGeneratorDeterministicSeeds() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let baseSeed: UInt64 = 12345
        
        let generator1 = PathVarianceGenerator(config: config, baseSeed: baseSeed)
        let generator2 = PathVarianceGenerator(config: config, baseSeed: baseSeed)
        
        // Same base seed should produce same step seeds
        XCTAssertEqual(generator1.stepSeeds, generator2.stepSeeds)
    }
    
    func testPathVarianceGeneratorAppliesVariance() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .high)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let originalPoint = CGPoint(x: 100, y: 100)
        let variedPoint = generator.applyVariance(to: originalPoint, step: 0, index: 0)
        
        // Point should be modified (with high variance, it should be noticeably different)
        // But not by an extreme amount
        XCTAssertNotEqual(variedPoint, originalPoint)
        
        // The variance should be reasonable (within 20% for high variance)
        let maxOffset = max(abs(originalPoint.x), abs(originalPoint.y)) * 0.10 * 2
        XCTAssertLessThan(abs(variedPoint.x - originalPoint.x), maxOffset)
        XCTAssertLessThan(abs(variedPoint.y - originalPoint.y), maxOffset)
    }
    
    func testPathVarianceGeneratorDifferentStepsProduceDifferentResults() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let point = CGPoint(x: 50, y: 50)
        let variedStep0 = generator.applyVariance(to: point, step: 0, index: 0)
        let variedStep1 = generator.applyVariance(to: point, step: 1, index: 0)
        
        // Different steps should produce different variations
        XCTAssertNotEqual(variedStep0, variedStep1)
    }
    
    func testPathVarianceGeneratorSameStepSameResult() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let point = CGPoint(x: 50, y: 50)
        let result1 = generator.applyVariance(to: point, step: 0, index: 0)
        let result2 = generator.applyVariance(to: point, step: 0, index: 0)
        
        // Same step and index should produce identical results (deterministic)
        XCTAssertEqual(result1, result2)
    }
    
    func testSwiftUIPathWithVariance() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.closeSubpath()
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let variedPath = path.withVariance(generator: generator, step: 0)
        
        // The varied path should be different from the original
        // We can check this by comparing bounding boxes (they should be similar but not identical)
        let originalBounds = path.boundingRect
        let variedBounds = variedPath.boundingRect
        
        // Bounds should be close but not exactly the same
        XCTAssertNotEqual(originalBounds, variedBounds)
    }
    
    func testRoughRenderCommandWithVariance() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        
        let command = RoughRenderCommand(
            path: path,
            style: .stroke(Color.red, lineWidth: 2)
        )
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .high)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let variedCommand = command.withVariance(generator: generator, step: 0)
        
        // Style should remain the same
        if case .stroke(let color, let lineWidth) = variedCommand.style {
            XCTAssertEqual(lineWidth, 2)
            // Color comparison is tricky, but lineWidth should be preserved
        } else {
            XCTFail("Expected stroke style to be preserved")
        }
        
        // Path should be modified
        XCTAssertNotEqual(command.path.boundingRect, variedCommand.path.boundingRect)
    }
    
    func testRoughRenderCommandWithVariancePreservesClipPath() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        
        var clipPath = SwiftUI.Path()
        clipPath.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let command = RoughRenderCommand(
            path: path,
            style: .fill(Color.blue),
            clipPath: clipPath,
            inverseClip: true
        )
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let variedCommand = command.withVariance(generator: generator, step: 0)
        
        // Clip path should exist and be varied
        XCTAssertNotNil(variedCommand.clipPath)
        XCTAssertTrue(variedCommand.inverseClip)
    }
    
    func testRoughViewAnimatedModifierReturnsAnimatedView() {
        let roughView = RoughView()
            .fill(Color.red)
            .fillStyle(.hachure)
            .circle()
        
        let animatedView = roughView.animated(steps: 6, speed: .slow, variance: .low)
        
        // Should return an AnimatedRoughView (we can't easily inspect internals,
        // but we can verify it compiles and returns the correct type)
        XCTAssertNotNil(animatedView)
    }
    
    func testRoughViewAnimatedModifierWithConfig() {
        let config = AnimationConfig(steps: 8, speed: .fast, variance: .high)
        let roughView = RoughView()
            .fill(Color.green)
            .circle()
        
        let animatedView = roughView.animated(config: config)
        
        XCTAssertNotNil(animatedView)
    }
    
    func testAnimatedRoughViewWithSVGPath() throws {
        let svgPath = "M10 10 L100 10 L100 100 Z"
        let roughView = RoughView()
            .stroke(Color.blue)
            .fill(Color.red)
            .draw(Path(d: svgPath))
        
        let animatedView = roughView.animated(steps: 4, speed: .medium, variance: .low)
        
        // Verify the animated view was created with the drawable
        XCTAssertNotNil(animatedView)
        XCTAssertEqual(roughView.drawables.count, 1)
    }
    
    func testPathVarianceWithQuadCurve() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 100), control: CGPoint(x: 50, y: 0))
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let variedPath = path.withVariance(generator: generator, step: 0)
        
        // Path should be modified
        XCTAssertNotEqual(path.boundingRect, variedPath.boundingRect)
    }
    
    func testPathVarianceWithBezierCurve() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(
            to: CGPoint(x: 100, y: 100),
            control1: CGPoint(x: 25, y: 0),
            control2: CGPoint(x: 75, y: 100)
        )
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let variedPath = path.withVariance(generator: generator, step: 0)
        
        // Path should be modified
        XCTAssertNotEqual(path.boundingRect, variedPath.boundingRect)
    }
    
    func testVeryLowVarianceProducesSubtleChanges() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .veryLow)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let point = CGPoint(x: 100, y: 100)
        let variedPoint = generator.applyVariance(to: point, step: 0, index: 0)
        
        // Very low variance (0.5%) should produce very subtle changes
        let maxExpectedOffset = 100.0 * 0.005 * 2 // magnitude * variance * 2 (for random range)
        let actualOffsetX = abs(variedPoint.x - point.x)
        let actualOffsetY = abs(variedPoint.y - point.y)
        
        XCTAssertLessThan(actualOffsetX, maxExpectedOffset)
        XCTAssertLessThan(actualOffsetY, maxExpectedOffset)
    }
    
}
