import XCTest
import SwiftUI
@testable import Sketchy

@MainActor
final class ScribbleFillRendererTests: XCTestCase {
    // MARK: - Renderer Scribble Fill Tests
    
    func testRendererSkipsFillSketchForScribble() {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = UIColor.red
        
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [Sketchy.Operation] = [move, line]
        
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
        let operations: [Sketchy.Operation] = [move, line]
        
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
        options.fill = UIColor.red
        options.stroke = UIColor.black
        options.scribbleTightness = 12

        // Wide enough that extractShapePath keeps the polygon. A near-square
        // non-rectangle is replaced with its bounding ellipse before scribble
        // generation, which would hide the concave clip.
        let operations: [Sketchy.Operation] = [
            Move(data: [20, 40]),
            LineTo(data: [280, 40]),
            LineTo(data: [200, 100]),
            LineTo(data: [280, 160]),
            LineTo(data: [20, 160]),
            LineTo(data: [100, 100]),
            Close()
        ]
        let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
        let drawing = Drawing(shape: "polygon", sets: [pathSet], options: options)

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 300, height: 200))

        XCTAssertFalse(commands.isEmpty, "A polygon scribble should emit fill strokes")
        XCTAssertTrue(
            commands.contains { $0.clipPath != nil },
            "Native polygon scribble fills should be clipped so strokes cannot leak across concave notches"
        )
    }

    func testScribbleFillDoesNotClipSimpleRectangle() {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = UIColor.blue
        options.stroke = UIColor.black
        options.scribbleTightness = 8

        let operations: [Sketchy.Operation] = [
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

        XCTAssertFalse(commands.isEmpty, "A rectangle scribble should emit fill strokes")
        XCTAssertFalse(
            commands.contains { $0.clipPath != nil },
            "Simple rectangles do not need scribble clipping"
        )
    }

    func testGeneratedPolygonScribbleClipKeepsInteriorAndDropsNotch() {
        assertPolygonClipCoversInterior(continuity: .continuous)
        assertPolygonClipCoversInterior(continuity: .legacy)
    }

    private func assertPolygonClipCoversInterior(continuity: StrokeContinuity) {
        var options = Options()
        options.fillStyle = .scribble
        options.fill = UIColor.orange
        options.stroke = UIColor.black
        options.scribbleOrigin = 90
        options.scribbleTightness = 16
        options.seed = 7
        options.strokeContinuity = continuity
        let points = [
            Point(x: 20, y: 40),
            Point(x: 280, y: 40),
            Point(x: 200, y: 100),
            Point(x: 280, y: 160),
            Point(x: 20, y: 160),
            Point(x: 100, y: 100)
        ]
        let size = CGSize(width: 300, height: 200)
        let drawing = NativeGenerator(size: size).generate(
            drawable: Polygon(points: points),
            options: options
        )
        let commands = SwiftUIRenderer().commands(for: drawing!, options: options, in: size)
        let clip = commands.compactMap(\.clipPath).first
        XCTAssertNotNil(clip, "\(continuity) polygon scribble should be clipped")
        // Waist center sits inside the hourglass. The left notch is outside
        // the outline but inside the bounding box, which is where an unclipped
        // vertical scribble leaks.
        XCTAssertTrue(
            clip?.contains(CGPoint(x: 150, y: 100), eoFill: true) == true,
            "\(continuity) clip should cover the polygon interior"
        )
        XCTAssertFalse(
            clip?.contains(CGPoint(x: 40, y: 100), eoFill: true) == true,
            "\(continuity) clip should exclude the concave notch"
        )
    }

    func testScribbleFillDoesNotClipCircleOrEllipse() {
        let shapes = ["circle", "ellipse"]
        for shape in shapes {
            var options = Options()
            options.fillStyle = .scribble
            options.fill = UIColor.orange
            options.stroke = UIColor.black
            options.scribbleTightness = 8

            let operations: [Sketchy.Operation] = [
                Move(data: [20, 40]),
                LineTo(data: [180, 40]),
                LineTo(data: [180, 120]),
                LineTo(data: [20, 120]),
                Close()
            ]
            let pathSet = OperationSet(type: .path, operations: operations, path: nil, size: nil)
            let drawing = Drawing(shape: shape, sets: [pathSet], options: options)

            let renderer = SwiftUIRenderer()
            let commands = renderer.commands(for: drawing, options: options, in: CGSize(width: 200, height: 160))

            XCTAssertFalse(commands.isEmpty, "A \(shape) scribble should emit fill strokes")
            XCTAssertFalse(
                commands.contains { $0.clipPath != nil },
                "Simple \(shape) scribble fills stay unclipped"
            )
        }
    }
    
}
