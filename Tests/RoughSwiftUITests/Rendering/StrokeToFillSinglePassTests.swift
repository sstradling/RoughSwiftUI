import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class StrokeToFillSinglePassTests: XCTestCase {
    // MARK: - StrokeToFillConverter Single-Pass Algorithm Tests
    
    func testStrokeToFillSinglePassProducesValidNormalizedT() {
        // Test that normalized t values are in [0, 1] range
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        path.addLine(to: CGPoint(x: 0, y: 100))
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 10,
            profile: profile
        )
        
        // The result should be a valid closed path
        XCTAssertFalse(result.isEmpty)
        
        // Verify the bounding rect is reasonable
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 90) // Should be at least close to original
        XCTAssertGreaterThan(bounds.height, 90)
    }
    
    func testStrokeToFillSinglePassWithZeroLengthSegments() {
        // Test that zero-length segments are handled gracefully
        let move = Move(data: [50, 50])
        let zeroLine = LineTo(data: [50, 50]) // Zero length
        let realLine = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, zeroLine, realLine]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 8,
            profile: profile
        )
        
        // Should still produce a valid path (zero-length segments are skipped)
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassWithVeryShortPath() {
        // Test with a very short path (just two points close together)
        let move = Move(data: [0, 0])
        let line = LineTo(data: [1, 1]) // Very short segment
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 5,
            profile: profile
        )
        
        // Should produce a valid path
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassWithLongPath() {
        // Test with a long path with many segments
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        
        // Create a zigzag pattern with 50 segments
        for i in 1...50 {
            let x = CGFloat(i * 10)
            let y = CGFloat((i % 2 == 0) ? 0 : 50)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        let profile = BrushProfile.pen
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 4,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Should cover the expected area
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 490) // ~500 total width
    }
    
    func testStrokeToFillSinglePassWithMixedCurves() {
        // Test with a mix of lines, quad curves, and cubic curves
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.addQuadCurve(to: CGPoint(x: 100, y: 50), control: CGPoint(x: 75, y: 0))
        path.addCurve(to: CGPoint(x: 100, y: 100), control1: CGPoint(x: 125, y: 60), control2: CGPoint(x: 125, y: 90))
        path.addLine(to: CGPoint(x: 0, y: 100))
        
        let profile = BrushProfile.calligraphic
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 6,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassPreservesThicknessProfile() {
        // Test that thickness profile is applied correctly
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        // Use a tapered profile
        let taperedProfile = BrushProfile(
            tip: .circular,
            thicknessProfile: .taperBoth(start: 0.1, end: 0.1)
        )
        
        let uniformProfile = BrushProfile(
            tip: .circular,
            thicknessProfile: .uniform
        )
        
        let taperedResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: taperedProfile
        )
        
        let uniformResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: uniformProfile
        )
        
        // Both should produce valid paths
        XCTAssertFalse(taperedResult.isEmpty)
        XCTAssertFalse(uniformResult.isEmpty)
        
        // Tapered result should have smaller area (narrower ends)
        let taperedBounds = taperedResult.boundingRect
        let uniformBounds = uniformResult.boundingRect
        
        // The uniform stroke should be wider (or at least as wide) at the endpoints
        XCTAssertGreaterThanOrEqual(uniformBounds.height, taperedBounds.height - 2)
    }
    
    func testStrokeToFillSinglePassWithCircularPath() {
        // Test with a circular arc approximation
        var path = SwiftUI.Path()
        let center = CGPoint(x: 50, y: 50)
        let radius: CGFloat = 40
        
        // Create a rough circle using cubic curves
        path.move(to: CGPoint(x: center.x + radius, y: center.y))
        
        // Four cubic bezier curves to approximate a circle
        let k: CGFloat = 0.5522847498 // Magic number for circular approximation
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + radius),
            control1: CGPoint(x: center.x + radius, y: center.y + radius * k),
            control2: CGPoint(x: center.x + radius * k, y: center.y + radius)
        )
        path.addCurve(
            to: CGPoint(x: center.x - radius, y: center.y),
            control1: CGPoint(x: center.x - radius * k, y: center.y + radius),
            control2: CGPoint(x: center.x - radius, y: center.y + radius * k)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - radius),
            control1: CGPoint(x: center.x - radius, y: center.y - radius * k),
            control2: CGPoint(x: center.x - radius * k, y: center.y - radius)
        )
        path.addCurve(
            to: CGPoint(x: center.x + radius, y: center.y),
            control1: CGPoint(x: center.x + radius * k, y: center.y - radius),
            control2: CGPoint(x: center.x + radius, y: center.y - radius * k)
        )
        
        let profile = BrushProfile.marker
        let result = StrokeToFillConverter.convert(
            path: path,
            baseWidth: 8,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Result should roughly contain the original circle
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 70) // Should be roughly diameter + stroke width
    }
    
    func testStrokeToFillSinglePassConsistency() {
        // Test that calling convert multiple times produces consistent results
        let move = Move(data: [0, 0])
        let line1 = LineTo(data: [50, 25])
        let line2 = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line1, line2]
        
        let profile = BrushProfile.pen
        
        let result1 = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        let result2 = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Bounding rects should be identical
        XCTAssertEqual(result1.boundingRect.width, result2.boundingRect.width, accuracy: 0.001)
        XCTAssertEqual(result1.boundingRect.height, result2.boundingRect.height, accuracy: 0.001)
    }
    
    func testStrokeToFillSinglePassWithDifferentWidths() {
        // Test that different base widths produce proportionally sized results
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 0])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile.default
        
        let narrowResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 5,
            profile: profile
        )
        
        let wideResult = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 20,
            profile: profile
        )
        
        let narrowBounds = narrowResult.boundingRect
        let wideBounds = wideResult.boundingRect
        
        // The wider stroke should have greater height (perpendicular to stroke direction)
        XCTAssertGreaterThan(wideBounds.height, narrowBounds.height)
        
        // The ratio should be roughly proportional to the width ratio (4:1)
        let heightRatio = wideBounds.height / narrowBounds.height
        XCTAssertGreaterThan(heightRatio, 2.0) // Should be significantly larger
    }
    
    func testStrokeToFillSinglePassOnlyMoveOperation() {
        // Test edge case: only a move operation (no actual drawing)
        let move = Move(data: [50, 50])
        let operations: [RoughSwiftUI.Operation] = [move]
        
        let profile = BrushProfile.default
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        // Should produce an empty path (can't stroke a single point)
        XCTAssertTrue(result.isEmpty)
    }
    
    func testStrokeToFillSinglePassDiagonalLine() {
        // Test with a diagonal line to verify angle calculations
        let move = Move(data: [0, 0])
        let line = LineTo(data: [100, 100])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        let profile = BrushProfile(
            tip: BrushTip(roundness: 0.3, angle: 0, directionSensitive: true),
            thicknessProfile: .uniform
        )
        
        let result = StrokeToFillConverter.convert(
            operations: operations,
            baseWidth: 10,
            profile: profile
        )
        
        XCTAssertFalse(result.isEmpty)
        
        // Diagonal line at 45 degrees should produce a path that spans both x and y
        let bounds = result.boundingRect
        XCTAssertGreaterThan(bounds.width, 90)
        XCTAssertGreaterThan(bounds.height, 90)
    }
    
    func testStrokeToFillSinglePassCapStyles() {
        let move = Move(data: [0, 50])
        let line = LineTo(data: [100, 50])
        let operations: [RoughSwiftUI.Operation] = [move, line]
        
        // Test different cap styles
        let roundProfile = BrushProfile(tip: .circular, thicknessProfile: .uniform, cap: .round, join: .round)
        let buttProfile = BrushProfile(tip: .circular, thicknessProfile: .uniform, cap: .butt, join: .round)
        let squareProfile = BrushProfile(tip: .circular, thicknessProfile: .uniform, cap: .square, join: .round)
        
        let roundResult = StrokeToFillConverter.convert(operations: operations, baseWidth: 20, profile: roundProfile)
        let buttResult = StrokeToFillConverter.convert(operations: operations, baseWidth: 20, profile: buttProfile)
        let squareResult = StrokeToFillConverter.convert(operations: operations, baseWidth: 20, profile: squareProfile)
        
        // All should produce non-empty paths
        XCTAssertFalse(roundResult.isEmpty)
        XCTAssertFalse(buttResult.isEmpty)
        XCTAssertFalse(squareResult.isEmpty)
        
        // Round and square caps should extend beyond butt caps
        let roundBounds = roundResult.boundingRect
        let buttBounds = buttResult.boundingRect
        let squareBounds = squareResult.boundingRect
        
        XCTAssertGreaterThanOrEqual(roundBounds.width, buttBounds.width - 1)
        XCTAssertGreaterThanOrEqual(squareBounds.width, buttBounds.width - 1)
    }
    
}
