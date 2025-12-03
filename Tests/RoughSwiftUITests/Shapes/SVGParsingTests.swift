import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SVGParsingTests: XCTestCase {
    // MARK: - SVG Number Parsing Tests
    
    func testSVGParseNumbersBasic() {
        // Basic space-separated numbers
        let result = SVGPath.parseNumbers("10 20 30 40")
        XCTAssertEqual(result, [10, 20, 30, 40])
    }
    
    func testSVGParseNumbersCommaSeparated() {
        // Comma-separated numbers
        let result = SVGPath.parseNumbers("10,20,30,40")
        XCTAssertEqual(result, [10, 20, 30, 40])
    }
    
    func testSVGParseNumbersMixedSeparators() {
        // Mix of comma and space separators
        let result = SVGPath.parseNumbers("10, 20 30,40")
        XCTAssertEqual(result, [10, 20, 30, 40])
    }
    
    func testSVGParseNumbersNegative() {
        // Negative numbers
        let result = SVGPath.parseNumbers("-10 -20 -30")
        XCTAssertEqual(result, [-10, -20, -30])
    }
    
    func testSVGParseNumbersImplicitNegative() {
        // Implicit separator with negative (e.g., "10-20" should parse as [10, -20])
        let result = SVGPath.parseNumbers("10-20-30")
        XCTAssertEqual(result, [10, -20, -30])
    }
    
    func testSVGParseNumbersDecimal() {
        // Decimal numbers
        let result = SVGPath.parseNumbers("10.5 20.25 30.125")
        XCTAssertEqual(result, [10.5, 20.25, 30.125])
    }
    
    func testSVGParseNumbersLeadingDecimal() {
        // Numbers with leading decimal point (e.g., ".5")
        let result = SVGPath.parseNumbers(".5 .25 .125")
        XCTAssertEqual(result, [0.5, 0.25, 0.125])
    }
    
    func testSVGParseNumbersConsecutiveDecimals() {
        // Consecutive decimal numbers (e.g., "1.2.3" should parse as [1.2, 0.3])
        let result = SVGPath.parseNumbers("1.2.3.4")
        XCTAssertEqual(result, [1.2, 0.3, 0.4])
    }
    
    func testSVGParseNumbersScientificNotation() {
        // Scientific notation
        let result = SVGPath.parseNumbers("1e5 2.5e-3 3E+2")
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], 100000, accuracy: 0.001)
        XCTAssertEqual(result[1], 0.0025, accuracy: 0.000001)
        XCTAssertEqual(result[2], 300, accuracy: 0.001)
    }
    
    func testSVGParseNumbersScientificWithNegativeExponent() {
        // Scientific notation with negative exponent shouldn't split on the minus
        let result = SVGPath.parseNumbers("1e-5")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], 0.00001, accuracy: 0.0000001)
    }
    
    func testSVGParseNumbersEmpty() {
        // Empty string
        let result = SVGPath.parseNumbers("")
        XCTAssertEqual(result, [])
    }
    
    func testSVGParseNumbersWhitespaceOnly() {
        // Whitespace only
        let result = SVGPath.parseNumbers("   ")
        XCTAssertEqual(result, [])
    }
    
    func testSVGParseNumbersComplexSVGPath() {
        // Complex real-world SVG path numbers
        let result = SVGPath.parseNumbers("100.5,200.25 -50.75,-25.125 0.5-0.25")
        XCTAssertEqual(result, [100.5, 200.25, -50.75, -25.125, 0.5, -0.25])
    }
    
    func testSVGParseNumbersZero() {
        // Zero values
        let result = SVGPath.parseNumbers("0 0.0 -0 +0")
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0], 0)
        XCTAssertEqual(result[1], 0)
        XCTAssertEqual(result[2], 0)
        XCTAssertEqual(result[3], 0)
    }
    
    func testSVGParseNumbersPositiveSign() {
        // Explicit positive sign
        let result = SVGPath.parseNumbers("+10 +20.5")
        XCTAssertEqual(result, [10, 20.5])
    }
    
    func testSVGPathParsing() {
        // Test full SVG path parsing with the new number parser
        let path = SVGPath("M10,20 L30,40 Q50,60 70,80 C90,100 110,120 130,140 Z")
        
        XCTAssertEqual(path.commands.count, 5)
        XCTAssertEqual(path.commands[0].type, .move)
        XCTAssertEqual(path.commands[0].point, CGPoint(x: 10, y: 20))
        
        XCTAssertEqual(path.commands[1].type, .line)
        XCTAssertEqual(path.commands[1].point, CGPoint(x: 30, y: 40))
        
        XCTAssertEqual(path.commands[2].type, .quadCurve)
        XCTAssertEqual(path.commands[2].control1, CGPoint(x: 50, y: 60))
        XCTAssertEqual(path.commands[2].point, CGPoint(x: 70, y: 80))
        
        XCTAssertEqual(path.commands[3].type, .cubeCurve)
        XCTAssertEqual(path.commands[3].control1, CGPoint(x: 90, y: 100))
        XCTAssertEqual(path.commands[3].control2, CGPoint(x: 110, y: 120))
        XCTAssertEqual(path.commands[3].point, CGPoint(x: 130, y: 140))
        
        XCTAssertEqual(path.commands[4].type, .close)
    }
    
    func testSVGPathRelativeCommands() {
        // Test relative path commands
        let path = SVGPath("M10,10 l20,20 l30,30")
        
        XCTAssertEqual(path.commands.count, 3)
        XCTAssertEqual(path.commands[0].point, CGPoint(x: 10, y: 10))
        XCTAssertEqual(path.commands[1].point, CGPoint(x: 30, y: 30))  // Relative to previous
        XCTAssertEqual(path.commands[2].point, CGPoint(x: 60, y: 60))  // Relative to previous
    }
    
    func testSVGPathWithNegativeCoordinates() {
        // Test path with negative coordinates (common in real SVG paths)
        let path = SVGPath("M-10,-20 L-30-40 l10-20")
        
        XCTAssertEqual(path.commands.count, 3)
        XCTAssertEqual(path.commands[0].point, CGPoint(x: -10, y: -20))
        XCTAssertEqual(path.commands[1].point, CGPoint(x: -30, y: -40))
        // Relative: (-30, -40) + (10, -20) = (-20, -60)
        XCTAssertEqual(path.commands[2].point, CGPoint(x: -20, y: -60))
    }
    
}
