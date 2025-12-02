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
        XCTAssertEqual(set.operations.count, 208)
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
}
