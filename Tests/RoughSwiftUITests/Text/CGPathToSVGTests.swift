import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class CGPathToSVGTests: XCTestCase {
    // MARK: - CGPath to SVG Tests
    
    func testCGPathToSVGSimpleLine() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let svg = path.toSVGPathString()
        
        // Should contain move and line commands
        XCTAssertTrue(svg.contains("M"))
        XCTAssertTrue(svg.contains("L"))
    }
    
    func testCGPathToSVGTriangle() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 100))
        path.closeSubpath()
        
        let svg = path.toSVGPathString()
        
        // Should contain move, lines, and close commands
        XCTAssertTrue(svg.contains("M"))
        XCTAssertTrue(svg.contains("L"))
        XCTAssertTrue(svg.contains("Z"))
    }
    
    func testCGPathToSVGQuadCurve() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 100), control: CGPoint(x: 50, y: 0))
        
        let svg = path.toSVGPathString()
        
        // Should contain quad curve command
        XCTAssertTrue(svg.contains("Q"))
    }
    
    func testCGPathToSVGCubicCurve() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addCurve(to: CGPoint(x: 100, y: 100), control1: CGPoint(x: 25, y: 0), control2: CGPoint(x: 75, y: 100))
        
        let svg = path.toSVGPathString()
        
        // Should contain cubic curve command
        XCTAssertTrue(svg.contains("C"))
    }
    
    func testCGPathToSVGWithPrecision() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 1.23456789, y: 9.87654321))
        
        let svg2 = path.toSVGPathString(precision: 2)
        let svg4 = path.toSVGPathString(precision: 4)
        
        // Different precisions should produce different output
        XCTAssertNotEqual(svg2, svg4)
        
        // Higher precision should result in longer string (more decimal places)
        XCTAssertGreaterThan(svg4.count, svg2.count)
    }
    
    func testCGPathToSVGFlippingY() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let normalSVG = path.toSVGPathString()
        let flippedSVG = path.toSVGPathStringFlippingY()
        
        // Flipped should be different from normal
        XCTAssertNotEqual(normalSVG, flippedSVG)
    }
    
    func testCGPathToSVGWithTransform() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 10, y: 10))
        
        let transform = CGAffineTransform(scaleX: 2, y: 2)
        let scaledSVG = path.toSVGPathString(applying: transform)
        
        // Scaled path should have larger coordinates
        XCTAssertTrue(scaledSVG.contains("20"))
    }
    
    func testCGPathToSVGEmptyPath() {
        let path = CGMutablePath()
        let svg = path.toSVGPathString()
        
        // Empty path should produce empty string
        XCTAssertTrue(svg.isEmpty)
    }
    
}
