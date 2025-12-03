import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class RendererBrushTests: XCTestCase {
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
    
}
