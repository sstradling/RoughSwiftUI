import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class StrokeToFillTests: XCTestCase {
    // MARK: - StrokeToFillConverter Tests
    
    func testStrokeToFillConverterProducesPath() {
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Should produce a non-empty path
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillConverterWithCurve() {
        let move = Move(data: [0, 0])
        let curve = BezierCurveTo(data: [25, 0, 75, 100, 100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, curve]
        
        let profile = BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.2, end: 0.2)
        )
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillConverterWithQuadCurve() {
        let move = Move(data: [0, 0])
        let quad = QuadraticCurveTo(data: [50, 0, 100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, quad]
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 6,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillConverterEmptyOperations() {
        let operations: [RoughSwiftUI.Operation] = []
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Empty operations should produce empty path
        XCTAssertTrue(result.isEmpty)
    }
    
    func testStrokeToFillConverterFromSwiftUIPath() {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        
        let profile = BrushProfile.marker
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 12,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Result should be wider than original path (it's an outline)
        let originalBounds = path.boundingRect
        let resultBounds = result.boundingRect
        
        XCTAssertGreaterThan(resultBounds.width, originalBounds.width - 1)
        XCTAssertGreaterThan(resultBounds.height, originalBounds.height - 1)
    }
    
    func testStrokeToFillConverterMultipleSubpaths() {
        var path = SwiftUI.Path()
        // First subpath
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 50))
        // Second subpath
        path.move(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 150, y: 50))
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
}
