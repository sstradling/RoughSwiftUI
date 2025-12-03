import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class BrushCapJoinTests: XCTestCase {
    // MARK: - Brush Cap Tests
    
    func testBrushCapCGLineCapConversion() {
        XCTAssertEqual(BrushCap.butt.cgLineCap, .butt)
        XCTAssertEqual(BrushCap.round.cgLineCap, .round)
        XCTAssertEqual(BrushCap.square.cgLineCap, .square)
    }
    
    // MARK: - Brush Join Tests
    
    func testBrushJoinCGLineJoinConversion() {
        XCTAssertEqual(BrushJoin.miter.cgLineJoin, .miter)
        XCTAssertEqual(BrushJoin.round.cgLineJoin, .round)
        XCTAssertEqual(BrushJoin.bevel.cgLineJoin, .bevel)
    }
    
}
