import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class DrawingCacheTests: XCTestCase {
    // MARK: - Drawing Cache Tests
    
    func testDrawingCacheStoresAndRetrievesDrawings() {
        let cache = DrawingCache()
        
        // Create a test drawing
        let options = Options()
        let drawing = Drawing(
            shape: "test",
            sets: [],
            options: options
        )
        
        // Create a cache key
        let key = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 100, height: 100),
            size: CGSize(width: 200, height: 200),
            options: options
        )
        
        // Store and retrieve
        cache.set(key, drawing: drawing)
        let retrieved = cache.get(key)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.shape, "test")
    }
    
    func testDrawingCacheReturnsNilForMissingKey() {
        let cache = DrawingCache()
        
        let key = DrawingCacheKey(
            drawable: Circle(x: 50, y: 50, diameter: 100),
            size: CGSize(width: 100, height: 100),
            options: Options()
        )
        
        let result = cache.get(key)
        
        XCTAssertNil(result)
    }
    
    func testDrawingCacheTracksCacheStats() {
        let cache = DrawingCache()
        
        let options = Options()
        let drawing = Drawing(shape: "test", sets: [], options: options)
        
        let key1 = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: Circle(x: 25, y: 25, diameter: 50),
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        // Miss
        _ = cache.get(key1)
        
        // Store
        cache.set(key1, drawing: drawing)
        
        // Hit
        _ = cache.get(key1)
        
        // Miss
        _ = cache.get(key2)
        
        let stats = cache.stats
        XCTAssertEqual(stats.entries, 1)
        XCTAssertEqual(stats.hits, 1)
        XCTAssertEqual(stats.misses, 2)
        XCTAssertEqual(stats.hitRate, 1.0 / 3.0, accuracy: 0.001)
    }
    
    func testDrawingCacheEvictsWhenFull() {
        let cache = DrawingCache(maxEntries: 3)
        let options = Options()
        
        // Fill the cache
        for i in 0..<5 {
            let drawing = Drawing(shape: "shape\(i)", sets: [], options: options)
            let key = DrawingCacheKey(
                drawable: Rectangle(x: Float(i * 10), y: 0, width: 50, height: 50),
                size: CGSize(width: 100, height: 100),
                options: options
            )
            cache.set(key, drawing: drawing)
        }
        
        // Cache should not exceed max entries
        XCTAssertLessThanOrEqual(cache.stats.entries, 3)
    }
    
    func testDrawingCacheGetOrGenerateUsesCachedValue() {
        let cache = DrawingCache()
        let options = Options()
        
        let key = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 100, height: 100),
            size: CGSize(width: 200, height: 200),
            options: options
        )
        
        var generatorCallCount = 0
        
        // First call should generate
        let result1 = cache.getOrGenerate(key) {
            generatorCallCount += 1
            return Drawing(shape: "generated", sets: [], options: options)
        }
        
        // Second call should use cache
        let result2 = cache.getOrGenerate(key) {
            generatorCallCount += 1
            return Drawing(shape: "generated-again", sets: [], options: options)
        }
        
        XCTAssertEqual(generatorCallCount, 1)
        XCTAssertEqual(result1?.shape, "generated")
        XCTAssertEqual(result2?.shape, "generated") // Should be cached value
    }
    
    func testDrawingCacheClear() {
        let cache = DrawingCache()
        let options = Options()
        
        let drawing = Drawing(shape: "test", sets: [], options: options)
        let key = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        cache.set(key, drawing: drawing)
        XCTAssertNotNil(cache.get(key))
        
        let statsBefore = cache.stats
        XCTAssertEqual(statsBefore.entries, 1)
        XCTAssertEqual(statsBefore.hits, 1) // The get above was a hit
        
        cache.clear()
        
        // After clear, the entry should be gone
        let statsAfter = cache.stats
        XCTAssertEqual(statsAfter.entries, 0)
        XCTAssertEqual(statsAfter.hits, 0) // Reset
        XCTAssertEqual(statsAfter.misses, 0) // Reset
        
        // Accessing after clear should be nil (and will record a miss)
        XCTAssertNil(cache.get(key))
        XCTAssertEqual(cache.stats.misses, 1) // Now there's a miss
    }
    
    func testDrawingCacheKeyDifferentDrawables() {
        let options = Options()
        let size = CGSize(width: 100, height: 100)
        
        let key1 = DrawingCacheKey(
            drawable: Rectangle(x: 0, y: 0, width: 50, height: 50),
            size: size,
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: Circle(x: 25, y: 25, diameter: 50),
            size: size,
            options: options
        )
        
        XCTAssertNotEqual(key1, key2)
    }
    
    func testDrawingCacheKeyDifferentOptions() {
        let size = CGSize(width: 100, height: 100)
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        
        var options1 = Options()
        options1.roughness = 1.0
        
        var options2 = Options()
        options2.roughness = 2.0
        
        let key1 = DrawingCacheKey(drawable: drawable, size: size, options: options1)
        let key2 = DrawingCacheKey(drawable: drawable, size: size, options: options2)
        
        XCTAssertNotEqual(key1, key2)
    }
    
    func testDrawingCacheKeyDifferentSizes() {
        let options = Options()
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        
        let key1 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 100, height: 100),
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 200, height: 200),
            options: options
        )
        
        XCTAssertNotEqual(key1, key2)
    }
    
    func testDrawingCacheKeySameSizeRounded() {
        let options = Options()
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        
        // Sizes that round to the same integer should produce same key
        let key1 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 100.2, height: 100.3),
            options: options
        )
        
        let key2 = DrawingCacheKey(
            drawable: drawable,
            size: CGSize(width: 100.4, height: 100.1),
            options: options
        )
        
        XCTAssertEqual(key1, key2)
    }
    
    func testOptionsCacheHashIncludesRelevantOptions() {
        var options1 = Options()
        options1.roughness = 1.0
        options1.fillStyle = .hachure
        
        var options2 = Options()
        options2.roughness = 1.0
        options2.fillStyle = .hachure
        
        // Same options should produce same hash
        XCTAssertEqual(options1.cacheHash, options2.cacheHash)
        
        // Different options should produce different hash
        options2.roughness = 2.0
        XCTAssertNotEqual(options1.cacheHash, options2.cacheHash)
    }
    
    func testOptionsCacheHashIncludesFillSpacingPattern() {
        var options1 = Options()
        options1.fillSpacingPattern = [1, 2, 3]
        
        var options2 = Options()
        options2.fillSpacingPattern = [1, 2, 3]
        
        var options3 = Options()
        options3.fillSpacingPattern = [4, 5, 6]
        
        XCTAssertEqual(options1.cacheHash, options2.cacheHash)
        XCTAssertNotEqual(options1.cacheHash, options3.cacheHash)
    }
    
    func testEngineClearCachesResetsAll() {
        let engine = Engine()
        
        // Use generators and generate drawings to populate caches
        let gen = engine.generator(size: CGSize(width: 100, height: 100))
        _ = gen.generate(drawable: Rectangle(x: 0, y: 0, width: 50, height: 50))
        
        let statsBefore = engine.cacheStats
        XCTAssertGreaterThan(statsBefore.generators, 0)
        
        engine.clearCaches()
        
        let statsAfter = engine.cacheStats
        XCTAssertEqual(statsAfter.generators, 0)
        XCTAssertEqual(statsAfter.drawings, 0)
    }
    
    func testGeneratorWithCacheReusesDrawings() {
        let engine = Engine()
        engine.clearCaches()
        
        let gen = engine.generator(size: CGSize(width: 100, height: 100))
        let drawable = Rectangle(x: 0, y: 0, width: 50, height: 50)
        let options = Options()
        
        // Generate twice with same parameters
        let drawing1 = gen.generate(drawable: drawable, options: options)
        let drawing2 = gen.generate(drawable: drawable, options: options)
        
        XCTAssertNotNil(drawing1)
        XCTAssertNotNil(drawing2)
        
        // Second call should hit cache
        let stats = engine.cacheStats
        XCTAssertGreaterThan(stats.hitRate, 0)
    }
    
}
