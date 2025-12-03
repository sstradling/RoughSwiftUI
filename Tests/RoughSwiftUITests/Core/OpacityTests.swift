import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class OpacityTests: XCTestCase {
    // MARK: - Opacity Options Tests
    
    func testOpacityOptionsDefaults() {
        let options = Options()
        
        // Default opacity should be fully opaque (1.0)
        XCTAssertEqual(options.strokeOpacity, 1.0)
        XCTAssertEqual(options.fillOpacity, 1.0)
    }
    
    func testOpacityOptionsCanBeSet() {
        var options = Options()
        options.strokeOpacity = 0.5
        options.fillOpacity = 0.75
        
        XCTAssertEqual(options.strokeOpacity, 0.5)
        XCTAssertEqual(options.fillOpacity, 0.75)
    }
    
    func testRoughViewStrokeOpacityModifier() {
        let view = RoughView()
            .strokeOpacity(50) // 50%
        
        // Modifier converts 0-100 to 0-1 range
        XCTAssertEqual(view.options.strokeOpacity, 0.5, accuracy: 0.001)
    }
    
    func testRoughViewFillOpacityModifier() {
        let view = RoughView()
            .fillOpacity(75) // 75%
        
        // Modifier converts 0-100 to 0-1 range
        XCTAssertEqual(view.options.fillOpacity, 0.75, accuracy: 0.001)
    }
    
    func testRoughViewOpacityModifiersClamping() {
        // Test clamping to valid range
        let viewLow = RoughView()
            .strokeOpacity(-10) // Should clamp to 0
            .fillOpacity(-20)
        
        XCTAssertEqual(viewLow.options.strokeOpacity, 0, accuracy: 0.001)
        XCTAssertEqual(viewLow.options.fillOpacity, 0, accuracy: 0.001)
        
        let viewHigh = RoughView()
            .strokeOpacity(150) // Should clamp to 100
            .fillOpacity(200)
        
        XCTAssertEqual(viewHigh.options.strokeOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(viewHigh.options.fillOpacity, 1.0, accuracy: 0.001)
    }
    
    func testRoughViewOpacityModifiersChaining() {
        let view = RoughView()
            .stroke(Color.red)
            .strokeOpacity(80)
            .fill(Color.blue)
            .fillOpacity(60)
            .circle()
        
        XCTAssertEqual(view.options.strokeOpacity, 0.8, accuracy: 0.001)
        XCTAssertEqual(view.options.fillOpacity, 0.6, accuracy: 0.001)
        XCTAssertEqual(view.drawables.count, 1)
    }
    
    func testOpacityFullyTransparent() {
        let view = RoughView()
            .strokeOpacity(0)
            .fillOpacity(0)
        
        XCTAssertEqual(view.options.strokeOpacity, 0, accuracy: 0.001)
        XCTAssertEqual(view.options.fillOpacity, 0, accuracy: 0.001)
    }
    
    func testOpacityFullyOpaque() {
        let view = RoughView()
            .strokeOpacity(100)
            .fillOpacity(100)
        
        XCTAssertEqual(view.options.strokeOpacity, 1.0, accuracy: 0.001)
        XCTAssertEqual(view.options.fillOpacity, 1.0, accuracy: 0.001)
    }
    
}
