import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class TextDrawableTests: XCTestCase {
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
    
}
