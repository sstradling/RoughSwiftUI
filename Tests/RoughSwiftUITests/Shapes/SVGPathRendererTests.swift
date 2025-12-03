import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SVGPathRendererTests: XCTestCase {
    // MARK: SVGPathRenderer Tests
    
    func testSVGPathRendererSimplePath() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 L 100 10 L 100 100 L 10 100 Z"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 8, "Should produce operations for all segments")
    }
    
    func testSVGPathRendererCurvePath() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 C 40 10 60 40 100 100"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 2, "Should produce operations for curve")
    }
    
    func testSVGPathRendererQuadCurve() {
        var options = Options()
        options.roughness = 0.5
        
        let svgPath = "M 10 10 Q 50 100 100 10"
        let ops = SVGPathRenderer.pathOps(svgPath: svgPath, options: options)
        
        XCTAssertGreaterThan(ops.count, 2, "Should produce operations for quad curve")
    }
    
}
