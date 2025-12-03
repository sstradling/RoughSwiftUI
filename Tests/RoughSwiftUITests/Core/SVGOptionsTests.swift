import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SVGOptionsTests: XCTestCase {
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
    
}
