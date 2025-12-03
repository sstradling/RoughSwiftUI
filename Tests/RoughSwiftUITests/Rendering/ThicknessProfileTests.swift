import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class ThicknessProfileTests: XCTestCase {
    // MARK: - Thickness Profile Tests
    
    func testThicknessProfileUniform() {
        let profile = ThicknessProfile.uniform
        
        XCTAssertEqual(profile.multiplier(at: 0), 1.0)
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0)
        XCTAssertEqual(profile.multiplier(at: 1.0), 1.0)
    }
    
    func testThicknessProfileTaperIn() {
        let profile = ThicknessProfile.taperIn(start: 0.5)
        
        // At start, should be thin
        XCTAssertEqual(profile.multiplier(at: 0), 0, accuracy: 0.001)
        
        // At midpoint (end of taper), should be full
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        
        // After taper, should stay full
        XCTAssertEqual(profile.multiplier(at: 0.75), 1.0, accuracy: 0.001)
        XCTAssertEqual(profile.multiplier(at: 1.0), 1.0, accuracy: 0.001)
    }
    
    func testThicknessProfileTaperOut() {
        let profile = ThicknessProfile.taperOut(end: 0.5)
        
        // At start, should be full
        XCTAssertEqual(profile.multiplier(at: 0), 1.0, accuracy: 0.001)
        
        // At midpoint (start of taper), should be full
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        
        // At end, should be thin
        XCTAssertEqual(profile.multiplier(at: 1.0), 0, accuracy: 0.001)
    }
    
    func testThicknessProfileTaperBoth() {
        let profile = ThicknessProfile.taperBoth(start: 0.25, end: 0.25)
        
        // At start, should be thin
        XCTAssertEqual(profile.multiplier(at: 0), 0, accuracy: 0.001)
        
        // In middle, should be full
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        
        // At end, should be thin
        XCTAssertEqual(profile.multiplier(at: 1.0), 0, accuracy: 0.001)
    }
    
    func testThicknessProfilePressure() {
        let profile = ThicknessProfile.pressure([0.2, 0.6, 1.0, 0.8, 0.4])
        
        // At start, should match first value
        XCTAssertEqual(profile.multiplier(at: 0), 0.2, accuracy: 0.001)
        
        // At end, should match last value
        XCTAssertEqual(profile.multiplier(at: 1.0), 0.4, accuracy: 0.001)
        
        // Mid values should be interpolated
        let midValue = profile.multiplier(at: 0.5)
        XCTAssertGreaterThan(midValue, 0.5)
    }
    
    func testThicknessProfileCustom() {
        let profile = ThicknessProfile.custom([0.5, 1.0, 0.5])
        
        XCTAssertEqual(profile.multiplier(at: 0), 0.5, accuracy: 0.001)
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        XCTAssertEqual(profile.multiplier(at: 1.0), 0.5, accuracy: 0.001)
    }
    
    func testThicknessProfileNaturalPenPreset() {
        let profile = ThicknessProfile.naturalPen
        
        // Should taper at both ends
        XCTAssertLessThan(profile.multiplier(at: 0), 1.0)
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0, accuracy: 0.001)
        XCTAssertLessThan(profile.multiplier(at: 1.0), 1.0)
    }
    
    func testThicknessProfileBrushStartPreset() {
        let profile = ThicknessProfile.brushStart
        
        // Should taper at start only
        XCTAssertLessThan(profile.multiplier(at: 0), 1.0)
        XCTAssertEqual(profile.multiplier(at: 1.0), 1.0, accuracy: 0.001)
    }
    
    func testThicknessProfileBrushEndPreset() {
        let profile = ThicknessProfile.brushEnd
        
        // Should taper at end only
        XCTAssertEqual(profile.multiplier(at: 0), 1.0, accuracy: 0.001)
        XCTAssertLessThan(profile.multiplier(at: 1.0), 1.0)
    }
    
    func testThicknessProfileEmptyArrayFallback() {
        let profile = ThicknessProfile.custom([])
        
        // Empty array should fallback to 1.0
        XCTAssertEqual(profile.multiplier(at: 0.5), 1.0)
    }
    
    func testThicknessProfileSingleValueArray() {
        let profile = ThicknessProfile.custom([0.7])
        
        // Single value should return that value everywhere
        XCTAssertEqual(profile.multiplier(at: 0), 0.7)
        XCTAssertEqual(profile.multiplier(at: 0.5), 0.7)
        XCTAssertEqual(profile.multiplier(at: 1.0), 0.7)
    }
    
    func testThicknessProfileClampsTParameter() {
        let profile = ThicknessProfile.taperIn(start: 0.5)
        
        // Values outside 0-1 should be clamped
        XCTAssertEqual(profile.multiplier(at: -0.5), profile.multiplier(at: 0))
        XCTAssertEqual(profile.multiplier(at: 1.5), profile.multiplier(at: 1.0))
    }
    
    func testThicknessProfileEquatable() {
        let profile1 = ThicknessProfile.taperIn(start: 0.3)
        let profile2 = ThicknessProfile.taperIn(start: 0.3)
        let profile3 = ThicknessProfile.taperIn(start: 0.5)
        
        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }
    
}
