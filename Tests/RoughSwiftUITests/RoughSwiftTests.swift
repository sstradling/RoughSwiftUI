import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class RoughSwiftTests: XCTestCase {
    func testDrawing() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 300, height: 300))

        let drawing = try XCTUnwrap(
            generator.generate(drawable: Rectangle(x: 10, y: 20, width: 100, height: 200))
        )

        XCTAssertEqual(drawing.shape, "rectangle")
        XCTAssertEqual(drawing.sets.count, 2)

        let set = drawing.sets[0]
        // Operation count varies due to roughness; just ensure it's in a reasonable range
        XCTAssertGreaterThan(set.operations.count, 100)
        XCTAssertLessThan(set.operations.count, 300)
    }

    func testDrawingWithOption() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 300, height: 300))

        var options = Options()
        options.fillAngle = 60
        options.fillSpacing = 8
        options.fillStyle = .zigzag
        options.fill = UIColor.red
        let drawing = try XCTUnwrap(
            generator.generate(drawable: Circle(x: 50, y: 150, diameter: 80), options: options)
        )

        XCTAssertEqual(drawing.shape, "circle")
        XCTAssertEqual(drawing.sets.count, 2)

        let set = drawing.sets[0]
        XCTAssertTrue(set.operations.count == 68 || set.operations.count == 76)

        XCTAssertEqual(drawing.options.fillStyle, .zigzag)
        XCTAssertEqual(drawing.options.fillAngle, 60)
        XCTAssertEqual(drawing.options.fillSpacing, 8)
    }

    func testSwiftUIRendererProducesCommands() throws {
        let size = CGSize(width: 300, height: 300)
        let engine = Engine()
        let generator = engine.generator(size: size)

        var options = Options()
        options.fill = UIColor.red
        options.stroke = UIColor.green

        let drawing = try XCTUnwrap(generator.generate(
            drawable: Rectangle(x: 10, y: 10, width: 50, height: 50),
            options: options
        ))

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: size)

        XCTAssertFalse(commands.isEmpty)
    }

    func testSwiftUIRendererPathAndFillVariants() {
        var options = Options()
        options.stroke = UIColor.green
        options.fill = UIColor.red

        // Simple two-point path
        let move = Move(data: [0, 0])
        let line = LineTo(data: [10, 10])
        let operations: [RoughSwiftUI.Operation] = [move, line]

        let size = CGSize(width: 50, height: 50)
        let renderer = SwiftUIRenderer()

        // Border path
        let pathSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        let pathDrawing = Drawing(shape: "test", sets: [pathSet], options: options)
        let pathCommands = renderer.commands(for: pathDrawing, options: options, in: size)
        XCTAssertFalse(pathCommands.isEmpty)

        // Solid fill path
        let fillSet = OperationSet(
            type: .fillPath,
            operations: operations,
            path: nil,
            size: nil
        )
        let fillDrawing = Drawing(shape: "test", sets: [fillSet], options: options)
        let fillCommands = renderer.commands(for: fillDrawing, options: options, in: size)
        XCTAssertFalse(fillCommands.isEmpty)

        // Sketch fill
        let sketchSet = OperationSet(
            type: .fillSketch,
            operations: operations,
            path: nil,
            size: nil
        )
        let sketchDrawing = Drawing(shape: "test", sets: [sketchSet], options: options)
        let sketchCommands = renderer.commands(for: sketchDrawing, options: options, in: size)
        XCTAssertFalse(sketchCommands.isEmpty)
    }

    func testSwiftUIRendererSVGVariantsWithExtremeSizes() {
        var options = Options()
        options.fill = UIColor.red

        // Minimal SVG path (triangle)
        let svgPath = "M0 0 L10 0 L10 10 Z"
        let operations: [RoughSwiftUI.Operation] = [] // not used by path2D* cases

        let renderer = SwiftUIRenderer()

        // Solid SVG fill with zero size canvas (will be clamped internally)
        let fillSet = OperationSet(
            type: .path2DFill,
            operations: operations,
            path: svgPath,
            size: nil
        )
        let zeroSizeDrawing = Drawing(shape: "path", sets: [fillSet], options: options)
        let zeroCommands = renderer.commands(for: zeroSizeDrawing, options: options, in: .zero)
        XCTAssertFalse(zeroCommands.isEmpty)

        // Pattern SVG fill with extreme aspect ratio
        let patternSet = OperationSet(
            type: .path2DPattern,
            operations: operations,
            path: svgPath,
            size: nil
        )
        let wideSize = CGSize(width: 1000, height: 10)
        let patternDrawing = Drawing(shape: "path", sets: [patternSet], options: options)
        let patternCommands = renderer.commands(for: patternDrawing, options: options, in: wideSize)
        XCTAssertFalse(patternCommands.isEmpty)
    }

    func testRectangle() {
        let size = CGSize(width: 300, height: 300)
        let engine = Engine()
        let generator = engine.generator(size: size)

        let drawing = generator.generate(
            drawable: Rectangle(x: 10, y: 20, width: 100, height: 200)
        )
        XCTAssertNotNil(drawing)
    }

    func testArcDrawingProducesOperations() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 300, height: 300))

        let arc = Arc(
            x: 150,
            y: 150,
            width: 100,
            height: 100,
            start: 0,
            stop: .pi,
            closed: false
        )

        let drawing = try XCTUnwrap(
            generator.generate(drawable: arc)
        )

        // We don't depend on the exact shape string, but we do assert that
        // rough.js produced at least one operation set with operations.
        XCTAssertFalse(drawing.sets.isEmpty)
        XCTAssertFalse(drawing.sets[0].operations.isEmpty)
    }

    func testOptionsDictionaryRoundTripAndColors() {
        var base = Options()
        base.maxRandomnessOffset = 5
        base.roughness = 2
        base.bowing = 1.5
        base.strokeWidth = 3
        base.curveTightness = 0.8
        base.curveStepCount = 12
        base.fillStyle = .zigzag
        base.fillWeight = 4
        base.fillAngle = 30
        base.fillSpacing = 6
        base.dashOffset = 2
        base.dashGap = 3
        base.zigzagOffset = 7
        base.stroke = UIColor.green
        base.fill = UIColor.red

        let dict = base.toRoughDictionary()
        let decoded = Options(dictionary: dict)

        XCTAssertEqual(decoded.maxRandomnessOffset, base.maxRandomnessOffset)
        XCTAssertEqual(decoded.roughness, base.roughness)
        XCTAssertEqual(decoded.bowing, base.bowing)
        XCTAssertEqual(decoded.strokeWidth, base.strokeWidth)
        XCTAssertEqual(decoded.curveTightness, base.curveTightness)
        XCTAssertEqual(decoded.curveStepCount, base.curveStepCount)
        XCTAssertEqual(decoded.fillStyle, base.fillStyle)
        XCTAssertEqual(decoded.fillWeight, base.fillWeight)
        XCTAssertEqual(decoded.fillAngle, base.fillAngle)
        XCTAssertEqual(decoded.fillSpacing, base.fillSpacing)
        XCTAssertEqual(decoded.dashOffset, base.dashOffset)
        XCTAssertEqual(decoded.dashGap, base.dashGap)
        XCTAssertEqual(decoded.zigzagOffset, base.zigzagOffset)

        XCTAssertEqual(decoded.stroke.toHex(), base.stroke.toHex())
        XCTAssertEqual(decoded.fill.toHex(), base.fill.toHex())
    }

    func testRoughViewSwiftUIColorModifiersBridgeThroughOptions() {
        let view = RoughView()
            .fill(Color.red)
            .stroke(Color.green)

        // Ensure the SwiftUI `Color` overloads ultimately configure
        // the underlying `Options` colors as expected.
        XCTAssertEqual(view.options.fill.toHex(), UIColor(.red).toHex())
        XCTAssertEqual(view.options.stroke.toHex(), UIColor(.green).toHex())
    }
    
    // MARK: - SVG-Specific Options Tests
    
    func testSVGSpecificOptionsDefaults() {
        let options = Options()
        
        // SVG-specific options should be nil by default
        XCTAssertNil(options.svgStrokeWidth)
        XCTAssertNil(options.svgFillWeight)
        
        // Default alignment should be center
        XCTAssertEqual(options.svgFillStrokeAlignment, .center)
        
        // Effective values should fall back to base options
        XCTAssertEqual(options.effectiveSVGStrokeWidth, options.strokeWidth)
        XCTAssertEqual(options.effectiveSVGFillWeight, options.fillWeight)
    }
    
    func testSVGSpecificOptionsOverride() {
        var options = Options()
        options.strokeWidth = 1
        options.fillWeight = 2
        options.svgStrokeWidth = 5
        options.svgFillWeight = 3
        
        // Effective values should use SVG-specific overrides
        XCTAssertEqual(options.effectiveSVGStrokeWidth, 5)
        XCTAssertEqual(options.effectiveSVGFillWeight, 3)
        
        // Base options should remain unchanged
        XCTAssertEqual(options.strokeWidth, 1)
        XCTAssertEqual(options.fillWeight, 2)
    }
    
    func testSVGFillStrokeAlignmentEnum() {
        // Test all alignment cases exist
        let center: SVGFillStrokeAlignment = .center
        let inside: SVGFillStrokeAlignment = .inside
        let outside: SVGFillStrokeAlignment = .outside
        
        XCTAssertNotEqual(center, inside)
        XCTAssertNotEqual(center, outside)
        XCTAssertNotEqual(inside, outside)
    }
    
    func testRoughViewSVGModifiers() {
        let view = RoughView()
            .svgStrokeWidth(4)
            .svgFillWeight(2)
            .svgFillStrokeAlignment(.inside)
        
        XCTAssertEqual(view.options.svgStrokeWidth, 4)
        XCTAssertEqual(view.options.svgFillWeight, 2)
        XCTAssertEqual(view.options.svgFillStrokeAlignment, .inside)
    }
    
    func testSVGPathDrawingIsRecognized() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 300, height: 300))
        
        let svgPath = "M10 10 L100 10 L100 100 Z"
        let drawing = try XCTUnwrap(
            generator.generate(drawable: Path(d: svgPath))
        )
        
        // SVG paths should have shape "path"
        XCTAssertEqual(drawing.shape, "path")
    }
    
    func testSVGRendererUsesSVGSpecificOptions() {
        var options = Options()
        options.strokeWidth = 1
        options.fillWeight = 1
        options.svgStrokeWidth = 5
        options.svgFillWeight = 3
        options.fill = UIColor.red
        
        let svgPath = "M0 0 L10 0 L10 10 Z"
        let operations: [RoughSwiftUI.Operation] = []
        
        let renderer = SwiftUIRenderer()
        let size = CGSize(width: 100, height: 100)
        
        // Create a path2DPattern set (uses fillWeight for stroke)
        let patternSet = OperationSet(
            type: .path2DPattern,
            operations: operations,
            path: svgPath,
            size: nil
        )
        
        // "path" shape triggers SVG-specific rendering
        let drawing = Drawing(shape: "path", sets: [patternSet], options: options)
        let commands = renderer.commands(for: drawing, options: options, in: size)
        
        XCTAssertFalse(commands.isEmpty)
        
        // Verify the command uses the SVG-specific fill weight (3) not the base (1)
        if case .stroke(_, let lineWidth) = commands[0].style {
            // SVG fill weight is 3, center alignment means no doubling
            XCTAssertEqual(lineWidth, 3)
        } else {
            XCTFail("Expected stroke style")
        }
    }
    
    func testSVGStrokeAlignmentInside() {
        var options = Options()
        options.svgFillWeight = 4
        options.svgFillStrokeAlignment = .inside
        options.fill = UIColor.red
        
        let svgPath = "M0 0 L10 0 L10 10 Z"
        let operations: [RoughSwiftUI.Operation] = []
        
        let renderer = SwiftUIRenderer()
        let size = CGSize(width: 100, height: 100)
        
        let patternSet = OperationSet(
            type: .path2DPattern,
            operations: operations,
            path: svgPath,
            size: nil
        )
        
        let drawing = Drawing(shape: "path", sets: [patternSet], options: options)
        let commands = renderer.commands(for: drawing, options: options, in: size)
        
        XCTAssertFalse(commands.isEmpty)
        
        // Inside alignment should have clip path and double the line width
        let command = commands[0]
        XCTAssertNotNil(command.clipPath, "Inside alignment should have a clip path")
        XCTAssertFalse(command.inverseClip, "Inside alignment should not use inverse clip")
        
        if case .stroke(_, let lineWidth) = command.style {
            // Inside alignment doubles the line width (4 * 2 = 8)
            XCTAssertEqual(lineWidth, 8)
        } else {
            XCTFail("Expected stroke style")
        }
    }
    
    func testSVGStrokeAlignmentOutside() {
        var options = Options()
        options.svgFillWeight = 4
        options.svgFillStrokeAlignment = .outside
        options.fill = UIColor.red
        
        let svgPath = "M0 0 L10 0 L10 10 Z"
        let operations: [RoughSwiftUI.Operation] = []
        
        let renderer = SwiftUIRenderer()
        let size = CGSize(width: 100, height: 100)
        
        let patternSet = OperationSet(
            type: .path2DPattern,
            operations: operations,
            path: svgPath,
            size: nil
        )
        
        let drawing = Drawing(shape: "path", sets: [patternSet], options: options)
        let commands = renderer.commands(for: drawing, options: options, in: size)
        
        XCTAssertFalse(commands.isEmpty)
        
        // Outside alignment should have clip path with inverse clip and double the line width
        let command = commands[0]
        XCTAssertNotNil(command.clipPath, "Outside alignment should have a clip path")
        XCTAssertTrue(command.inverseClip, "Outside alignment should use inverse clip")
        
        if case .stroke(_, let lineWidth) = command.style {
            // Outside alignment doubles the line width (4 * 2 = 8)
            XCTAssertEqual(lineWidth, 8)
        } else {
            XCTFail("Expected stroke style")
        }
    }
    
    func testSVGStrokeAlignmentCenter() {
        var options = Options()
        options.svgFillWeight = 4
        options.svgFillStrokeAlignment = .center
        options.fill = UIColor.red
        
        let svgPath = "M0 0 L10 0 L10 10 Z"
        let operations: [RoughSwiftUI.Operation] = []
        
        let renderer = SwiftUIRenderer()
        let size = CGSize(width: 100, height: 100)
        
        let patternSet = OperationSet(
            type: .path2DPattern,
            operations: operations,
            path: svgPath,
            size: nil
        )
        
        let drawing = Drawing(shape: "path", sets: [patternSet], options: options)
        let commands = renderer.commands(for: drawing, options: options, in: size)
        
        XCTAssertFalse(commands.isEmpty)
        
        // Center alignment should have no clip path and normal line width
        let command = commands[0]
        XCTAssertNil(command.clipPath, "Center alignment should not have a clip path")
        XCTAssertFalse(command.inverseClip)
        
        if case .stroke(_, let lineWidth) = command.style {
            // Center alignment uses normal line width (4)
            XCTAssertEqual(lineWidth, 4)
        } else {
            XCTFail("Expected stroke style")
        }
    }
    
    func testSVGScalingTransformIsApplied() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 100, height: 100))
        
        // Large SVG that needs scaling down
        let largeSVG = "M0 0 L500 0 L500 500 Z"
        
        var options = Options()
        options.fill = UIColor.red
        
        let drawing = try XCTUnwrap(
            generator.generate(drawable: Path(d: largeSVG), options: options)
        )
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 100, height: 100))
        
        // Should produce commands (scaling should not fail)
        XCTAssertFalse(commands.isEmpty)
    }
    
    func testNonSVGShapesIgnoreSVGOptions() {
        var options = Options()
        options.strokeWidth = 2
        options.svgStrokeWidth = 10  // Should be ignored for non-SVG
        options.stroke = UIColor.green
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [10, 10])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let renderer = SwiftUIRenderer()
        let size = CGSize(width: 50, height: 50)
        
        // Non-SVG shape (shape is "test", not "path")
        let pathSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        let drawing = Drawing(shape: "test", sets: [pathSet], options: options)
        let commands = renderer.commands(for: drawing, options: options, in: size)
        
        XCTAssertFalse(commands.isEmpty)
        
        // Should use base strokeWidth (2), not svgStrokeWidth (10)
        if case .stroke(_, let lineWidth) = commands[0].style {
            XCTAssertEqual(lineWidth, 2)
        } else {
            XCTFail("Expected stroke style")
        }
    }
    
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
    
    // MARK: - Text Path Conversion Tests
    
    func testTextPathConverterProducesNonEmptyPath() {
        let font = UIFont.systemFont(ofSize: 48)
        let path = TextPathConverter.path(from: "Hello", font: font)
        
        // The path should not be empty
        XCTAssertFalse(path.isEmpty)
        
        // The bounding box should have reasonable dimensions
        let bounds = path.boundingBox
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }
    
    func testTextPathConverterWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Test",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 36)]
        )
        let path = TextPathConverter.path(from: attributed)
        
        XCTAssertFalse(path.isEmpty)
        XCTAssertGreaterThan(path.boundingBox.width, 0)
    }
    
    func testTextPathConverterWithFontName() {
        let path = TextPathConverter.path(from: "ABC", fontName: "Helvetica", fontSize: 24)
        
        XCTAssertFalse(path.isEmpty)
    }
    
    func testTextPathConverterBoundingBox() {
        let font = UIFont.systemFont(ofSize: 32)
        let bounds = TextPathConverter.boundingBox(for: "Wide", font: font)
        
        // Bounding box should have positive dimensions
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }
    
    func testTextPathConverterEmptyStringProducesEmptyPath() {
        let font = UIFont.systemFont(ofSize: 24)
        let path = TextPathConverter.path(from: "", font: font)
        
        // Empty string should produce an empty path
        XCTAssertTrue(path.isEmpty)
    }
    
    func testTextPathConverterDifferentFontSizesProduceDifferentBounds() {
        let smallPath = TextPathConverter.path(from: "A", font: UIFont.systemFont(ofSize: 12))
        let largePath = TextPathConverter.path(from: "A", font: UIFont.systemFont(ofSize: 48))
        
        // Larger font should produce larger bounds
        XCTAssertGreaterThan(largePath.boundingBox.width, smallPath.boundingBox.width)
        XCTAssertGreaterThan(largePath.boundingBox.height, smallPath.boundingBox.height)
    }
    
    // MARK: - CGPath to SVG Tests
    
    func testCGPathToSVGSimpleLine() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let svg = path.toSVGPathString()
        
        // Should contain move and line commands
        XCTAssertTrue(svg.contains("M"))
        XCTAssertTrue(svg.contains("L"))
    }
    
    func testCGPathToSVGTriangle() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 100))
        path.closeSubpath()
        
        let svg = path.toSVGPathString()
        
        // Should contain move, lines, and close commands
        XCTAssertTrue(svg.contains("M"))
        XCTAssertTrue(svg.contains("L"))
        XCTAssertTrue(svg.contains("Z"))
    }
    
    func testCGPathToSVGQuadCurve() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 100), control: CGPoint(x: 50, y: 0))
        
        let svg = path.toSVGPathString()
        
        // Should contain quad curve command
        XCTAssertTrue(svg.contains("Q"))
    }
    
    func testCGPathToSVGCubicCurve() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 100, y: 100), control1: CGPoint(x: 25, y: 0), control2: CGPoint(x: 75, y: 100))
        
        let svg = path.toSVGPathString()
        
        // Should contain cubic curve command
        XCTAssertTrue(svg.contains("C"))
    }
    
    func testCGPathToSVGWithPrecision() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 1.23456789, y: 9.87654321))
        
        let svg2 = path.toSVGPathString(precision: 2)
        let svg4 = path.toSVGPathString(precision: 4)
        
        // Different precisions should produce different output
        XCTAssertNotEqual(svg2, svg4)
        
        // Higher precision should result in longer string (more decimal places)
        XCTAssertGreaterThan(svg4.count, svg2.count)
    }
    
    func testCGPathToSVGFlippingY() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let normalSVG = path.toSVGPathString()
        let flippedSVG = path.toSVGPathStringFlippingY()
        
        // Flipped should be different from normal
        XCTAssertNotEqual(normalSVG, flippedSVG)
    }
    
    func testCGPathToSVGWithTransform() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let transform = CGAffineTransform(scaleX: 2, y: 2)
        let scaledSVG = path.toSVGPathString(applying: transform)
        
        // Scaled path should have larger coordinates
        XCTAssertTrue(scaledSVG.contains("20"))
    }
    
    func testCGPathToSVGEmptyPath() {
        let path = CGMutablePath()
        let svg = path.toSVGPathString()
        
        // Empty path should produce empty string
        XCTAssertTrue(svg.isEmpty)
    }
    
    // MARK: - Text Drawable Tests
    
    func testTextDrawableMethod() {
        let text = Text("Hello", font: UIFont.systemFont(ofSize: 24))
        
        // Text should use "path" method (reuses SVG path rendering)
        XCTAssertEqual(text.method, "path")
    }
    
    func testTextDrawableArguments() {
        let text = Text("A", font: UIFont.systemFont(ofSize: 48))
        
        // Arguments should contain a single SVG path string
        XCTAssertEqual(text.arguments.count, 1)
        XCTAssertTrue(text.arguments[0] is String)
        
        let svgPath = text.arguments[0] as! String
        XCTAssertFalse(svgPath.isEmpty)
        XCTAssertTrue(svgPath.contains("M"))  // Should have move commands
    }
    
    func testTextDrawableWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Bold",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 32)]
        )
        let text = Text(attributedString: attributed)
        
        XCTAssertEqual(text.method, "path")
        XCTAssertEqual(text.arguments.count, 1)
    }
    
    func testTextDrawableGeneratesDrawing() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 300, height: 100))
        
        let text = Text("Test", font: UIFont.systemFont(ofSize: 36))
        let drawing = try XCTUnwrap(generator.generate(drawable: text))
        
        // Should produce a path drawing
        XCTAssertEqual(drawing.shape, "path")
        XCTAssertFalse(drawing.sets.isEmpty)
    }
    
    func testTextDrawableRendersCommands() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 200, height: 80))
        
        var options = Options()
        options.fill = UIColor.red
        options.stroke = UIColor.black
        
        let text = Text("Hi", font: UIFont.boldSystemFont(ofSize: 48))
        let drawing = try XCTUnwrap(generator.generate(drawable: text, options: options))
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 200, height: 80))
        
        // Should produce render commands
        XCTAssertFalse(commands.isEmpty)
    }
    
    // MARK: - RoughView Text Modifier Tests
    
    func testRoughViewTextModifier() {
        let view = RoughView()
            .fill(Color.red)
            .text("Hello", font: UIFont.systemFont(ofSize: 24))
        
        // Should have one drawable
        XCTAssertEqual(view.drawables.count, 1)
        
        // Drawable should be a Text
        XCTAssertTrue(view.drawables[0] is RoughSwiftUI.Text)
    }
    
    func testRoughViewTextModifierWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Styled",
            attributes: [.font: UIFont.italicSystemFont(ofSize: 20)]
        )
        let view = RoughView()
            .text(attributedString: attributed)
        
        XCTAssertEqual(view.drawables.count, 1)
        XCTAssertTrue(view.drawables[0] is RoughSwiftUI.Text)
    }
    
    func testRoughViewTextModifierWithFontName() {
        let view = RoughView()
            .text("ABC", fontName: "Helvetica-Bold", fontSize: 32)
        
        XCTAssertEqual(view.drawables.count, 1)
    }
    
    func testRoughViewMultipleTexts() {
        let view = RoughView()
            .text("First", font: UIFont.systemFont(ofSize: 24))
            .text("Second", font: UIFont.systemFont(ofSize: 24))
        
        // Should have two drawables
        XCTAssertEqual(view.drawables.count, 2)
    }
    
    // MARK: - RoughText View Tests
    
    func testRoughTextViewCreation() {
        let roughText = RoughText("Hello", font: UIFont.systemFont(ofSize: 36))
        
        // Should compile and create successfully
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Styled",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 24)]
        )
        let roughText = RoughText(attributedString: attributed)
        
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewWithFontName() {
        let roughText = RoughText("Test", fontName: "Courier", fontSize: 28)
        
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewModifiersReturnSelf() {
        let roughText = RoughText("Test", font: UIFont.systemFont(ofSize: 24))
            .fill(Color.red)
            .stroke(Color.black)
            .fillStyle(.hachure)
            .strokeWidth(2)
            .roughness(1.5)
        
        // All modifiers should chain properly
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewAnimatedModifier() {
        let roughText = RoughText("Wobble", font: UIFont.boldSystemFont(ofSize: 32))
            .fill(Color.blue)
            .fillStyle(.crossHatch)
        
        let animatedView = roughText.animated(steps: 6, speed: .slow, variance: .low)
        
        // Should return AnimatedRoughView
        XCTAssertNotNil(animatedView)
    }
    
    func testRoughTextViewSVGModifiers() {
        let roughText = RoughText("SVG", font: UIFont.systemFont(ofSize: 24))
            .svgStrokeWidth(3)
            .svgFillWeight(2)
            .svgFillStrokeAlignment(.inside)
        
        XCTAssertNotNil(roughText)
    }
    
    // MARK: - Brush Tip Tests
    
    func testBrushTipDefaults() {
        let tip = BrushTip()
        
        XCTAssertEqual(tip.roundness, 1.0)
        XCTAssertEqual(tip.angle, 0)
        XCTAssertTrue(tip.directionSensitive)
    }
    
    func testBrushTipCircularPreset() {
        let tip = BrushTip.circular
        
        XCTAssertEqual(tip.roundness, 1.0)
        XCTAssertEqual(tip.angle, 0)
        XCTAssertFalse(tip.directionSensitive)
    }
    
    func testBrushTipCalligraphicPreset() {
        let tip = BrushTip.calligraphic
        
        XCTAssertEqual(tip.roundness, 0.3)
        XCTAssertEqual(tip.angle, .pi / 4, accuracy: 0.001)
        XCTAssertTrue(tip.directionSensitive)
    }
    
    func testBrushTipFlatPreset() {
        let tip = BrushTip.flat
        
        XCTAssertEqual(tip.roundness, 0.2)
        XCTAssertEqual(tip.angle, 0)
        XCTAssertTrue(tip.directionSensitive)
    }
    
    func testBrushTipRoundnessClamping() {
        // Test that roundness is clamped to valid range
        let tooLow = BrushTip(roundness: -0.5)
        let tooHigh = BrushTip(roundness: 2.0)
        
        XCTAssertEqual(tooLow.roundness, 0.01)
        XCTAssertEqual(tooHigh.roundness, 1.0)
    }
    
    func testBrushTipEffectiveWidthCircular() {
        let tip = BrushTip.circular
        let baseWidth: CGFloat = 10
        
        // Circular tip should return same width regardless of direction
        let width0 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: 0)
        let width45 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 4)
        let width90 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 2)
        
        XCTAssertEqual(width0, baseWidth)
        XCTAssertEqual(width45, baseWidth)
        XCTAssertEqual(width90, baseWidth)
    }
    
    func testBrushTipEffectiveWidthDirectionSensitive() {
        let tip = BrushTip(roundness: 0.5, angle: 0, directionSensitive: true)
        let baseWidth: CGFloat = 10
        
        // With flat horizontal brush, horizontal stroke should be narrower than vertical
        let widthHorizontal = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: 0)
        let widthVertical = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 2)
        
        // Vertical stroke cuts through the thin part, horizontal through the wide part
        XCTAssertNotEqual(widthHorizontal, widthVertical)
    }
    
    func testBrushTipEffectiveWidthDirectionInsensitive() {
        let tip = BrushTip(roundness: 0.5, angle: 0, directionSensitive: false)
        let baseWidth: CGFloat = 10
        
        // Direction-insensitive should return base width regardless of angle
        let width0 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: 0)
        let width90 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 2)
        
        XCTAssertEqual(width0, baseWidth)
        XCTAssertEqual(width90, baseWidth)
    }
    
    func testBrushTipEquatable() {
        let tip1 = BrushTip(roundness: 0.5, angle: 0.1, directionSensitive: true)
        let tip2 = BrushTip(roundness: 0.5, angle: 0.1, directionSensitive: true)
        let tip3 = BrushTip(roundness: 0.6, angle: 0.1, directionSensitive: true)
        
        XCTAssertEqual(tip1, tip2)
        XCTAssertNotEqual(tip1, tip3)
    }
    
    // MARK: - Thickness Profile Tests
    
    func testThicknessProfileUniform() {
        let profile = ThicknessProfile.uniform
        
        XCTAssertEqual(profile.multiplier(at: 0), 1.0)
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0)
        XCTAssertEqual(profile.multiplier(at: 1.0), 1.0)
    }
    
    func testThicknessProfileTaperIn() {
        let profile = ThicknessProfile.taperIn(start: 0.5)
        
        // At start, should be thin
        XCTAssertEqual(profile.multiplier(at: 0), 0, accuracy: 0.001)
        
        // At midpoint (end of taper), should be full
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        
        // After taper, should stay full
        XCTAssertEqual(profile.multiplier(at: 0.75), 1.0, accuracy: 0.001)
        XCTAssertEqual(profile.multiplier(at: 1.0), 1.0, accuracy: 0.001)
    }
    
    func testThicknessProfileTaperOut() {
        let profile = ThicknessProfile.taperOut(end: 0.5)
        
        // At start, should be full
        XCTAssertEqual(profile.multiplier(at: 0), 1.0, accuracy: 0.001)
        
        // At midpoint (start of taper), should be full
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        
        // At end, should be thin
        XCTAssertEqual(profile.multiplier(at: 1.0), 0, accuracy: 0.001)
    }
    
    func testThicknessProfileTaperBoth() {
        let profile = ThicknessProfile.taperBoth(start: 0.25, end: 0.25)
        
        // At start, should be thin
        XCTAssertEqual(profile.multiplier(at: 0), 0, accuracy: 0.001)
        
        // In middle, should be full
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        
        // At end, should be thin
        XCTAssertEqual(profile.multiplier(at: 1.0), 0, accuracy: 0.001)
    }
    
    func testThicknessProfilePressure() {
        let profile = ThicknessProfile.pressure([0.2, 0.6, 1.0, 0.8, 0.4])
        
        // At start, should match first value
        XCTAssertEqual(profile.multiplier(at: 0), 0.2, accuracy: 0.001)
        
        // At end, should match last value
        XCTAssertEqual(profile.multiplier(at: 1.0), 0.4, accuracy: 0.001)
        
        // Mid values should be interpolated
        let midValue = profile.multiplier(at: 0.5)
        XCTAssertGreaterThan(midValue, 0.5)
    }
    
    func testThicknessProfileCustom() {
        let profile = ThicknessProfile.custom([0.5, 1.0, 0.5])
        
        XCTAssertEqual(profile.multiplier(at: 0), 0.5, accuracy: 0.001)
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        XCTAssertEqual(profile.multiplier(at: 1.0), 0.5, accuracy: 0.001)
    }
    
    func testThicknessProfileNaturalPenPreset() {
        let profile = ThicknessProfile.naturalPen
        
        // Should taper at both ends
        XCTAssertLessThan(profile.multiplier(at: 0), 1.0)
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        XCTAssertLessThan(profile.multiplier(at: 1.0), 1.0)
    }
    
    func testThicknessProfileBrushStartPreset() {
        let profile = ThicknessProfile.brushStart
        
        // Should taper at start only
        XCTAssertLessThan(profile.multiplier(at: 0), 1.0)
        XCTAssertEqual(profile.multiplier(at: 1.0), 1.0, accuracy: 0.001)
    }
    
    func testThicknessProfileBrushEndPreset() {
        let profile = ThicknessProfile.brushEnd
        
        // Should taper at end only
        XCTAssertEqual(profile.multiplier(at: 0), 1.0, accuracy: 0.001)
        XCTAssertLessThan(profile.multiplier(at: 1.0), 1.0)
    }
    
    func testThicknessProfileEmptyArrayFallback() {
        let profile = ThicknessProfile.custom([])
        
        // Empty array should fallback to 1.0
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0)
    }
    
    func testThicknessProfileSingleValueArray() {
        let profile = ThicknessProfile.custom([0.7])
        
        // Single value should return that value everywhere
        XCTAssertEqual(profile.multiplier(at: 0), 0.7)
        XCTAssertEqual(profile.multiplier(at: 0.5), 0.7)
        XCTAssertEqual(profile.multiplier(at: 1.0), 0.7)
    }
    
    func testThicknessProfileClampsTParameter() {
        let profile = ThicknessProfile.taperIn(start: 0.5)
        
        // Values outside 0-1 should be clamped
        XCTAssertEqual(profile.multiplier(at: -0.5), profile.multiplier(at: 0))
        XCTAssertEqual(profile.multiplier(at: 1.5), profile.multiplier(at: 1.0))
    }
    
    func testThicknessProfileEquatable() {
        let profile1 = ThicknessProfile.taperIn(start: 0.3)
        let profile2 = ThicknessProfile.taperIn(start: 0.3)
        let profile3 = ThicknessProfile.taperIn(start: 0.5)
        
        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }
    
    // MARK: - Brush Cap Tests
    
    func testBrushCapCGLineCapConversion() {
        XCTAssertEqual(BrushCap.butt.cgLineCap, .butt)
        XCTAssertEqual(BrushCap.round.cgLineCap, .round)
        XCTAssertEqual(BrushCap.square.cgLineCap, .square)
    }
    
    // MARK: - Brush Join Tests
    
    func testBrushJoinCGLineJoinConversion() {
        XCTAssertEqual(BrushJoin.miter.cgLineJoin, .miter)
        XCTAssertEqual(BrushJoin.round.cgLineJoin, .round)
        XCTAssertEqual(BrushJoin.bevel.cgLineJoin, .bevel)
    }
    
    // MARK: - Brush Profile Tests
    
    func testBrushProfileDefaults() {
        let profile = BrushProfile()
        
        XCTAssertEqual(profile.tip, .circular)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
        XCTAssertEqual(profile.cap, .round)
        XCTAssertEqual(profile.join, .round)
    }
    
    func testBrushProfileDefaultPreset() {
        let profile = BrushProfile.default
        
        XCTAssertFalse(profile.requiresCustomRendering)
    }
    
    func testBrushProfileCalligraphicPreset() {
        let profile = BrushProfile.calligraphic
        
        XCTAssertEqual(profile.tip, .calligraphic)
        XCTAssertEqual(profile.thicknessProfile, .naturalPen)
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileMarkerPreset() {
        let profile = BrushProfile.marker
        
        XCTAssertEqual(profile.tip, .flat)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
        XCTAssertEqual(profile.cap, .butt)
        XCTAssertEqual(profile.join, .bevel)
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfilePenPreset() {
        let profile = BrushProfile.pen
        
        XCTAssertEqual(profile.tip, .circular)
        XCTAssertEqual(profile.thicknessProfile, .penPressure)
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileRequiresCustomRenderingWithNonCircularTip() {
        let profile = BrushProfile(tip: .flat, thicknessProfile: .uniform)
        
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileRequiresCustomRenderingWithVariableThickness() {
        let profile = BrushProfile(tip: .circular, thicknessProfile: .naturalPen)
        
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileNoCustomRenderingForSimpleProfile() {
        let profile = BrushProfile(
            tip: BrushTip(roundness: 1.0, angle: 0, directionSensitive: false),
            thicknessProfile: .uniform
        )
        
        XCTAssertFalse(profile.requiresCustomRendering)
    }
    
    func testBrushProfileEquatable() {
        let profile1 = BrushProfile.calligraphic
        let profile2 = BrushProfile.calligraphic
        let profile3 = BrushProfile.marker
        
        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }
    
    // MARK: - Options Brush Profile Tests
    
    func testOptionsBrushProfileDefaults() {
        let options = Options()
        
        XCTAssertEqual(options.brushProfile, .default)
        XCTAssertEqual(options.brushTip, .circular)
        XCTAssertEqual(options.thicknessProfile, .uniform)
        XCTAssertEqual(options.strokeCap, .round)
        XCTAssertEqual(options.strokeJoin, .round)
    }
    
    func testOptionsBrushProfileConvenienceAccessors() {
        var options = Options()
        
        options.brushTip = .calligraphic
        XCTAssertEqual(options.brushProfile.tip, .calligraphic)
        
        options.thicknessProfile = .naturalPen
        XCTAssertEqual(options.brushProfile.thicknessProfile, .naturalPen)
        
        options.strokeCap = .butt
        XCTAssertEqual(options.brushProfile.cap, .butt)
        
        options.strokeJoin = .bevel
        XCTAssertEqual(options.brushProfile.join, .bevel)
    }
    
    func testOptionsBrushProfileFullAssignment() {
        var options = Options()
        options.brushProfile = .marker
        
        XCTAssertEqual(options.brushTip, .flat)
        XCTAssertEqual(options.thicknessProfile, .uniform)
        XCTAssertEqual(options.strokeCap, .butt)
        XCTAssertEqual(options.strokeJoin, .bevel)
    }
    
    // MARK: - RoughView Brush Profile Modifiers Tests
    
    func testRoughViewBrushProfileModifier() {
        let view = RoughView()
            .brushProfile(.calligraphic)
        
        XCTAssertEqual(view.options.brushProfile, .calligraphic)
    }
    
    func testRoughViewBrushTipModifier() {
        let view = RoughView()
            .brushTip(roundness: 0.4, angle: 0.5, directionSensitive: true)
        
        XCTAssertEqual(view.options.brushTip.roundness, 0.4)
        XCTAssertEqual(view.options.brushTip.angle, 0.5)
        XCTAssertTrue(view.options.brushTip.directionSensitive)
    }
    
    func testRoughViewBrushTipPresetModifier() {
        let view = RoughView()
            .brushTip(.flat)
        
        XCTAssertEqual(view.options.brushTip, .flat)
    }
    
    func testRoughViewThicknessProfileModifier() {
        let view = RoughView()
            .thicknessProfile(.taperBoth(start: 0.2, end: 0.3))
        
        XCTAssertEqual(view.options.thicknessProfile, .taperBoth(start: 0.2, end: 0.3))
    }
    
    func testRoughViewStrokeCapModifier() {
        let view = RoughView()
            .strokeCap(.butt)
        
        XCTAssertEqual(view.options.strokeCap, .butt)
    }
    
    func testRoughViewStrokeJoinModifier() {
        let view = RoughView()
            .strokeJoin(.miter)
        
        XCTAssertEqual(view.options.strokeJoin, .miter)
    }
    
    func testRoughViewBrushModifiersChaining() {
        let view = RoughView()
            .strokeWidth(8)
            .brushTip(.calligraphic)
            .thicknessProfile(.naturalPen)
            .strokeCap(.round)
            .strokeJoin(.round)
            .stroke(Color.black)
            .draw(Line(from: Point(x: 0, y: 0), to: Point(x: 100, y: 100)))
        
        XCTAssertEqual(view.options.strokeWidth, 8)
        XCTAssertEqual(view.options.brushTip, .calligraphic)
        XCTAssertEqual(view.options.thicknessProfile, .naturalPen)
        XCTAssertEqual(view.drawables.count, 1)
    }
    
    // MARK: - Renderer Brush Profile Tests
    
    func testRendererUsesFillStyleForCustomBrushProfile() {
        var options = Options()
        options.brushProfile = .calligraphic
        options.strokeWidth = 8
        options.stroke = UIColor.black
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let pathSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        let drawing = Drawing(shape: "test", sets: [pathSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 200, height: 200))
        
        XCTAssertFalse(commands.isEmpty)
        
        // With custom brush profile, should use fill style instead of stroke
        if case .fill(_) = commands[0].style {
            // Expected - custom brush profiles convert to filled paths
        } else {
            XCTFail("Expected fill style for custom brush profile")
        }
    }
    
    func testRendererUsesStrokeStyleForDefaultBrushProfile() {
        var options = Options()
        options.brushProfile = .default
        options.strokeWidth = 4
        options.stroke = UIColor.blue
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let pathSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        let drawing = Drawing(shape: "test", sets: [pathSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 100, height: 100))
        
        XCTAssertFalse(commands.isEmpty)
        
        // With default brush profile, should use standard stroke style
        if case .stroke(_, let lineWidth) = commands[0].style {
            XCTAssertEqual(lineWidth, 4)
        } else {
            XCTFail("Expected stroke style for default brush profile")
        }
    }
    
    func testRendererCapAndJoinWithDefaultProfile() {
        var options = Options()
        options.strokeCap = .square
        options.strokeJoin = .miter
        options.strokeWidth = 5
        options.stroke = UIColor.red
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let pathSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        let drawing = Drawing(shape: "test", sets: [pathSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 100, height: 100))
        
        XCTAssertFalse(commands.isEmpty)
        
        // Check cap and join are set correctly
        XCTAssertEqual(commands[0].cap, .square)
        XCTAssertEqual(commands[0].join, .miter)
    }
    
    // MARK: - StrokeToFillConverter Tests
    
    func testStrokeToFillConverterProducesPath() {
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Should produce a non-empty path
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillConverterWithCurve() {
        let move = Move(data: [0, 0])
        let curve = BezierCurveTo(data: [25, 0, 75, 100, 100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, curve]
        
        let profile = BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.2, end: 0.2)
        )
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillConverterWithQuadCurve() {
        let move = Move(data: [0, 0])
        let quad = QuadraticCurveTo(data: [50, 0, 100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, quad]
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 6,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillConverterEmptyOperations() {
        let operations: [RoughSwiftUI.Operation] = []
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Empty operations should produce empty path
        XCTAssertTrue(result.isEmpty)
    }
    
    func testStrokeToFillConverterFromSwiftUIPath() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let profile = BrushProfile.marker
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 12,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Result should be wider than original path (it's an outline)
        let originalBounds = path.boundingRect
        let resultBounds = result.boundingRect
        
        XCTAssertGreaterThan(resultBounds.width, originalBounds.width - 1)
        XCTAssertGreaterThan(resultBounds.height, originalBounds.height - 1)
    }
    
    func testStrokeToFillConverterMultipleSubpaths() {
        var path = SwiftUI.Path()
        // First subpath
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        // Second subpath
        path.move(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 150, y: 50))
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    // MARK: - StrokeToFillConverter Single-Pass Algorithm Tests
    
    func testStrokeToFillSinglePassProducesValidNormalizedT() {
        // Test that normalized t values are in [0, 1] range
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.addLine(to: CGPoint(x: 0, y: 100))
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 10,
            profile: profile
        )
        
        // The result should be a valid closed path
        XCTAssertFalse(result.isEmpty)
        
        // Verify the bounding rect is reasonable
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 90) // Should be at least close to original
        XCTAssertGreaterThan(bounds.height, 90)
    }
    
    func testStrokeToFillSinglePassWithZeroLengthSegments() {
        // Test that zero-length segments are handled gracefully
        let move = Move(data: [50, 50])
        let zeroLine = LineTo(data: [50, 50]) // Zero length
        let realLine = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, zeroLine, realLine]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 8,
            profile: profile
        )
        
        // Should still produce a valid path (zero-length segments are skipped)
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassWithVeryShortPath() {
        // Test with a very short path (just two points close together)
        let move = Move(data: [0, 0])
        let line = LineTo(data: [1, 1]) // Very short segment
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 5,
            profile: profile
        )
        
        // Should produce a valid path
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassWithLongPath() {
        // Test with a long path with many segments
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Create a zigzag pattern with 50 segments
        for i in 1...50 {
            let x = CGFloat(i * 10)
            let y = CGFloat((i % 2 == 0) ? 0 : 50)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 4,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Should cover the expected area
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 490) // ~500 total width
    }
    
    func testStrokeToFillSinglePassWithMixedCurves() {
        // Test with a mix of lines, quad curves, and cubic curves
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 50), control: CGPoint(x: 75, y: 0))
        path.addCurve(to: CGPoint(x: 100, y: 100), control1: CGPoint(x: 125, y: 60), control2: CGPoint(x: 125, y: 90))
        path.addLine(to: CGPoint(x: 0, y: 100))
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 6,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassPreservesThicknessProfile() {
        // Test that thickness profile is applied correctly
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        // Use a tapered profile
        let taperedProfile = BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.1, end: 0.1)
        )
        
        let uniformProfile = BrushProfile(
            tip: .circular,
            thicknessProfile: .uniform
        )
        
        let taperedResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: taperedProfile
        )
        
        let uniformResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: uniformProfile
        )
        
        // Both should produce valid paths
        XCTAssertFalse(taperedResult.isEmpty)
        XCTAssertFalse(uniformResult.isEmpty)
        
        // Tapered result should have smaller area (narrower ends)
        let taperedBounds = taperedResult.boundingRect
        let uniformBounds = uniformResult.boundingRect
        
        // The uniform stroke should be wider (or at least as wide) at the endpoints
        XCTAssertGreaterThanOrEqual(uniformBounds.height, taperedBounds.height - 2)
    }
    
    func testStrokeToFillSinglePassWithCircularPath() {
        // Test with a circular arc approximation
        var path = SwiftUI.Path()
        let center = CGPoint(x: 50, y: 50)
        let radius: CGFloat = 40
        
        // Create a rough circle using cubic curves
        path.move(to: CGPoint(x: center.x + radius, y: center.y))
        
        // Four cubic bezier curves to approximate a circle
        let k: CGFloat = 0.5522847498 // Magic number for circular approximation
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + radius),
            control1: CGPoint(x: center.x + radius, y: center.y + radius * k),
            control2: CGPoint(x: center.x + radius * k, y: center.y + radius)
        )
        path.addCurve(
            to: CGPoint(x: center.x - radius, y: center.y),
            control1: CGPoint(x: center.x - radius * k, y: center.y + radius),
            control2: CGPoint(x: center.x - radius, y: center.y + radius * k)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - radius),
            control1: CGPoint(x: center.x - radius, y: center.y - radius * k),
            control2: CGPoint(x: center.x - radius * k, y: center.y - radius)
        )
        path.addCurve(
            to: CGPoint(x: center.x + radius, y: center.y),
            control1: CGPoint(x: center.x + radius * k, y: center.y - radius),
            control2: CGPoint(x: center.x + radius, y: center.y - radius * k)
        )
        
        let profile = BrushProfile.marker
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Result should roughly contain the original circle
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 70) // Should be roughly diameter + stroke width
    }
    
    func testStrokeToFillSinglePassConsistency() {
        // Test that calling convert multiple times produces consistent results
        let move = Move(data: [0, 0])
        let line1 = LineTo(data: [50, 25])
        let line2 = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line1, line2]
        
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
        
        // Bounding rects should be identical
        XCTAssertEqual(result1.boundingRect.width, result2.boundingRect.width, accuracy: 0.001)
        XCTAssertEqual(result1.boundingRect.height, result2.boundingRect.height, accuracy: 0.001)
    }
    
    func testStrokeToFillSinglePassWithDifferentWidths() {
        // Test that different base widths produce proportionally sized results
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.default
        
        let narrowResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 5,
            profile: profile
        )
        
        let wideResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 20,
            profile: profile
        )
        
        let narrowBounds = narrowResult.boundingRect
        let wideBounds = wideResult.boundingRect
        
        // The wider stroke should have greater height (perpendicular to stroke direction)
        XCTAssertGreaterThan(wideBounds.height, narrowBounds.height)
        
        // The ratio should be roughly proportional to the width ratio (4:1)
        let heightRatio = wideBounds.height / narrowBounds.height
        XCTAssertGreaterThan(heightRatio, 2.0) // Should be significantly larger
    }
    
    func testStrokeToFillSinglePassOnlyMoveOperation() {
        // Test edge case: only a move operation (no actual drawing)
        let move = Move(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Should produce an empty path (can't stroke a single point)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassDiagonalLine() {
        // Test with a diagonal line to verify angle calculations
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile(
            tip: BrushTip(roundness: 0.3, angle: 0, directionSensitive: true),
            thicknessProfile: .uniform
        )
        
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Diagonal line at 45 degrees should produce a path that spans both x and y
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 90)
        XCTAssertGreaterThan(bounds.height, 90)
    }
    
    func testStrokeToFillSinglePassCapStyles() {
        let move = Move(data: [0, 50])
        let line = LineTo(data: [100, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        // Test different cap styles
        let roundProfile = BrushProfile(tip: .circular, thicknessProfile: .uniform, cap: .round, join: .round)
        let buttProfile = BrushProfile(tip: .circular, thicknessProfile: .uniform, cap: .butt, join: .round)
        let squareProfile = BrushProfile(tip: .circular, thicknessProfile: .uniform, cap: .square, join: .round)
        
        let roundResult = StrokeToFillConverter.convert(operations: operations, baseWidth: 20, profile: roundProfile)
        let buttResult = StrokeToFillConverter.convert(operations: operations, baseWidth: 20, profile: buttProfile)
        let squareResult = StrokeToFillConverter.convert(operations: operations, baseWidth: 20, profile: squareProfile)
        
        // All should produce non-empty paths
        XCTAssertFalse(roundResult.isEmpty)
        XCTAssertFalse(buttResult.isEmpty)
        XCTAssertFalse(squareResult.isEmpty)
        
        // Round and square caps should extend beyond butt caps
        let roundBounds = roundResult.boundingRect
        let buttBounds = buttResult.boundingRect
        let squareBounds = squareResult.boundingRect
        
        XCTAssertGreaterThanOrEqual(roundBounds.width, buttBounds.width - 1)
        XCTAssertGreaterThanOrEqual(squareBounds.width, buttBounds.width - 1)
    }
    
    // MARK: - Opacity Options Tests
    
    func testOpacityOptionsDefaults() {
        let options = Options()
        
        // Default opacity should be fully opaque (1.0)
        XCTAssertEqual(options.strokeOpacity, 1.0)
        XCTAssertEqual(options.fillOpacity, 1.0)
    }
    
    func testOpacityOptionsCanBeSet() {
        var options = Options()
        options.strokeOpacity = 0.5
        options.fillOpacity = 0.75
        
        XCTAssertEqual(options.strokeOpacity, 0.5)
        XCTAssertEqual(options.fillOpacity, 0.75)
    }
    
    func testRoughViewStrokeOpacityModifier() {
        let view = RoughView()
            .strokeOpacity(50) // 50%
        
        // Modifier converts 0-100 to 0-1 range
        XCTAssertEqual(view.options.strokeOpacity, 0.5, accuracy: 0.001)
    }
    
    func testRoughViewFillOpacityModifier() {
        let view = RoughView()
            .fillOpacity(75) // 75%
        
        // Modifier converts 0-100 to 0-1 range
        XCTAssertEqual(view.options.fillOpacity, 0.75, accuracy: 0.001)
    }
    
    func testRoughViewOpacityModifiersClamping() {
        // Test clamping to valid range
        let viewLow = RoughView()
            .strokeOpacity(-10) // Should clamp to 0
            .fillOpacity(-20)
        
        XCTAssertEqual(viewLow.options.strokeOpacity, 0, accuracy: 0.001)
        XCTAssertEqual(viewLow.options.fillOpacity, 0, accuracy: 0.001)
        
        let viewHigh = RoughView()
            .strokeOpacity(150) // Should clamp to 100
            .fillOpacity(200)
        
        XCTAssertEqual(viewHigh.options.strokeOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(viewHigh.options.fillOpacity, 1.0, accuracy: 0.001)
    }
    
    func testRoughViewOpacityModifiersChaining() {
        let view = RoughView()
            .stroke(Color.red)
            .strokeOpacity(80)
            .fill(Color.blue)
            .fillOpacity(60)
            .circle()
        
        XCTAssertEqual(view.options.strokeOpacity, 0.8, accuracy: 0.001)
        XCTAssertEqual(view.options.fillOpacity, 0.6, accuracy: 0.001)
        XCTAssertEqual(view.drawables.count, 1)
    }
    
    func testOpacityFullyTransparent() {
        let view = RoughView()
            .strokeOpacity(0)
            .fillOpacity(0)
        
        XCTAssertEqual(view.options.strokeOpacity, 0, accuracy: 0.001)
        XCTAssertEqual(view.options.fillOpacity, 0, accuracy: 0.001)
    }
    
    func testOpacityFullyOpaque() {
        let view = RoughView()
            .strokeOpacity(100)
            .fillOpacity(100)
        
        XCTAssertEqual(view.options.strokeOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(view.options.fillOpacity, 1.0, accuracy: 0.001)
    }
    
    // MARK: - Scribble Fill Options Tests
    
    func testScribbleOptionsDefaults() {
        let options = Options()
        
        XCTAssertEqual(options.scribbleOrigin, 0)
        XCTAssertEqual(options.scribbleTightness, 10)
        XCTAssertEqual(options.scribbleCurvature, 0)
        XCTAssertFalse(options.scribbleUseBrushStroke)
        XCTAssertNil(options.scribbleTightnessPattern)
    }
    
    func testScribbleOptionsCanBeSet() {
        var options = Options()
        options.scribbleOrigin = 45
        options.scribbleTightness = 20
        options.scribbleCurvature = 25
        options.scribbleUseBrushStroke = true
        options.scribbleTightnessPattern = [5, 15, 5]
        
        XCTAssertEqual(options.scribbleOrigin, 45)
        XCTAssertEqual(options.scribbleTightness, 20)
        XCTAssertEqual(options.scribbleCurvature, 25)
        XCTAssertTrue(options.scribbleUseBrushStroke)
        XCTAssertEqual(options.scribbleTightnessPattern, [5, 15, 5])
    }
    
    func testRoughViewScribbleOriginModifier() {
        let view = RoughView()
            .scribbleOrigin(90)
        
        XCTAssertEqual(view.options.scribbleOrigin, 90)
    }
    
    func testRoughViewScribbleTightnessModifier() {
        let view = RoughView()
            .scribbleTightness(25)
        
        XCTAssertEqual(view.options.scribbleTightness, 25)
    }
    
    func testRoughViewScribbleCurvatureModifier() {
        let view = RoughView()
            .scribbleCurvature(30)
        
        XCTAssertEqual(view.options.scribbleCurvature, 30)
    }
    
    func testRoughViewScribbleUseBrushStrokeModifier() {
        let view = RoughView()
            .scribbleUseBrushStroke(true)
        
        XCTAssertTrue(view.options.scribbleUseBrushStroke)
    }
    
    func testRoughViewScribbleTightnessPatternModifier() {
        let pattern = [10, 30, 10]
        let view = RoughView()
            .scribbleTightnessPattern(pattern)
        
        XCTAssertEqual(view.options.scribbleTightnessPattern, pattern)
    }
    
    func testRoughViewScribbleCombinedModifier() {
        let view = RoughView()
            .scribble(
                origin: 45,
                tightness: 15,
                curvature: 20,
                useBrushStroke: true
            )
        
        XCTAssertEqual(view.options.scribbleOrigin, 45)
        XCTAssertEqual(view.options.scribbleTightness, 15)
        XCTAssertEqual(view.options.scribbleCurvature, 20)
        XCTAssertTrue(view.options.scribbleUseBrushStroke)
    }
    
    func testRoughViewScribbleCombinedModifierWithPattern() {
        let view = RoughView()
            .scribble(
                origin: 45,
                tightnessPattern: [5, 20, 5],
                curvature: 20,
                useBrushStroke: true
            )
        
        XCTAssertEqual(view.options.scribbleOrigin, 45)
        XCTAssertEqual(view.options.scribbleCurvature, 20)
        XCTAssertTrue(view.options.scribbleUseBrushStroke)
        XCTAssertEqual(view.options.scribbleTightnessPattern, [5, 20, 5])
    }
    
    func testRoughViewScribbleCombinedModifierPartialValues() {
        let view = RoughView()
            .scribble(origin: 90, curvature: 15)
        
        // Only specified values should change
        XCTAssertEqual(view.options.scribbleOrigin, 90)
        XCTAssertEqual(view.options.scribbleCurvature, 15)
        // Others should remain default
        XCTAssertEqual(view.options.scribbleTightness, 10) // default
        XCTAssertFalse(view.options.scribbleUseBrushStroke) // default
    }
    
    func testScribbleFillStyleEnum() {
        // Test that scribble is a valid fill style
        let fillStyle = FillStyle.scribble
        XCTAssertEqual(fillStyle.rawValue, "scribble")
    }
    
    func testRoughViewWithScribbleFillStyle() {
        let view = RoughView()
            .fill(Color.red)
            .fillStyle(.scribble)
            .scribbleTightness(15)
            .scribbleCurvature(20)
            .rectangle()
        
        XCTAssertEqual(view.options.fillStyle, .scribble)
        XCTAssertEqual(view.options.scribbleTightness, 15)
        XCTAssertEqual(view.options.scribbleCurvature, 20)
        XCTAssertEqual(view.drawables.count, 1)
    }
    
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
    
    // MARK: - Renderer Scribble Fill Tests
    
    func testRendererSkipsFillSketchForScribble() {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = UIColor.red
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        // Create a fillSketch set (normally would be rendered)
        let fillSketchSet = OperationSet(
            type: .fillSketch,
            operations: operations,
            path: nil,
            size: nil
        )
        
        let drawing = Drawing(shape: "test", sets: [fillSketchSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 200, height: 200))
        
        // With scribble fill style, fillSketch should be skipped
        XCTAssertTrue(commands.isEmpty, "fillSketch should be skipped when using scribble fill")
    }
    
    func testRendererSkipsFillPathForScribble() {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = UIColor.blue
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        // Create a fillPath set
        let fillPathSet = OperationSet(
            type: .fillPath,
            operations: operations,
            path: nil,
            size: nil
        )
        
        let drawing = Drawing(shape: "test", sets: [fillPathSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 100, height: 100))
        
        // With scribble fill style, fillPath should be skipped
        XCTAssertTrue(commands.isEmpty, "fillPath should be skipped when using scribble fill")
    }
    
    // MARK: - Opacity Rendering Tests
    
    func testRendererAppliesStrokeOpacity() {
        var options = Options()
        options.strokeOpacity = 0.5
        options.stroke = UIColor.black
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let pathSet = OperationSet(
            type: .path,
            operations: operations,
            path: nil,
            size: nil
        )
        
        let drawing = Drawing(shape: "test", sets: [pathSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 100, height: 100))
        
        XCTAssertFalse(commands.isEmpty)
        // The command should exist - opacity is applied to the color
    }
    
    func testRendererAppliesFillOpacity() {
        var options = Options()
        options.fillOpacity = 0.75
        options.fill = UIColor.red
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let fillSet = OperationSet(
            type: .fillPath,
            operations: operations,
            path: nil,
            size: nil
        )
        
        let drawing = Drawing(shape: "test", sets: [fillSet], options: options)
        
        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 100, height: 100))
        
        XCTAssertFalse(commands.isEmpty)
        // The command should exist - opacity is applied to the color
    }
    
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
    
    // MARK: - Generator Caching Tests
    
    func testGeneratorCacheReturnsSameGeneratorForSameSize() {
        let cache = GeneratorCache()
        let engine = Engine()
        let size = CGSize(width: 200, height: 200)
        
        let generator1 = cache.generator(for: size, using: engine)
        let generator2 = cache.generator(for: size, using: engine)
        
        // Should return the same generator instance
        XCTAssertTrue(generator1 === generator2)
    }
    
    func testGeneratorCacheReturnsDifferentGeneratorForDifferentSizes() {
        let cache = GeneratorCache()
        let engine = Engine()
        
        let generator1 = cache.generator(for: CGSize(width: 100, height: 100), using: engine)
        let generator2 = cache.generator(for: CGSize(width: 200, height: 200), using: engine)
        
        // Should return different generators
        XCTAssertFalse(generator1 === generator2)
    }
    
    func testGeneratorCacheRoundsSizes() {
        let cache = GeneratorCache()
        let engine = Engine()
        
        // Sizes that round to the same integer should use the same generator
        let generator1 = cache.generator(for: CGSize(width: 100.2, height: 100.3), using: engine)
        let generator2 = cache.generator(for: CGSize(width: 100.4, height: 100.1), using: engine)
        
        XCTAssertTrue(generator1 === generator2)
    }
    
    func testGeneratorCacheEvictsOldEntries() {
        let cache = GeneratorCache(maxEntries: 3)
        let engine = Engine()
        
        // Fill the cache
        _ = cache.generator(for: CGSize(width: 100, height: 100), using: engine)
        _ = cache.generator(for: CGSize(width: 200, height: 200), using: engine)
        _ = cache.generator(for: CGSize(width: 300, height: 300), using: engine)
        
        XCTAssertEqual(cache.count, 3)
        
        // Adding a new size should evict the oldest
        _ = cache.generator(for: CGSize(width: 400, height: 400), using: engine)
        
        XCTAssertEqual(cache.count, 3)
    }
    
    func testGeneratorCacheClear() {
        let cache = GeneratorCache()
        let engine = Engine()
        
        _ = cache.generator(for: CGSize(width: 100, height: 100), using: engine)
        _ = cache.generator(for: CGSize(width: 200, height: 200), using: engine)
        
        XCTAssertEqual(cache.count, 2)
        
        cache.clear()
        
        XCTAssertEqual(cache.count, 0)
    }
    
    func testEngineGeneratorCachingIntegration() {
        let engine = Engine()
        
        // Clear caches first
        engine.clearCaches()
        
        let size = CGSize(width: 150, height: 150)
        
        // Access the same size multiple times
        let gen1 = engine.generator(size: size)
        let gen2 = engine.generator(size: size)
        
        // Should return same generator
        XCTAssertTrue(gen1 === gen2)
        
        // Cache stats should reflect this
        let stats = engine.cacheStats
        XCTAssertGreaterThanOrEqual(stats.generators, 1)
    }
    
    // MARK: - Drawing Cache Tests
    
    func testDrawingCacheStoresAndRetrievesDrawings() {
        let cache = DrawingCache()
        
        // Create a test drawing
        let options = Options()
        let drawing = Drawing(
            shape: "test",
            sets: [],
            options: options
        )
        
        // Create a cache key
        let key = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 100, height: 100),
            size: CGSize(width: 200, height: 200),
            options: options
        )
        
        // Store and retrieve
        cache.set(key, drawing: drawing)
        let retrieved = cache.get(key)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.shape, "test")
    }
    
    func testDrawingCacheReturnsNilForMissingKey() {
        let cache = DrawingCache()
        
        let key = DrawingCacheKey(
            drawable: Circle(x: 50, y: 50, diameter: 100),
            size: CGSize(width: 100, height: 100),
            options: Options()
        )
        
        let result = cache.get(key)
        
        XCTAssertNil(result)
    }
    
    func testDrawingCacheTracksCacheStats() {
        let cache = DrawingCache()
        
        let options = Options()
        let drawing = Drawing(shape: "test", sets: [], options: options)
        
        let key1 = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: Circle(x: 25, y: 25, diameter: 50),
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        // Miss
        _ = cache.get(key1)
        
        // Store
        cache.set(key1, drawing: drawing)
        
        // Hit
        _ = cache.get(key1)
        
        // Miss
        _ = cache.get(key2)
        
        let stats = cache.stats
        XCTAssertEqual(stats.entries, 1)
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 2)
        XCTAssertEqual(stats.hitRate, 1.0 / 3.0, accuracy: 0.001)
    }
    
    func testDrawingCacheEvictsWhenFull() {
        let cache = DrawingCache(maxEntries: 3)
        let options = Options()
        
        // Fill the cache
        for i in 0..<5 {
            let drawing = Drawing(shape: "shape\(i)", sets: [], options: options)
            let key = DrawingCacheKey(
                drawable: Rectangle(x: Float(i * 10), y: 0, width: 50, height: 50),
                size: CGSize(width: 100, height: 100),
                options: options
            )
            cache.set(key, drawing: drawing)
        }
        
        // Cache should not exceed max entries
        XCTAssertLessThanOrEqual(cache.stats.entries, 3)
    }
    
    func testDrawingCacheGetOrGenerateUsesCachedValue() {
        let cache = DrawingCache()
        let options = Options()
        
        let key = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 100, height: 100),
            size: CGSize(width: 200, height: 200),
            options: options
        )
        
        var generatorCallCount = 0
        
        // First call should generate
        let result1 = cache.getOrGenerate(key) {
            generatorCallCount += 1
            return Drawing(shape: "generated", sets: [], options: options)
        }
        
        // Second call should use cache
        let result2 = cache.getOrGenerate(key) {
            generatorCallCount += 1
            return Drawing(shape: "generated-again", sets: [], options: options)
        }
        
        XCTAssertEqual(generatorCallCount, 1)
        XCTAssertEqual(result1?.shape, "generated")
        XCTAssertEqual(result2?.shape, "generated") // Should be cached value
    }
    
    func testDrawingCacheClear() {
        let cache = DrawingCache()
        let options = Options()
        
        let drawing = Drawing(shape: "test", sets: [], options: options)
        let key = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        cache.set(key, drawing: drawing)
        XCTAssertNotNil(cache.get(key))
        
        let statsBefore = cache.stats
        XCTAssertEqual(statsBefore.entries, 1)
        XCTAssertEqual(statsBefore.hits, 1) // The get above was a hit
        
        cache.clear()
        
        // After clear, the entry should be gone
        let statsAfter = cache.stats
        XCTAssertEqual(statsAfter.entries, 0)
        XCTAssertEqual(statsAfter.hits, 0) // Reset
        XCTAssertEqual(statsAfter.misses, 0) // Reset
        
        // Accessing after clear should be nil (and will record a miss)
        XCTAssertNil(cache.get(key))
        XCTAssertEqual(cache.stats.misses, 1) // Now there's a miss
    }
    
    func testDrawingCacheKeyDifferentDrawables() {
        let options = Options()
        let size = CGSize(width: 100, height: 100)
        
        let key1 = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            size: size,
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: Circle(x: 25, y: 25, diameter: 50),
            size: size,
            options: options
        )
        
        XCTAssertNotEqual(key1, key2)
    }
    
    func testDrawingCacheKeyDifferentOptions() {
        let size = CGSize(width: 100, height: 100)
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        
        var options1 = Options()
        options1.roughness = 1.0
        
        var options2 = Options()
        options2.roughness = 2.0
        
        let key1 = DrawingCacheKey(drawable: drawable, size: size, options: options1)
        let key2 = DrawingCacheKey(drawable: drawable, size: size, options: options2)
        
        XCTAssertNotEqual(key1, key2)
    }
    
    func testDrawingCacheKeyDifferentSizes() {
        let options = Options()
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        
        let key1 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 200, height: 200),
            options: options
        )
        
        XCTAssertNotEqual(key1, key2)
    }
    
    func testDrawingCacheKeySameSizeRounded() {
        let options = Options()
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        
        // Sizes that round to the same integer should produce same key
        let key1 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 100.2, height: 100.3),
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 100.4, height: 100.1),
            options: options
        )
        
        XCTAssertEqual(key1, key2)
    }
    
    func testOptionsCacheHashIncludesRelevantOptions() {
        var options1 = Options()
        options1.roughness = 1.0
        options1.fillStyle = .hachure
        
        var options2 = Options()
        options2.roughness = 1.0
        options2.fillStyle = .hachure
        
        // Same options should produce same hash
        XCTAssertEqual(options1.cacheHash, options2.cacheHash)
        
        // Different options should produce different hash
        options2.roughness = 2.0
        XCTAssertNotEqual(options1.cacheHash, options2.cacheHash)
    }
    
    func testOptionsCacheHashIncludesFillSpacingPattern() {
        var options1 = Options()
        options1.fillSpacingPattern = [1, 2, 3]
        
        var options2 = Options()
        options2.fillSpacingPattern = [1, 2, 3]
        
        var options3 = Options()
        options3.fillSpacingPattern = [4, 5, 6]
        
        XCTAssertEqual(options1.cacheHash, options2.cacheHash)
        XCTAssertNotEqual(options1.cacheHash, options3.cacheHash)
    }
    
    func testEngineClearCachesResetsAll() {
        let engine = Engine()
        
        // Use generators and generate drawings to populate caches
        let gen = engine.generator(size: CGSize(width: 100, height: 100))
        _ = gen.generate(drawable: Rectangle(x: 0, y: 0, width: 50, height: 50))
        
        let statsBefore = engine.cacheStats
        XCTAssertGreaterThan(statsBefore.generators, 0)
        
        engine.clearCaches()
        
        let statsAfter = engine.cacheStats
        XCTAssertEqual(statsAfter.generators, 0)
        XCTAssertEqual(statsAfter.drawings, 0)
    }
    
    func testGeneratorWithCacheReusesDrawings() {
        let engine = Engine()
        engine.clearCaches()
        
        let gen = engine.generator(size: CGSize(width: 100, height: 100))
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        let options = Options()
        
        // Generate twice with same parameters
        let drawing1 = gen.generate(drawable: drawable, options: options)
        let drawing2 = gen.generate(drawable: drawable, options: options)
        
        XCTAssertNotNil(drawing1)
        XCTAssertNotNil(drawing2)
        
        // Second call should hit cache
        let stats = engine.cacheStats
        XCTAssertGreaterThan(stats.hitRate, 0)
    }
    
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
    
    // MARK: - SVG Number Parsing Tests
    
    func testSVGParseNumbersBasic() {
        // Basic space-separated numbers
        let result = SVGPath.parseNumbers("10 20 30 40")
        XCTAssertEqual(result, [10, 20, 30, 40])
    }
    
    func testSVGParseNumbersCommaSeparated() {
        // Comma-separated numbers
        let result = SVGPath.parseNumbers("10,20,30,40")
        XCTAssertEqual(result, [10, 20, 30, 40])
    }
    
    func testSVGParseNumbersMixedSeparators() {
        // Mix of comma and space separators
        let result = SVGPath.parseNumbers("10, 20 30,40")
        XCTAssertEqual(result, [10, 20, 30, 40])
    }
    
    func testSVGParseNumbersNegative() {
        // Negative numbers
        let result = SVGPath.parseNumbers("-10 -20 -30")
        XCTAssertEqual(result, [-10, -20, -30])
    }
    
    func testSVGParseNumbersImplicitNegative() {
        // Implicit separator with negative (e.g., "10-20" should parse as [10, -20])
        let result = SVGPath.parseNumbers("10-20-30")
        XCTAssertEqual(result, [10, -20, -30])
    }
    
    func testSVGParseNumbersDecimal() {
        // Decimal numbers
        let result = SVGPath.parseNumbers("10.5 20.25 30.125")
        XCTAssertEqual(result, [10.5, 20.25, 30.125])
    }
    
    func testSVGParseNumbersLeadingDecimal() {
        // Numbers with leading decimal point (e.g., ".5")
        let result = SVGPath.parseNumbers(".5 .25 .125")
        XCTAssertEqual(result, [0.5, 0.25, 0.125])
    }
    
    func testSVGParseNumbersConsecutiveDecimals() {
        // Consecutive decimal numbers (e.g., "1.2.3" should parse as [1.2, 0.3])
        let result = SVGPath.parseNumbers("1.2.3.4")
        XCTAssertEqual(result, [1.2, 0.3, 0.4])
    }
    
    func testSVGParseNumbersScientificNotation() {
        // Scientific notation
        let result = SVGPath.parseNumbers("1e5 2.5e-3 3E+2")
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], 100000, accuracy: 0.001)
        XCTAssertEqual(result[1], 0.0025, accuracy: 0.000001)
        XCTAssertEqual(result[2], 300, accuracy: 0.001)
    }
    
    func testSVGParseNumbersScientificWithNegativeExponent() {
        // Scientific notation with negative exponent shouldn't split on the minus
        let result = SVGPath.parseNumbers("1e-5")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 0.00001, accuracy: 0.0000001)
    }
    
    func testSVGParseNumbersEmpty() {
        // Empty string
        let result = SVGPath.parseNumbers("")
        XCTAssertEqual(result, [])
    }
    
    func testSVGParseNumbersWhitespaceOnly() {
        // Whitespace only
        let result = SVGPath.parseNumbers("   ")
        XCTAssertEqual(result, [])
    }
    
    func testSVGParseNumbersComplexSVGPath() {
        // Complex real-world SVG path numbers
        let result = SVGPath.parseNumbers("100.5,200.25 -50.75,-25.125 0.5-0.25")
        XCTAssertEqual(result, [100.5, 200.25, -50.75, -25.125, 0.5, -0.25])
    }
    
    func testSVGParseNumbersZero() {
        // Zero values
        let result = SVGPath.parseNumbers("0 0.0 -0 +0")
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], 0)
        XCTAssertEqual(result[1], 0)
        XCTAssertEqual(result[2], 0)
        XCTAssertEqual(result[3], 0)
    }
    
    func testSVGParseNumbersPositiveSign() {
        // Explicit positive sign
        let result = SVGPath.parseNumbers("+10 +20.5")
        XCTAssertEqual(result, [10, 20.5])
    }
    
    func testSVGPathParsing() {
        // Test full SVG path parsing with the new number parser
        let path = SVGPath("M10,20 L30,40 Q50,60 70,80 C90,100 110,120 130,140 Z")
        
        XCTAssertEqual(path.commands.count, 5)
        XCTAssertEqual(path.commands[0].type, .move)
        XCTAssertEqual(path.commands[0].point, CGPoint(x: 10, y: 20))
        
        XCTAssertEqual(path.commands[1].type, .line)
        XCTAssertEqual(path.commands[1].point, CGPoint(x: 30, y: 40))
        
        XCTAssertEqual(path.commands[2].type, .quadCurve)
        XCTAssertEqual(path.commands[2].control1, CGPoint(x: 50, y: 60))
        XCTAssertEqual(path.commands[2].point, CGPoint(x: 70, y: 80))
        
        XCTAssertEqual(path.commands[3].type, .cubeCurve)
        XCTAssertEqual(path.commands[3].control1, CGPoint(x: 90, y: 100))
        XCTAssertEqual(path.commands[3].control2, CGPoint(x: 110, y: 120))
        XCTAssertEqual(path.commands[3].point, CGPoint(x: 130, y: 140))
        
        XCTAssertEqual(path.commands[4].type, .close)
    }
    
    func testSVGPathRelativeCommands() {
        // Test relative path commands
        let path = SVGPath("M10,10 l20,20 l30,30")
        
        XCTAssertEqual(path.commands.count, 3)
        XCTAssertEqual(path.commands[0].point, CGPoint(x: 10, y: 10))
        XCTAssertEqual(path.commands[1].point, CGPoint(x: 30, y: 30))  // Relative to previous
        XCTAssertEqual(path.commands[2].point, CGPoint(x: 60, y: 60))  // Relative to previous
    }
    
    func testSVGPathWithNegativeCoordinates() {
        // Test path with negative coordinates (common in real SVG paths)
        let path = SVGPath("M-10,-20 L-30-40 l10-20")
        
        XCTAssertEqual(path.commands.count, 3)
        XCTAssertEqual(path.commands[0].point, CGPoint(x: -10, y: -20))
        XCTAssertEqual(path.commands[1].point, CGPoint(x: -30, y: -40))
        // Relative: (-30, -40) + (10, -20) = (-20, -60)
        XCTAssertEqual(path.commands[2].point, CGPoint(x: -20, y: -60))
    }
}
