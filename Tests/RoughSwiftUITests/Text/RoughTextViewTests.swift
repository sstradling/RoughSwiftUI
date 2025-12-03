import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class RoughTextViewTests: XCTestCase {
    // MARK: - RoughText View Tests
    
    func testRoughTextViewCreation() {
        let roughText = RoughText("Hello", font: UIFont.systemFont(ofSize: 36))
        
        // Should compile and create successfully
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Styled",
            attributes: [.font: UIFont.boldSystemFont(ofSize: 24)]
        )
        let roughText = RoughText(attributedString: attributed)
        
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewWithFontName() {
        let roughText = RoughText("Test", fontName: "Courier", fontSize: 28)
        
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewModifiersReturnSelf() {
        let roughText = RoughText("Test", font: UIFont.systemFont(ofSize: 24))
            .fill(Color.red)
            .stroke(Color.black)
            .fillStyle(.hachure)
            .strokeWidth(2)
            .roughness(1.5)
        
        // All modifiers should chain properly
        XCTAssertNotNil(roughText)
    }
    
    func testRoughTextViewAnimatedModifier() {
        let roughText = RoughText("Wobble", font: UIFont.boldSystemFont(ofSize: 32))
            .fill(Color.blue)
            .fillStyle(.crossHatch)
        
        let animatedView = roughText.animated(steps: 6, speed: .slow, variance: .low)
        
        // Should return AnimatedRoughView
        XCTAssertNotNil(animatedView)
    }
    
    func testRoughTextViewSVGModifiers() {
        let roughText = RoughText("SVG", font: UIFont.systemFont(ofSize: 24))
            .svgStrokeWidth(3)
            .svgFillWeight(2)
            .svgFillStrokeAlignment(.inside)
        
        XCTAssertNotNil(roughText)
    }
    
}
