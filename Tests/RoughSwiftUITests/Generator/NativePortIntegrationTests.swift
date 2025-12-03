import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class NativePortIntegrationTests: XCTestCase {
    // MARK: Additional Native Port Integration Tests
    
    func testEngineWithNativeGenerator() {
        let engine = Engine()
        let gen = engine.generator(size: CGSize(width: 200, height: 200))
        
        XCTAssertNotNil(gen, "Engine should return a generator")
        
        let drawing = gen.generate(drawable: Rectangle(x: 10, y: 10, width: 80, height: 80))
        XCTAssertNotNil(drawing, "Generator should produce drawing")
        XCTAssertEqual(drawing?.shape, "rectangle")
    }
    
    func testEngineGenerateWithCache() {
        let engine = Engine()
        engine.clearCaches()
        
        let drawable = Rectangle(x: 10, y: 10, width: 80, height: 80)
        let options = Options()
        let size = CGSize(width: 200, height: 200)
        
        // First call
        let drawing1 = engine.generate(drawable: drawable, options: options, size: size)
        XCTAssertNotNil(drawing1)
        
        // Second call should use cache
        let drawing2 = engine.generate(drawable: drawable, options: options, size: size)
        XCTAssertNotNil(drawing2)
        
        // Stats should show cache activity
        let stats = engine.cacheStats
        XCTAssertGreaterThan(stats.hitRate, 0, "Should have cache hits")
    }
    
    func testEngineClearCaches() {
        let engine = Engine()
        
        _ = engine.generator(size: CGSize(width: 100, height: 100))
        _ = engine.generate(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            options: Options(),
            size: CGSize(width: 100, height: 100)
        )
        
        engine.clearCaches()
        
        let stats = engine.cacheStats
        XCTAssertEqual(stats.generators, 0, "Generator cache should be empty")
        XCTAssertEqual(stats.drawings, 0, "Drawing cache should be empty")
    }
    
    func testAllShapesGenerateSuccessfully() {
        let engine = Engine()
        let gen = engine.generator(size: CGSize(width: 300, height: 300))
        
        // Test all shape types
        let shapes: [(Drawable, String)] = [
            (Line(from: Point(x: 10, y: 10), to: Point(x: 100, y: 100)), "line"),
            (Rectangle(x: 10, y: 10, width: 100, height: 80), "rectangle"),
            (Ellipse(x: 100, y: 100, width: 80, height: 60), "ellipse"),
            (Circle(x: 100, y: 100, diameter: 80), "circle"),
            (Polygon(points: [Point(x: 100, y: 10), Point(x: 190, y: 100), Point(x: 10, y: 100)]), "polygon"),
            (Arc(x: 100, y: 100, width: 80, height: 80, start: 0, stop: Float.pi), "arc"),
            (Curve(points: [Point(x: 10, y: 50), Point(x: 50, y: 10), Point(x: 150, y: 90), Point(x: 190, y: 50)]), "curve"),
            (LinearPath(points: [Point(x: 10, y: 10), Point(x: 100, y: 50), Point(x: 190, y: 10)]), "linearPath"),
            (Path(d: "M 10 10 L 100 100 L 10 100 Z"), "path")
        ]
        
        for (drawable, expectedShape) in shapes {
            let drawing = gen.generate(drawable: drawable)
            XCTAssertNotNil(drawing, "Should generate \(expectedShape)")
            XCTAssertEqual(drawing?.shape, expectedShape, "Shape should be \(expectedShape)")
        }
    }
    
    func testAllFillStylesGenerateSuccessfully() {
        let engine = Engine()
        let gen = engine.generator(size: CGSize(width: 200, height: 200))
        let drawable = Rectangle(x: 10, y: 10, width: 100, height: 80)
        
        let fillStyles: [RoughSwiftUI.FillStyle] = [.hachure, .solid, .zigzag, .crossHatch, .dots, .dashed, .sunBurst, .starBurst]
        
        for style in fillStyles {
            var options = Options()
            options.fillStyle = style
            options.fill = .blue
            
            let drawing = gen.generate(drawable: drawable, options: options)
            XCTAssertNotNil(drawing, "Should generate with fill style \(style)")
            XCTAssertEqual(drawing?.sets.count, 2, "Should have fill and stroke sets for \(style)")
        }
    }
}
