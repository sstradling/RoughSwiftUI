import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class TextPathConverterTests: XCTestCase {
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
    
}
