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
}
