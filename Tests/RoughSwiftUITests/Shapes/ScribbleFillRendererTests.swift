import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class ScribbleFillRendererTests: XCTestCase {
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

    func testScribbleFillClipsNativePolygon() {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = .red
        options.stroke = .black
        options.scribbleTightness = 12

        let operations: [RoughSwiftUI.Operation] = [
            Move(data: [20, 20]),
            LineTo(data: [180, 20]),
            LineTo(data: [120, 90]),
            LineTo(data: [180, 180]),
            LineTo(data: [20, 180]),
            LineTo(data: [80, 90]),
            Close()
        ]
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "polygon", sets: [pathSet], options: options)

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 200, height: 200))

        XCTAssertTrue(
            commands.contains { $0.clipPath != nil },
            "Native polygon scribble fills should be clipped so strokes cannot leak across concave notches"
        )
    }

    func testScribbleFillDoesNotClipSimpleRectangle() {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = .blue
        options.stroke = .black
        options.scribbleTightness = 8

        let operations: [RoughSwiftUI.Operation] = [
            Move(data: [20, 20]),
            LineTo(data: [180, 20]),
            LineTo(data: [180, 180]),
            LineTo(data: [20, 180]),
            Close()
        ]
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "rectangle", sets: [pathSet], options: options)

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 200, height: 200))

        XCTAssertFalse(
            commands.contains { $0.clipPath != nil },
            "Simple rectangles do not need scribble clipping"
        )
    }
    
}
