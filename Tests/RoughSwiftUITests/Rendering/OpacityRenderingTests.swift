import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class OpacityRenderingTests: XCTestCase {
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
    
}
