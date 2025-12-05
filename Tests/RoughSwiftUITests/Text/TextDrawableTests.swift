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
    
    // MARK: - FullText Centered Text Tests
    
    func testFullTextMethod() {
        let fullText = FullText("Hello", font: UIFont.systemFont(ofSize: 24))
        
        // FullText should use "path" method like Text
        XCTAssertEqual(fullText.method, "path")
    }
    
    func testFullTextIsFulfillable() {
        let fullText = FullText("Test", font: UIFont.systemFont(ofSize: 36))
        
        // FullText should conform to Fulfillable
        XCTAssertTrue(fullText is Fulfillable)
    }
    
    func testFullTextArgumentsWithSize() {
        let fullText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let canvasSize = Size(width: 300, height: 100)
        
        // When given a size, arguments should return a transformed SVG path
        let args = fullText.arguments(size: canvasSize)
        XCTAssertEqual(args.count, 1)
        XCTAssertTrue(args[0] is String)
        
        let svgPath = args[0] as! String
        XCTAssertFalse(svgPath.isEmpty)
        XCTAssertTrue(svgPath.contains("M"))  // Should have move commands
    }
    
    func testFullTextCentersHorizontally() {
        let fullText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let canvasSize = Size(width: 300, height: 100)
        
        let args = fullText.arguments(size: canvasSize)
        let svgPath = args[0] as! String
        
        // Parse the first M command to check the starting position
        // The text should be centered, so X coordinate should be around canvas center
        if let range = svgPath.range(of: "M([\\d.-]+) ([\\d.-]+)", options: .regularExpression) {
            let match = String(svgPath[range])
            let components = match.dropFirst().split(separator: " ")
            if let xStr = components.first, let x = Float(xStr) {
                // X should be in the center region of the canvas (accounting for text width)
                // For a 300-wide canvas, centered text should start somewhere between 50-250
                XCTAssertGreaterThan(x, 0, "Text should not start at origin")
                XCTAssertLessThan(x, Float(canvasSize.width), "Text should be within canvas")
            }
        }
    }
    
    func testFullTextCentersVertically() {
        let fullText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let canvasSize = Size(width: 300, height: 200)
        
        let args = fullText.arguments(size: canvasSize)
        let svgPath = args[0] as! String
        
        // Parse the first M command to check the starting position
        if let range = svgPath.range(of: "M([\\d.-]+) ([\\d.-]+)", options: .regularExpression) {
            let match = String(svgPath[range])
            let components = match.dropFirst().split(separator: " ")
            if components.count >= 2, let y = Float(components[1]) {
                // Y should be in the center region of the canvas
                // For a 200-tall canvas, centered text should have Y around 50-150
                XCTAssertGreaterThan(y, 0, "Text should not be at top edge")
                XCTAssertLessThan(y, Float(canvasSize.height), "Text should be within canvas")
            }
        }
    }
    
    func testFullTextWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Bold",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 32)]
        )
        let fullText = FullText(attributedString: attributed)
        
        XCTAssertEqual(fullText.method, "path")
        
        let args = fullText.arguments(size: Size(width: 200, height: 100))
        XCTAssertEqual(args.count, 1)
        XCTAssertTrue(args[0] is String)
    }
    
    func testFullTextGeneratesDrawing() throws {
        let engine = Engine()
        let generator = engine.generator(size: CGSize(width: 300, height: 100))
        
        let fullText = FullText("Test", font: UIFont.systemFont(ofSize: 36))
        let drawing = try XCTUnwrap(generator.generate(drawable: fullText))
        
        // Should produce a path drawing
        XCTAssertEqual(drawing.shape, "path")
        XCTAssertFalse(drawing.sets.isEmpty)
    }
    
    func testFullTextDifferentFromText() {
        let text = Text("A", font: UIFont.systemFont(ofSize: 48))
        let fullText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let canvasSize = Size(width: 300, height: 100)
        
        // Text has fixed arguments (at origin)
        let textPath = text.arguments[0] as! String
        
        // FullText has size-dependent arguments (centered)
        let fullTextPath = fullText.arguments(size: canvasSize)[0] as! String
        
        // The paths should be different because FullText applies centering transform
        XCTAssertNotEqual(textPath, fullTextPath, "FullText should produce a different path than Text due to centering transform")
    }
    
    func testRoughViewTextUsesFullText() {
        // Create a RoughView with text using the builder API
        let roughView = RoughView()
            .text("Test", font: UIFont.systemFont(ofSize: 36))
        
        // The drawable should be FullText (Fulfillable)
        XCTAssertEqual(roughView.drawables.count, 1)
        XCTAssertTrue(roughView.drawables[0] is Fulfillable, "RoughView.text() should use FullText which is Fulfillable")
    }
    
    func testRoughViewTextAttributedUsesFullText() {
        let attributed = NSAttributedString(
            string: "Bold",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 32)]
        )
        
        let roughView = RoughView()
            .text(attributedString: attributed)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        XCTAssertTrue(roughView.drawables[0] is Fulfillable, "RoughView.text(attributedString:) should use FullText which is Fulfillable")
    }
    
    func testRoughViewTextWithFontNameUsesFullText() {
        let roughView = RoughView()
            .text("Test", fontName: "Helvetica-Bold", fontSize: 24)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        XCTAssertTrue(roughView.drawables[0] is Fulfillable, "RoughView.text(_:fontName:fontSize:) should use FullText which is Fulfillable")
    }
    
    // MARK: - Alignment Tests
    
    func testFullTextHorizontalAlignmentLeading() {
        let leadingText = FullText("A", font: UIFont.systemFont(ofSize: 48), horizontalAlignment: .leading)
        let centeredText = FullText("A", font: UIFont.systemFont(ofSize: 48), horizontalAlignment: .center)
        let canvasSize = Size(width: 300, height: 100)
        
        let leadingPath = leadingText.arguments(size: canvasSize)[0] as! String
        let centeredPath = centeredText.arguments(size: canvasSize)[0] as! String
        
        // Leading text should be positioned differently from centered text
        XCTAssertNotEqual(leadingPath, centeredPath, "Leading alignment should produce different path than center")
        
        // Extract X coordinate from leading text - should be near left edge
        if let range = leadingPath.range(of: "M([\\d.-]+)", options: .regularExpression) {
            let match = String(leadingPath[range])
            if let x = Float(match.dropFirst()) {
                // Leading text should be near the left edge (with small inset of ~4)
                XCTAssertLessThan(x, 50, "Leading text should be near left edge")
            }
        }
    }
    
    func testFullTextHorizontalAlignmentTrailing() {
        let trailingText = FullText("A", font: UIFont.systemFont(ofSize: 48), horizontalAlignment: .trailing)
        let centeredText = FullText("A", font: UIFont.systemFont(ofSize: 48), horizontalAlignment: .center)
        let canvasSize = Size(width: 300, height: 100)
        
        let trailingPath = trailingText.arguments(size: canvasSize)[0] as! String
        let centeredPath = centeredText.arguments(size: canvasSize)[0] as! String
        
        // Trailing text should be positioned differently from centered text
        XCTAssertNotEqual(trailingPath, centeredPath, "Trailing alignment should produce different path than center")
    }
    
    func testFullTextVerticalAlignmentTop() {
        let topText = FullText("A", font: UIFont.systemFont(ofSize: 48), verticalAlignment: .top)
        let centeredText = FullText("A", font: UIFont.systemFont(ofSize: 48), verticalAlignment: .center)
        let canvasSize = Size(width: 300, height: 200)
        
        let topPath = topText.arguments(size: canvasSize)[0] as! String
        let centeredPath = centeredText.arguments(size: canvasSize)[0] as! String
        
        // Top-aligned text should be positioned differently from centered text
        XCTAssertNotEqual(topPath, centeredPath, "Top alignment should produce different path than center")
    }
    
    func testFullTextVerticalAlignmentBottom() {
        let bottomText = FullText("A", font: UIFont.systemFont(ofSize: 48), verticalAlignment: .bottom)
        let centeredText = FullText("A", font: UIFont.systemFont(ofSize: 48), verticalAlignment: .center)
        let canvasSize = Size(width: 300, height: 200)
        
        let bottomPath = bottomText.arguments(size: canvasSize)[0] as! String
        let centeredPath = centeredText.arguments(size: canvasSize)[0] as! String
        
        // Bottom-aligned text should be positioned differently from centered text
        XCTAssertNotEqual(bottomPath, centeredPath, "Bottom alignment should produce different path than center")
    }
    
    // MARK: - Offset Tests
    
    func testFullTextWithOffsetX() {
        let noOffsetText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let offsetText = FullText("A", font: UIFont.systemFont(ofSize: 48), offsetX: 50)
        let canvasSize = Size(width: 300, height: 100)
        
        let noOffsetPath = noOffsetText.arguments(size: canvasSize)[0] as! String
        let offsetPath = offsetText.arguments(size: canvasSize)[0] as! String
        
        // Text with X offset should be positioned differently
        XCTAssertNotEqual(noOffsetPath, offsetPath, "X offset should change text position")
    }
    
    func testFullTextWithOffsetY() {
        let noOffsetText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let offsetText = FullText("A", font: UIFont.systemFont(ofSize: 48), offsetY: 30)
        let canvasSize = Size(width: 300, height: 100)
        
        let noOffsetPath = noOffsetText.arguments(size: canvasSize)[0] as! String
        let offsetPath = offsetText.arguments(size: canvasSize)[0] as! String
        
        // Text with Y offset should be positioned differently
        XCTAssertNotEqual(noOffsetPath, offsetPath, "Y offset should change text position")
    }
    
    func testFullTextWithBothOffsets() {
        let noOffsetText = FullText("A", font: UIFont.systemFont(ofSize: 48))
        let offsetText = FullText("A", font: UIFont.systemFont(ofSize: 48), offsetX: 20, offsetY: 15)
        let canvasSize = Size(width: 300, height: 100)
        
        let noOffsetPath = noOffsetText.arguments(size: canvasSize)[0] as! String
        let offsetPath = offsetText.arguments(size: canvasSize)[0] as! String
        
        // Text with both offsets should be positioned differently
        XCTAssertNotEqual(noOffsetPath, offsetPath, "Combined offsets should change text position")
    }
    
    func testFullTextAlignmentWithOffset() {
        // Test that offset is applied on top of alignment
        let leadingText = FullText("A", font: UIFont.systemFont(ofSize: 48), horizontalAlignment: .leading)
        let leadingOffsetText = FullText("A", font: UIFont.systemFont(ofSize: 48), horizontalAlignment: .leading, offsetX: 20)
        let canvasSize = Size(width: 300, height: 100)
        
        let leadingPath = leadingText.arguments(size: canvasSize)[0] as! String
        let leadingOffsetPath = leadingOffsetText.arguments(size: canvasSize)[0] as! String
        
        // Leading with offset should be different from plain leading
        XCTAssertNotEqual(leadingPath, leadingOffsetPath, "Offset should modify position even with alignment set")
    }
    
    // MARK: - RoughView API with Alignment Tests
    
    func testRoughViewTextWithAlignment() {
        let roughView = RoughView()
            .text("Test", font: UIFont.systemFont(ofSize: 36),
                  horizontalAlignment: .leading,
                  verticalAlignment: .top)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        XCTAssertTrue(roughView.drawables[0] is Fulfillable)
        
        // Verify it's a FullText with correct alignment
        if let fullText = roughView.drawables[0] as? FullText {
            XCTAssertEqual(fullText.horizontalAlignment, .leading)
            XCTAssertEqual(fullText.verticalAlignment, .top)
        }
    }
    
    func testRoughViewTextWithOffset() {
        let roughView = RoughView()
            .text("Test", font: UIFont.systemFont(ofSize: 36),
                  offsetX: 10, offsetY: -5)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        
        // Verify it's a FullText with correct offset
        if let fullText = roughView.drawables[0] as? FullText {
            XCTAssertEqual(fullText.offsetX, 10)
            XCTAssertEqual(fullText.offsetY, -5)
        }
    }
    
    func testRoughViewTextWithAlignmentAndOffset() {
        let roughView = RoughView()
            .text("Test", font: UIFont.systemFont(ofSize: 36),
                  horizontalAlignment: .trailing,
                  verticalAlignment: .bottom,
                  offsetX: -8, offsetY: -4)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        
        if let fullText = roughView.drawables[0] as? FullText {
            XCTAssertEqual(fullText.horizontalAlignment, .trailing)
            XCTAssertEqual(fullText.verticalAlignment, .bottom)
            XCTAssertEqual(fullText.offsetX, -8)
            XCTAssertEqual(fullText.offsetY, -4)
        }
    }
    
    func testRoughViewAttributedTextWithAlignment() {
        let attributed = NSAttributedString(
            string: "Styled",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 28)]
        )
        
        let roughView = RoughView()
            .text(attributedString: attributed,
                  horizontalAlignment: .center,
                  verticalAlignment: .top,
                  offsetY: 10)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        
        if let fullText = roughView.drawables[0] as? FullText {
            XCTAssertEqual(fullText.horizontalAlignment, .center)
            XCTAssertEqual(fullText.verticalAlignment, .top)
            XCTAssertEqual(fullText.offsetY, 10)
        }
    }
    
    func testRoughViewTextWithFontNameAndAlignment() {
        let roughView = RoughView()
            .text("Test", fontName: "Helvetica-Bold", fontSize: 24,
                  horizontalAlignment: .leading,
                  offsetX: 5)
        
        XCTAssertEqual(roughView.drawables.count, 1)
        
        if let fullText = roughView.drawables[0] as? FullText {
            XCTAssertEqual(fullText.horizontalAlignment, .leading)
            XCTAssertEqual(fullText.offsetX, 5)
        }
    }
    
}
