import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class RoughViewTextTests: XCTestCase {
    // MARK: - RoughView Text Modifier Tests
    
    func testRoughViewTextModifier() {
        let view = RoughView()
            .fill(Color.red)
            .text("Hello", font: UIFont.systemFont(ofSize: 24))
        
        // Should have one drawable
        XCTAssertEqual(view.drawables.count, 1)
        
        // Drawable should be a Text
        XCTAssertTrue(view.drawables[0] is RoughSwiftUI.Text)
    }
    
    func testRoughViewTextModifierWithAttributedString() {
        let attributed = NSAttributedString(
            string: "Styled",
            attributes: [.font: UIFont.italicSystemFont(ofSize: 20)]
        )
        let view = RoughView()
            .text(attributedString: attributed)
        
        XCTAssertEqual(view.drawables.count, 1)
        XCTAssertTrue(view.drawables[0] is RoughSwiftUI.Text)
    }
    
    func testRoughViewTextModifierWithFontName() {
        let view = RoughView()
            .text("ABC", fontName: "Helvetica-Bold", fontSize: 32)
        
        XCTAssertEqual(view.drawables.count, 1)
    }
    
    func testRoughViewMultipleTexts() {
        let view = RoughView()
            .text("First", font: UIFont.systemFont(ofSize: 24))
            .text("Second", font: UIFont.systemFont(ofSize: 24))
        
        // Should have two drawables
        XCTAssertEqual(view.drawables.count, 2)
    }
    
}
