import XCTest
import SwiftUI
@testable import Sketchy

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
        XCTAssertEqual(BrushJoin.standardCurvedBevel.cgLineJoin, .bevel)
        XCTAssertEqual(BrushJoin.curvedBevel(bulge: 2).curvedBevelBulge, 1)
        XCTAssertEqual(BrushJoin.curvedBevel(bulge: -1).curvedBevelBulge, 0)
        XCTAssertTrue(BrushJoin.standardCurvedBevel.requiresCustomOutline)
        XCTAssertFalse(BrushJoin.miter.requiresCustomOutline)
    }
    
}
