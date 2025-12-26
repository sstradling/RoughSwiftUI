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
    
    // MARK: - Typographic Size Tests
    
    func testTypographicSizeReturnsPositiveDimensions() {
        let font = UIFont.systemFont(ofSize: 48)
        let size = TextPathConverter.typographicSize(for: "Hello", font: font)
        
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }
    
    func testTypographicSizeWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Test",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 36)]
        )
        let size = TextPathConverter.typographicSize(for: attributed)
        
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
    }
    
    func testTypographicMetricsReturnsAscentAndSize() {
        let font = UIFont.systemFont(ofSize: 48)
        let (size, ascent) = TextPathConverter.typographicMetrics(for: "Ay", font: font)
        
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(ascent, 0, "Ascent should be positive")
        XCTAssertLessThanOrEqual(ascent, size.height, "Ascent should not exceed height")
    }
    
    // MARK: - Path Size And Ascent Tests
    
    func testPathSizeAndAscentReturnsAllComponents() {
        let font = UIFont.systemFont(ofSize: 48)
        let (path, size, ascent, inkOrigin) = TextPathConverter.pathSizeAndAscent(for: "Hello", font: font)
        
        // Path should not be empty
        XCTAssertFalse(path.isEmpty)
        
        // Size should have positive dimensions
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
        
        // Ascent should be positive
        XCTAssertGreaterThan(ascent, 0)
        
        // Ink origin should match path's bounding box origin
        let bounds = path.boundingBox
        XCTAssertEqual(inkOrigin.x, bounds.minX, accuracy: 0.001)
        XCTAssertEqual(inkOrigin.y, bounds.minY, accuracy: 0.001)
    }
    
    func testPathSizeAndAscentWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Test",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 36)]
        )
        let (path, size, ascent, inkOrigin) = TextPathConverter.pathSizeAndAscent(for: attributed)
        
        XCTAssertFalse(path.isEmpty)
        XCTAssertGreaterThan(size.width, 0)
        XCTAssertGreaterThan(size.height, 0)
        XCTAssertGreaterThan(ascent, 0)
        
        // Ink origin should match path's bounding box origin
        let bounds = path.boundingBox
        XCTAssertEqual(inkOrigin.x, bounds.minX, accuracy: 0.001)
        XCTAssertEqual(inkOrigin.y, bounds.minY, accuracy: 0.001)
    }
    
    func testInkOriginAccountsForSideBearings() {
        // Some fonts have side bearings (space before first glyph)
        let font = UIFont.systemFont(ofSize: 48)
        let (path, _, _, inkOrigin) = TextPathConverter.pathSizeAndAscent(for: "A", font: font)
        
        let bounds = path.boundingBox
        
        // The ink origin should accurately reflect where the glyph starts
        // This may or may not be at x=0 depending on the font's side bearings
        XCTAssertEqual(inkOrigin.x, bounds.minX, accuracy: 0.001)
        XCTAssertEqual(inkOrigin.y, bounds.minY, accuracy: 0.001)
    }
    
    // MARK: - Diagnostic Tests for Path Structure
    
    func testGlyphPathStructureForSystemFont() {
        let font = UIFont.systemFont(ofSize: 48, weight: .bold)
        
        // Analyze 'e' - should have 2 closed contours (outer + inner counter)
        let pathE = TextPathConverter.path(from: "e", font: font)
        let statsE = analyzePathStructure(pathE)
        
        // 'e' should have exactly 2 Move commands (2 contours: outer bowl + inner counter)
        // If it has only 1 Move, it's a single continuous stroke
        XCTAssertEqual(statsE.moveCount, statsE.closeCount, 
            "'e' should have equal moves and closes (each subpath should be closed)")
        
        // Analyze 'd' - should have 2 closed contours (outer + inner counter)
        let pathD = TextPathConverter.path(from: "d", font: font)
        let statsD = analyzePathStructure(pathD)
        
        XCTAssertEqual(statsD.moveCount, statsD.closeCount,
            "'d' should have equal moves and closes (each subpath should be closed)")
    }
    
    private func analyzePathStructure(_ path: CGPath) -> (moveCount: Int, closeCount: Int, lineCount: Int, curveCount: Int) {
        var moveCount = 0
        var closeCount = 0
        var lineCount = 0
        var curveCount = 0
        
        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                moveCount += 1
            case .addLineToPoint:
                lineCount += 1
            case .addQuadCurveToPoint, .addCurveToPoint:
                curveCount += 1
            case .closeSubpath:
                closeCount += 1
            @unknown default:
                break
            }
        }
        
        return (moveCount, closeCount, lineCount, curveCount)
    }
    
}
