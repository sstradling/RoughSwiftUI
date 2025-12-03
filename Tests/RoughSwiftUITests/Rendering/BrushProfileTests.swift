import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class BrushProfileTests: XCTestCase {
    // MARK: - Brush Profile Tests
    
    func testBrushProfileDefaults() {
        let profile = BrushProfile()
        
        XCTAssertEqual(profile.tip, .circular)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
        XCTAssertEqual(profile.cap, .round)
        XCTAssertEqual(profile.join, .round)
    }
    
    func testBrushProfileDefaultPreset() {
        let profile = BrushProfile.default
        
        XCTAssertFalse(profile.requiresCustomRendering)
    }
    
    func testBrushProfileCalligraphicPreset() {
        let profile = BrushProfile.calligraphic
        
        XCTAssertEqual(profile.tip, .calligraphic)
        XCTAssertEqual(profile.thicknessProfile, .naturalPen)
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileMarkerPreset() {
        let profile = BrushProfile.marker
        
        XCTAssertEqual(profile.tip, .flat)
        XCTAssertEqual(profile.thicknessProfile, .uniform)
        XCTAssertEqual(profile.cap, .butt)
        XCTAssertEqual(profile.join, .bevel)
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfilePenPreset() {
        let profile = BrushProfile.pen
        
        XCTAssertEqual(profile.tip, .circular)
        XCTAssertEqual(profile.thicknessProfile, .penPressure)
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileRequiresCustomRenderingWithNonCircularTip() {
        let profile = BrushProfile(tip: .flat, thicknessProfile: .uniform)
        
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileRequiresCustomRenderingWithVariableThickness() {
        let profile = BrushProfile(tip: .circular, thicknessProfile: .naturalPen)
        
        XCTAssertTrue(profile.requiresCustomRendering)
    }
    
    func testBrushProfileNoCustomRenderingForSimpleProfile() {
        let profile = BrushProfile(
            tip: BrushTip(roundness: 1.0, angle: 0, directionSensitive: false),
            thicknessProfile: .uniform
        )
        
        XCTAssertFalse(profile.requiresCustomRendering)
    }
    
    func testBrushProfileEquatable() {
        let profile1 = BrushProfile.calligraphic
        let profile2 = BrushProfile.calligraphic
        let profile3 = BrushProfile.marker
        
        XCTAssertEqual(profile1, profile2)
        XCTAssertNotEqual(profile1, profile3)
    }
    
    // MARK: - Options Brush Profile Tests
    
    func testOptionsBrushProfileDefaults() {
        let options = Options()
        
        XCTAssertEqual(options.brushProfile, .default)
        XCTAssertEqual(options.brushTip, .circular)
        XCTAssertEqual(options.thicknessProfile, .uniform)
        XCTAssertEqual(options.strokeCap, .round)
        XCTAssertEqual(options.strokeJoin, .round)
    }
    
    func testOptionsBrushProfileConvenienceAccessors() {
        var options = Options()
        
        options.brushTip = .calligraphic
        XCTAssertEqual(options.brushProfile.tip, .calligraphic)
        
        options.thicknessProfile = .naturalPen
        XCTAssertEqual(options.brushProfile.thicknessProfile, .naturalPen)
        
        options.strokeCap = .butt
        XCTAssertEqual(options.brushProfile.cap, .butt)
        
        options.strokeJoin = .bevel
        XCTAssertEqual(options.brushProfile.join, .bevel)
    }
    
    func testOptionsBrushProfileFullAssignment() {
        var options = Options()
        options.brushProfile = .marker
        
        XCTAssertEqual(options.brushTip, .flat)
        XCTAssertEqual(options.thicknessProfile, .uniform)
        XCTAssertEqual(options.strokeCap, .butt)
        XCTAssertEqual(options.strokeJoin, .bevel)
    }
    
    // MARK: - RoughView Brush Profile Modifiers Tests
    
    func testRoughViewBrushProfileModifier() {
        let view = RoughView()
            .brushProfile(.calligraphic)
        
        XCTAssertEqual(view.options.brushProfile, .calligraphic)
    }
    
    func testRoughViewBrushTipModifier() {
        let view = RoughView()
            .brushTip(roundness: 0.4, angle: 0.5, directionSensitive: true)
        
        XCTAssertEqual(view.options.brushTip.roundness, 0.4)
        XCTAssertEqual(view.options.brushTip.angle, 0.5)
        XCTAssertTrue(view.options.brushTip.directionSensitive)
    }
    
    func testRoughViewBrushTipPresetModifier() {
        let view = RoughView()
            .brushTip(.flat)
        
        XCTAssertEqual(view.options.brushTip, .flat)
    }
    
    func testRoughViewThicknessProfileModifier() {
        let view = RoughView()
            .thicknessProfile(.taperBoth(start: 0.2, end: 0.3))
        
        XCTAssertEqual(view.options.thicknessProfile, .taperBoth(start: 0.2, end: 0.3))
    }
    
    func testRoughViewStrokeCapModifier() {
        let view = RoughView()
            .strokeCap(.butt)
        
        XCTAssertEqual(view.options.strokeCap, .butt)
    }
    
    func testRoughViewStrokeJoinModifier() {
        let view = RoughView()
            .strokeJoin(.miter)
        
        XCTAssertEqual(view.options.strokeJoin, .miter)
    }
    
    func testRoughViewBrushModifiersChaining() {
        let view = RoughView()
            .strokeWidth(8)
            .brushTip(.calligraphic)
            .thicknessProfile(.naturalPen)
            .strokeCap(.round)
            .strokeJoin(.round)
            .stroke(Color.black)
            .draw(Line(from: Point(x: 0, y: 0), to: Point(x: 100, y: 100)))
        
        XCTAssertEqual(view.options.strokeWidth, 8)
        XCTAssertEqual(view.options.brushTip, .calligraphic)
        XCTAssertEqual(view.options.thicknessProfile, .naturalPen)
        XCTAssertEqual(view.drawables.count, 1)
    }
    
}
