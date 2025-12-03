import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class GeneratorCacheTests: XCTestCase {
    // MARK: - Generator Caching Tests
    
    func testGeneratorCacheReturnsSameGeneratorForSameSize() {
        let cache = GeneratorCache()
        let engine = Engine()
        let size = CGSize(width: 200, height: 200)
        
        let generator1 = cache.generator(for: size, using: engine)
        let generator2 = cache.generator(for: size, using: engine)
        
        // Should return the same generator instance
        XCTAssertTrue(generator1 === generator2)
    }
    
    func testGeneratorCacheReturnsDifferentGeneratorForDifferentSizes() {
        let cache = GeneratorCache()
        let engine = Engine()
        
        let generator1 = cache.generator(for: CGSize(width: 100, height: 100), using: engine)
        let generator2 = cache.generator(for: CGSize(width: 200, height: 200), using: engine)
        
        // Should return different generators
        XCTAssertFalse(generator1 === generator2)
    }
    
    func testGeneratorCacheRoundsSizes() {
        let cache = GeneratorCache()
        let engine = Engine()
        
        // Sizes that round to the same integer should use the same generator
        let generator1 = cache.generator(for: CGSize(width: 100.2, height: 100.3), using: engine)
        let generator2 = cache.generator(for: CGSize(width: 100.4, height: 100.1), using: engine)
        
        XCTAssertTrue(generator1 === generator2)
    }
    
    func testGeneratorCacheEvictsOldEntries() {
        let cache = GeneratorCache(maxEntries: 3)
        let engine = Engine()
        
        // Fill the cache
        _ = cache.generator(for: CGSize(width: 100, height: 100), using: engine)
        _ = cache.generator(for: CGSize(width: 200, height: 200), using: engine)
        _ = cache.generator(for: CGSize(width: 300, height: 300), using: engine)
        
        XCTAssertEqual(cache.count, 3)
        
        // Adding a new size should evict the oldest
        _ = cache.generator(for: CGSize(width: 400, height: 400), using: engine)
        
        XCTAssertEqual(cache.count, 3)
    }
    
    func testGeneratorCacheClear() {
        let cache = GeneratorCache()
        let engine = Engine()
        
        _ = cache.generator(for: CGSize(width: 100, height: 100), using: engine)
        _ = cache.generator(for: CGSize(width: 200, height: 200), using: engine)
        
        XCTAssertEqual(cache.count, 2)
        
        cache.clear()
        
        XCTAssertEqual(cache.count, 0)
    }
    
    func testEngineGeneratorCachingIntegration() {
        let engine = Engine()
        
        // Clear caches first
        engine.clearCaches()
        
        let size = CGSize(width: 150, height: 150)
        
        // Access the same size multiple times
        let gen1 = engine.generator(size: size)
        let gen2 = engine.generator(size: size)
        
        // Should return same generator
        XCTAssertTrue(gen1 === gen2)
        
        // Cache stats should reflect this
        let stats = engine.cacheStats
        XCTAssertGreaterThanOrEqual(stats.generators, 1)
    }
    
}
