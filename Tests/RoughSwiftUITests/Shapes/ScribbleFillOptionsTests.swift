import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class ScribbleFillOptionsTests: XCTestCase {
    // MARK: - Scribble Fill Options Tests
    
    func testScribbleOptionsDefaults() {
        let options = Options()
        
        XCTAssertEqual(options.scribbleOrigin, 0)
        XCTAssertEqual(options.scribbleTightness, 10)
        XCTAssertEqual(options.scribbleCurvature, 0)
        XCTAssertFalse(options.scribbleUseBrushStroke)
        XCTAssertNil(options.scribbleTightnessPattern)
    }
    
    func testScribbleOptionsCanBeSet() {
        var options = Options()
        options.scribbleOrigin = 45
        options.scribbleTightness = 20
        options.scribbleCurvature = 25
        options.scribbleUseBrushStroke = true
        options.scribbleTightnessPattern = [5, 15, 5]
        
        XCTAssertEqual(options.scribbleOrigin, 45)
        XCTAssertEqual(options.scribbleTightness, 20)
        XCTAssertEqual(options.scribbleCurvature, 25)
        XCTAssertTrue(options.scribbleUseBrushStroke)
        XCTAssertEqual(options.scribbleTightnessPattern, [5, 15, 5])
    }
    
    func testRoughViewScribbleOriginModifier() {
        let view = RoughView()
            .scribbleOrigin(90)
        
        XCTAssertEqual(view.options.scribbleOrigin, 90)
    }
    
    func testRoughViewScribbleTightnessModifier() {
        let view = RoughView()
            .scribbleTightness(25)
        
        XCTAssertEqual(view.options.scribbleTightness, 25)
    }
    
    func testRoughViewScribbleCurvatureModifier() {
        let view = RoughView()
            .scribbleCurvature(30)
        
        XCTAssertEqual(view.options.scribbleCurvature, 30)
    }
    
    func testRoughViewScribbleUseBrushStrokeModifier() {
        let view = RoughView()
            .scribbleUseBrushStroke(true)
        
        XCTAssertTrue(view.options.scribbleUseBrushStroke)
    }
    
    func testRoughViewScribbleTightnessPatternModifier() {
        let pattern = [10, 30, 10]
        let view = RoughView()
            .scribbleTightnessPattern(pattern)
        
        XCTAssertEqual(view.options.scribbleTightnessPattern, pattern)
    }
    
    func testRoughViewScribbleCombinedModifier() {
        let view = RoughView()
            .scribble(
                origin: 45,
                tightness: 15,
                curvature: 20,
                useBrushStroke: true
            )
        
        XCTAssertEqual(view.options.scribbleOrigin, 45)
        XCTAssertEqual(view.options.scribbleTightness, 15)
        XCTAssertEqual(view.options.scribbleCurvature, 20)
        XCTAssertTrue(view.options.scribbleUseBrushStroke)
    }
    
    func testRoughViewScribbleCombinedModifierWithPattern() {
        let view = RoughView()
            .scribble(
                origin: 45,
                tightnessPattern: [5, 20, 5],
                curvature: 20,
                useBrushStroke: true
            )
        
        XCTAssertEqual(view.options.scribbleOrigin, 45)
        XCTAssertEqual(view.options.scribbleCurvature, 20)
        XCTAssertTrue(view.options.scribbleUseBrushStroke)
        XCTAssertEqual(view.options.scribbleTightnessPattern, [5, 20, 5])
    }
    
    func testRoughViewScribbleCombinedModifierPartialValues() {
        let view = RoughView()
            .scribble(origin: 90, curvature: 15)
        
        // Only specified values should change
        XCTAssertEqual(view.options.scribbleOrigin, 90)
        XCTAssertEqual(view.options.scribbleCurvature, 15)
        // Others should remain default
        XCTAssertEqual(view.options.scribbleTightness, 10) // default
        XCTAssertFalse(view.options.scribbleUseBrushStroke) // default
    }
    
    func testScribbleFillStyleEnum() {
        // Test that scribble is a valid fill style
        let fillStyle = FillStyle.scribble
        XCTAssertEqual(fillStyle.rawValue, "scribble")
    }
    
    func testRoughViewWithScribbleFillStyle() {
        let view = RoughView()
            .fill(Color.red)
            .fillStyle(.scribble)
            .scribbleTightness(15)
            .scribbleCurvature(20)
            .rectangle()
        
        XCTAssertEqual(view.options.fillStyle, .scribble)
        XCTAssertEqual(view.options.scribbleTightness, 15)
        XCTAssertEqual(view.options.scribbleCurvature, 20)
        XCTAssertEqual(view.drawables.count, 1)
    }
    
}
