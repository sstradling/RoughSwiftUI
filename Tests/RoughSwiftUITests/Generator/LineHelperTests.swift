import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class LineHelperTests: XCTestCase {
    // MARK: Line Helper Tests
    
    func testLineHelperIntersection() {
        // Two perpendicular lines that should intersect at (50, 50)
        let line1 = LineHelper.Line(p1: (0, 50), p2: (100, 50))
        let line2 = LineHelper.Line(p1: (50, 0), p2: (50, 100))
        
        let intersection = LineHelper.intersection(line1, line2)
        
        XCTAssertNotNil(intersection, "Lines should intersect")
        XCTAssertEqual(intersection?.x ?? 0, 50, accuracy: 0.1, "Intersection X should be 50")
        XCTAssertEqual(intersection?.y ?? 0, 50, accuracy: 0.1, "Intersection Y should be 50")
    }
    
    func testLineHelperNoIntersectionParallel() {
        // Two parallel horizontal lines
        let line1 = LineHelper.Line(p1: (0, 0), p2: (100, 0))
        let line2 = LineHelper.Line(p1: (0, 50), p2: (100, 50))
        
        let intersection = LineHelper.intersection(line1, line2)
        
        XCTAssertNil(intersection, "Parallel lines should not intersect")
    }
    
    func testLineHelperPolygonIntersections() {
        // Horizontal line through a square
        let square: [[Float]] = [[0, 0], [100, 0], [100, 100], [0, 100]]
        let intersections = LineHelper.linePolygonIntersections(
            line: (start: (-50, 50), end: (150, 50)),
            polygon: square
        )
        
        XCTAssertEqual(intersections.count, 2, "Should have 2 intersections")
    }
    
}
