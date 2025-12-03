import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class BrushTipTests: XCTestCase {
    // MARK: - Brush Tip Tests
    
    func testBrushTipDefaults() {
        let tip = BrushTip()
        
        XCTAssertEqual(tip.roundness, 1.0)
        XCTAssertEqual(tip.angle, 0)
        XCTAssertTrue(tip.directionSensitive)
    }
    
    func testBrushTipCircularPreset() {
        let tip = BrushTip.circular
        
        XCTAssertEqual(tip.roundness, 1.0)
        XCTAssertEqual(tip.angle, 0)
        XCTAssertFalse(tip.directionSensitive)
    }
    
    func testBrushTipCalligraphicPreset() {
        let tip = BrushTip.calligraphic
        
        XCTAssertEqual(tip.roundness, 0.3)
        XCTAssertEqual(tip.angle, .pi / 4, accuracy: 0.001)
        XCTAssertTrue(tip.directionSensitive)
    }
    
    func testBrushTipFlatPreset() {
        let tip = BrushTip.flat
        
        XCTAssertEqual(tip.roundness, 0.2)
        XCTAssertEqual(tip.angle, 0)
        XCTAssertTrue(tip.directionSensitive)
    }
    
    func testBrushTipRoundnessClamping() {
        // Test that roundness is clamped to valid range
        let tooLow = BrushTip(roundness: -0.5)
        let tooHigh = BrushTip(roundness: 2.0)
        
        XCTAssertEqual(tooLow.roundness, 0.01)
        XCTAssertEqual(tooHigh.roundness, 1.0)
    }
    
    func testBrushTipEffectiveWidthCircular() {
        let tip = BrushTip.circular
        let baseWidth: CGFloat = 10
        
        // Circular tip should return same width regardless of direction
        let width0 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: 0)
        let width45 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 4)
        let width90 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 2)
        
        XCTAssertEqual(width0, baseWidth)
        XCTAssertEqual(width45, baseWidth)
        XCTAssertEqual(width90, baseWidth)
    }
    
    func testBrushTipEffectiveWidthDirectionSensitive() {
        let tip = BrushTip(roundness: 0.5, angle: 0, directionSensitive: true)
        let baseWidth: CGFloat = 10
        
        // With flat horizontal brush, horizontal stroke should be narrower than vertical
        let widthHorizontal = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: 0)
        let widthVertical = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 2)
        
        // Vertical stroke cuts through the thin part, horizontal through the wide part
        XCTAssertNotEqual(widthHorizontal, widthVertical)
    }
    
    func testBrushTipEffectiveWidthDirectionInsensitive() {
        let tip = BrushTip(roundness: 0.5, angle: 0, directionSensitive: false)
        let baseWidth: CGFloat = 10
        
        // Direction-insensitive should return base width regardless of angle
        let width0 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: 0)
        let width90 = tip.effectiveWidth(baseWidth: baseWidth, strokeAngle: .pi / 2)
        
        XCTAssertEqual(width0, baseWidth)
        XCTAssertEqual(width90, baseWidth)
    }
    
    func testBrushTipEquatable() {
        let tip1 = BrushTip(roundness: 0.5, angle: 0.1, directionSensitive: true)
        let tip2 = BrushTip(roundness: 0.5, angle: 0.1, directionSensitive: true)
        let tip3 = BrushTip(roundness: 0.6, angle: 0.1, directionSensitive: true)
        
        XCTAssertEqual(tip1, tip2)
        XCTAssertNotEqual(tip1, tip3)
    }
    
}
