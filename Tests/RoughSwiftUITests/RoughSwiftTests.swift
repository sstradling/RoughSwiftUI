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
        options.hachureAngle = 60
        options.hachureGap = 8
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
        XCTAssertEqual(drawing.options.hachureAngle, 60)
        XCTAssertEqual(drawing.options.hachureGap, 8)
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
        let commands = renderer.commands(for: drawing, in: size)

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
        let pathCommands = renderer.commands(for: pathDrawing, in: size)
        XCTAssertFalse(pathCommands.isEmpty)

        // Solid fill path
        let fillSet = OperationSet(
            type: .fillPath,
            operations: operations,
            path: nil,
            size: nil
        )
        let fillDrawing = Drawing(shape: "test", sets: [fillSet], options: options)
        let fillCommands = renderer.commands(for: fillDrawing, in: size)
        XCTAssertFalse(fillCommands.isEmpty)

        // Sketch fill
        let sketchSet = OperationSet(
            type: .fillSketch,
            operations: operations,
            path: nil,
            size: nil
        )
        let sketchDrawing = Drawing(shape: "test", sets: [sketchSet], options: options)
        let sketchCommands = renderer.commands(for: sketchDrawing, in: size)
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
        let zeroSizeDrawing = Drawing(shape: "svg", sets: [fillSet], options: options)
        let zeroCommands = renderer.commands(for: zeroSizeDrawing, in: .zero)
        XCTAssertFalse(zeroCommands.isEmpty)

        // Pattern SVG fill with extreme aspect ratio
        let patternSet = OperationSet(
            type: .path2DPattern,
            operations: operations,
            path: svgPath,
            size: nil
        )
        let wideSize = CGSize(width: 1000, height: 10)
        let patternDrawing = Drawing(shape: "svg", sets: [patternSet], options: options)
        let patternCommands = renderer.commands(for: patternDrawing, in: wideSize)
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
        base.hachureAngle = 30
        base.hachureGap = 6
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
        XCTAssertEqual(decoded.hachureAngle, base.hachureAngle)
        XCTAssertEqual(decoded.hachureGap, base.hachureGap)
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
}
