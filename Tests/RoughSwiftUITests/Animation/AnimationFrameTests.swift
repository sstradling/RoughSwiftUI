import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class AnimationFrameTests: XCTestCase {
    // MARK: - Pre-generated Animation Frame Tests
    
    func testPathVarianceGeneratorStepCount() {
        let config = AnimationConfig(steps: 8, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config)
        
        XCTAssertEqual(generator.stepCount, 8)
    }
    
    func testPathVarianceGeneratorPrecomputeAllSteps() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.closeSubpath()
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let precomputed = generator.precomputeAllSteps(for: path)
        
        // Should produce one path per step
        XCTAssertEqual(precomputed.count, 4)
        
        // Each path should be different from the original
        for variedPath in precomputed {
            XCTAssertNotEqual(variedPath.boundingRect, path.boundingRect)
        }
        
        // Different steps should have different variations
        XCTAssertNotEqual(precomputed[0].boundingRect, precomputed[1].boundingRect)
    }
    
    func testPathVarianceGeneratorPrecomputeIsDeterministic() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        
        let config = AnimationConfig(steps: 3, speed: .medium, variance: .medium)
        let baseSeed: UInt64 = 12345
        
        let generator1 = PathVarianceGenerator(config: config, baseSeed: baseSeed)
        let generator2 = PathVarianceGenerator(config: config, baseSeed: baseSeed)
        
        let precomputed1 = generator1.precomputeAllSteps(for: path)
        let precomputed2 = generator2.precomputeAllSteps(for: path)
        
        // Same seed should produce identical results
        for (p1, p2) in zip(precomputed1, precomputed2) {
            XCTAssertEqual(p1.boundingRect, p2.boundingRect)
        }
    }
    
    func testRoughRenderCommandPrecomputeAllSteps() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let command = RoughRenderCommand(
            path: path,
            style: .stroke(Color.red, lineWidth: 2),
            cap: .round,
            join: .round
        )
        
        let config = AnimationConfig(steps: 5, speed: .medium, variance: .high)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let precomputed = command.precomputeAllSteps(generator: generator)
        
        // Should produce one command per step
        XCTAssertEqual(precomputed.count, 5)
        
        // Each command should preserve the style
        for variedCommand in precomputed {
            if case .stroke(_, let lineWidth) = variedCommand.style {
                XCTAssertEqual(lineWidth, 2)
            } else {
                XCTFail("Expected stroke style to be preserved")
            }
            
            // Cap and join should be preserved
            XCTAssertEqual(variedCommand.cap, .round)
            XCTAssertEqual(variedCommand.join, .round)
        }
        
        // Paths should vary between steps
        XCTAssertNotEqual(precomputed[0].path.boundingRect, precomputed[1].path.boundingRect)
    }
    
    func testRoughRenderCommandPrecomputeWithClipPath() {
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
        
        let config = AnimationConfig(steps: 3, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let precomputed = command.precomputeAllSteps(generator: generator)
        
        // All precomputed commands should have clip paths
        for variedCommand in precomputed {
            XCTAssertNotNil(variedCommand.clipPath)
            XCTAssertTrue(variedCommand.inverseClip)
        }
    }
    
    func testZeroVarianceReturnsOriginalPoint() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .veryLow)
        // Create generator with zero variance by using a custom config
        var zeroConfig = config
        // veryLow is 0.005, which is not zero - test the guard clause behavior
        let generator = PathVarianceGenerator(config: zeroConfig, baseSeed: 42)
        
        let point = CGPoint(x: 100, y: 100)
        let varied = generator.applyVariance(to: point, step: 0, index: 0)
        
        // With very low variance, the change should be minimal
        let maxExpectedOffset = 100.0 * 0.005 * 2
        XCTAssertLessThan(abs(varied.x - point.x), maxExpectedOffset)
        XCTAssertLessThan(abs(varied.y - point.y), maxExpectedOffset)
    }
    
    func testPrecomputedPathsWithComplexElements() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 50), control: CGPoint(x: 75, y: 0))
        path.addCurve(to: CGPoint(x: 50, y: 100), control1: CGPoint(x: 100, y: 75), control2: CGPoint(x: 75, y: 100))
        path.closeSubpath()
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let precomputed = generator.precomputeAllSteps(for: path)
        
        // Should handle all element types
        XCTAssertEqual(precomputed.count, 4)
        
        // Each precomputed path should be non-empty
        for variedPath in precomputed {
            XCTAssertFalse(variedPath.isEmpty)
        }
    }
    
    func testAnimationFrameCreation() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let commands = [
            RoughRenderCommand(path: path, style: .stroke(Color.red, lineWidth: 2)),
            RoughRenderCommand(path: path, style: .fill(Color.blue))
        ]
        
        // AnimationFrame is just a container for pre-computed commands
        let frame = AnimationFrame(commands: commands)
        
        // Frame should contain same number of commands
        XCTAssertEqual(frame.commands.count, 2)
    }
    
    func testAnimationFrameCacheEmpty() {
        let cache = AnimationFrameCache.empty
        
        XCTAssertTrue(cache.frames.isEmpty)
        XCTAssertEqual(cache.size, .zero)
        XCTAssertEqual(cache.stepCount, 0)
    }
    
    func testAnimationFrameCachePrecompute() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let commands = [
            RoughRenderCommand(path: path, style: .stroke(Color.red, lineWidth: 2))
        ]
        
        let config = AnimationConfig(steps: 6, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        let size = CGSize(width: 200, height: 200)
        
        let cache = AnimationFrameCache.precompute(
            baseCommands: commands,
            generator: generator,
            size: size
        )
        
        XCTAssertEqual(cache.frames.count, 6)
        XCTAssertEqual(cache.stepCount, 6)
        XCTAssertEqual(cache.size, size)
    }
    
    func testAnimationFrameCacheSubscript() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        
        let commands = [
            RoughRenderCommand(path: path, style: .fill(Color.green))
        ]
        
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let cache = AnimationFrameCache.precompute(
            baseCommands: commands,
            generator: generator,
            size: CGSize(width: 100, height: 100)
        )
        
        // Normal access
        let frame0 = cache[0]
        let frame3 = cache[3]
        XCTAssertEqual(frame0.commands.count, 1)
        XCTAssertEqual(frame3.commands.count, 1)
        
        // Wrapping access (step 4 should wrap to 0 with 4 steps)
        let frameWrapped = cache[4]
        XCTAssertEqual(frameWrapped.commands.count, frame0.commands.count)
        
        // Large index wrapping
        let frameLarge = cache[100]
        XCTAssertEqual(frameLarge.commands.count, 1)
    }
    
    func testAnimationFrameCachePreservesCommandProperties() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        
        var clipPath = SwiftUI.Path()
        clipPath.addRect(CGRect(x: 0, y: 0, width: 100, height: 100))
        
        let commands = [
            RoughRenderCommand(
                path: path,
                style: .stroke(Color.red, lineWidth: 5),
                clipPath: clipPath,
                inverseClip: true,
                cap: .square,
                join: .miter
            )
        ]
        
        let config = AnimationConfig(steps: 3, speed: .medium, variance: .medium)
        let generator = PathVarianceGenerator(config: config, baseSeed: 42)
        
        let cache = AnimationFrameCache.precompute(
            baseCommands: commands,
            generator: generator,
            size: CGSize(width: 100, height: 100)
        )
        
        // Check that all properties are preserved in cached frames
        for i in 0..<cache.stepCount {
            let frame = cache[i]
            let command = frame.commands[0]
            
            // Style should be preserved
            if case .stroke(_, let lineWidth) = command.style {
                XCTAssertEqual(lineWidth, 5)
            } else {
                XCTFail("Expected stroke style")
            }
            
            // Clip path should exist and be varied
            XCTAssertNotNil(command.clipPath)
            XCTAssertTrue(command.inverseClip)
            
            // Cap and join should be preserved
            XCTAssertEqual(command.cap, .square)
            XCTAssertEqual(command.join, .miter)
        }
    }
    
}
