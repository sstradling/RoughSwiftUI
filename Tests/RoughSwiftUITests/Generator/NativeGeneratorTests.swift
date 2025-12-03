import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class NativeGeneratorTests: XCTestCase {
    // MARK: NativeGenerator Tests
    
    func testNativeGeneratorLine() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let drawable = Line(from: Point(x: 10, y: 10), to: Point(x: 190, y: 190))
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate line drawing")
        XCTAssertEqual(drawing?.shape, "line")
        XCTAssertGreaterThan(drawing?.sets.count ?? 0, 0, "Should have at least one set")
    }
    
    func testNativeGeneratorRectangle() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let drawable = Rectangle(x: 10, y: 10, width: 100, height: 80)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate rectangle drawing")
        XCTAssertEqual(drawing?.shape, "rectangle")
        XCTAssertEqual(drawing?.sets.count, 2, "Rectangle should have fill and stroke sets")
    }
    
    func testNativeGeneratorEllipse() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let drawable = Ellipse(x: 100, y: 100, width: 80, height: 60)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate ellipse drawing")
        XCTAssertEqual(drawing?.shape, "ellipse")
        XCTAssertEqual(drawing?.sets.count, 2, "Ellipse should have fill and stroke sets")
    }
    
    func testNativeGeneratorCircle() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let drawable = Circle(x: 100, y: 100, diameter: 80)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate circle drawing")
        XCTAssertEqual(drawing?.shape, "circle")
        XCTAssertEqual(drawing?.sets.count, 2, "Circle should have fill and stroke sets")
    }
    
    func testNativeGeneratorPolygon() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let points = [Point(x: 100, y: 10), Point(x: 190, y: 190), Point(x: 10, y: 190)]
        let drawable = Polygon(points: points)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate polygon drawing")
        XCTAssertEqual(drawing?.shape, "polygon")
    }
    
    func testNativeGeneratorArc() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let drawable = Arc(x: 100, y: 100, width: 80, height: 80, start: 0, stop: Float.pi, closed: true)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate arc drawing")
        XCTAssertEqual(drawing?.shape, "arc")
    }
    
    func testNativeGeneratorCurve() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let points = [Point(x: 10, y: 100), Point(x: 50, y: 10), Point(x: 150, y: 190), Point(x: 190, y: 100)]
        let drawable = Curve(points: points)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate curve drawing")
        XCTAssertEqual(drawing?.shape, "curve")
    }
    
    func testNativeGeneratorLinearPath() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let points = [Point(x: 10, y: 10), Point(x: 100, y: 50), Point(x: 190, y: 10)]
        let drawable = LinearPath(points: points)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate linear path drawing")
        XCTAssertEqual(drawing?.shape, "linearPath")
    }
    
    func testNativeGeneratorPath() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let svgPath = "M 10 10 L 190 10 L 190 190 L 10 190 Z"
        let drawable = Path(d: svgPath)
        
        let drawing = gen.generate(drawable: drawable)
        
        XCTAssertNotNil(drawing, "Should generate SVG path drawing")
        XCTAssertEqual(drawing?.shape, "path")
    }
    
    func testNativeGeneratorWithOptions() {
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200))
        let drawable = Rectangle(x: 10, y: 10, width: 100, height: 80)
        
        var options = Options()
        options.roughness = 2.0
        options.strokeWidth = 3.0
        options.fillStyle = .crossHatch
        options.fill = .red
        
        let drawing = gen.generate(drawable: drawable, options: options)
        
        XCTAssertNotNil(drawing, "Should generate drawing with options")
        XCTAssertEqual(drawing?.options.roughness, 2.0)
        XCTAssertEqual(drawing?.options.strokeWidth, 3.0)
        XCTAssertEqual(drawing?.options.fillStyle, .crossHatch)
    }
    
    func testNativeGeneratorWithCache() {
        let cache = DrawingCache()
        let gen = NativeGenerator(size: CGSize(width: 200, height: 200), drawingCache: cache)
        let drawable = Rectangle(x: 10, y: 10, width: 100, height: 80)
        
        // First call
        let drawing1 = gen.generate(drawable: drawable)
        XCTAssertNotNil(drawing1)
        
        // Second call should hit cache
        let drawing2 = gen.generate(drawable: drawable)
        XCTAssertNotNil(drawing2)
        
        // Cache should have recorded a hit
        XCTAssertGreaterThan(cache.stats.hits, 0, "Should have cache hits")
    }
    
    func testNativeGeneratorFullRectangle() {
        let gen = NativeGenerator(size: CGSize(width: 100, height: 100))
        let drawing = gen.generate(drawable: FullRectangle())
        
        XCTAssertNotNil(drawing, "Should generate full rectangle")
        XCTAssertEqual(drawing?.shape, "rectangle")
    }
    
    func testNativeGeneratorFullCircle() {
        let gen = NativeGenerator(size: CGSize(width: 100, height: 100))
        let drawing = gen.generate(drawable: FullCircle())
        
        XCTAssertNotNil(drawing, "Should generate full circle")
        XCTAssertEqual(drawing?.shape, "circle")
    }
    
}
