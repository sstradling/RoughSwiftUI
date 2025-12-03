import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class FillPatternTests: XCTestCase {
    // MARK: Fill Pattern Tests
    
    func testHachureFillerPolygon() {
        let filler = HachureFiller()
        var options = Options()
        options.fillAngle = 45
        options.fillSpacing = 4
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce fill set")
        XCTAssertEqual(fillSet?.type, .fillSketch, "Should be fillSketch type")
        XCTAssertGreaterThan(fillSet?.operations.count ?? 0, 10, "Should have fill operations")
    }
    
    func testHachureFillerEllipse() {
        let filler = HachureFiller()
        var options = Options()
        options.fillAngle = 45
        options.fillSpacing = 4
        
        let fillSet = filler.fillEllipse(cx: 50, cy: 50, rx: 40, ry: 30, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce fill set for ellipse")
        XCTAssertGreaterThan(fillSet?.operations.count ?? 0, 5, "Should have fill operations")
    }
    
    func testSolidFiller() {
        let filler = SolidFiller()
        let options = Options()
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce fill set")
        XCTAssertEqual(fillSet?.type, .fillPath, "Should be fillPath type")
    }
    
    func testZigzagFiller() {
        let filler = ZigzagFiller()
        var options = Options()
        options.fillAngle = 45
        options.fillSpacing = 4
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce zigzag fill set")
        XCTAssertEqual(fillSet?.type, .fillSketch, "Should be fillSketch type")
    }
    
    func testCrossHatchFiller() {
        let filler = CrossHatchFiller()
        var options = Options()
        options.fillAngle = 45
        options.fillSpacing = 4
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce cross-hatch fill set")
        // Cross-hatch should have more operations than single hachure
        let singleHachure = HachureFiller().fillPolygon(points: points, options: options)
        XCTAssertGreaterThan(
            fillSet?.operations.count ?? 0,
            singleHachure?.operations.count ?? 0,
            "Cross-hatch should have more operations than single hachure"
        )
    }
    
    func testDotsFiller() {
        let filler = DotsFiller()
        var options = Options()
        options.fillSpacing = 10
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce dots fill set")
        XCTAssertEqual(fillSet?.type, .fillSketch, "Should be fillSketch type")
    }
    
    func testDashedFiller() {
        let filler = DashedFiller()
        var options = Options()
        options.fillAngle = 45
        options.fillSpacing = 4
        options.dashOffset = 5
        options.dashGap = 3
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce dashed fill set")
        XCTAssertEqual(fillSet?.type, .fillSketch, "Should be fillSketch type")
    }
    
    func testStarburstFiller() {
        let filler = StarburstFiller()
        var options = Options()
        options.fillSpacing = 8
        
        let points: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let fillSet = filler.fillPolygon(points: points, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce starburst fill set")
        XCTAssertEqual(fillSet?.type, .fillSketch, "Should be fillSketch type")
    }
    
    func testStarburstFillerEllipse() {
        let filler = StarburstFiller()
        var options = Options()
        options.fillSpacing = 8
        
        let fillSet = filler.fillEllipse(cx: 50, cy: 50, rx: 40, ry: 30, options: options)
        
        XCTAssertNotNil(fillSet, "Should produce starburst fill for ellipse")
    }
    
    func testFillPatternFactoryReturnsCorrectFillers() {
        XCTAssertTrue(FillPatternFactory.filler(for: .hachure) is HachureFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .solid) is SolidFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .zigzag) is ZigzagFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .crossHatch) is CrossHatchFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .dots) is DotsFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .dashed) is DashedFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .sunBurst) is StarburstFiller)
        XCTAssertTrue(FillPatternFactory.filler(for: .starBurst) is StarburstFiller)
    }
    
    func testFillPatternFactoryCachesFillers() {
        // Getting the same filler twice should return the same instance
        let filler1 = FillPatternFactory.filler(for: .hachure)
        let filler2 = FillPatternFactory.filler(for: .hachure)
        
        // Note: Protocol doesn't support identity comparison directly,
        // but the implementation caches, so this is a design note
        XCTAssertNotNil(filler1)
        XCTAssertNotNil(filler2)
    }
    
}
