//
//  DrawingCache.swift
//  RoughSwift
//
//  Caching layer for generated drawings to improve performance.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation
import CoreGraphics

// MARK: - Cache Key

/// Key for caching generated drawings.
/// Combines drawable parameters with options to create unique keys.
public struct DrawingCacheKey: Hashable {
    let drawableType: String
    let size: CGSize
    let argumentsHash: Int
    let optionsHash: Int
    
    public init(drawable: Drawable, size: CGSize, options: Options) {
        self.drawableType = drawable.method
        // Round size to avoid floating point key issues (same as GeneratorCache)
        self.size = CGSize(
            width: round(size.width),
            height: round(size.height)
        )
        self.argumentsHash = Self.hashArguments(drawable.arguments)
        self.optionsHash = Self.hashOptions(options)
    }
    
    /// Creates a hash from drawable arguments.
    private static func hashArguments(_ arguments: [Any]) -> Int {
        var hasher = Hasher()
        for arg in arguments {
            if let num = arg as? NSNumber {
                hasher.combine(num.doubleValue)
            } else if let str = arg as? String {
                hasher.combine(str)
            } else if let dict = arg as? [String: Any] {
                // Point dictionary
                if let x = dict["x"] as? NSNumber {
                    hasher.combine(x.doubleValue)
                }
                if let y = dict["y"] as? NSNumber {
                    hasher.combine(y.doubleValue)
                }
            }
        }
        return hasher.finalize()
    }
    
    /// Creates a hash from render-affecting options.
    private static func hashOptions(_ options: Options) -> Int {
        var hasher = Hasher()
        hasher.combine(options.maxRandomnessOffset)
        hasher.combine(options.roughness)
        hasher.combine(options.bowing)
        hasher.combine(options.strokeWidth)
        hasher.combine(options.curveTightness)
        hasher.combine(options.curveStepCount)
        hasher.combine(options.fillStyle)
        hasher.combine(options.fillWeight)
        hasher.combine(options.fillAngle)
        hasher.combine(options.fillSpacing)
        hasher.combine(options.dashOffset)
        hasher.combine(options.dashGap)
        hasher.combine(options.zigzagOffset)
        return hasher.finalize()
    }
}

// MARK: - Drawing Cache

/// Thread-safe cache for generated drawings.
/// Uses LRU eviction when capacity is reached.
@MainActor
public final class DrawingCache {
    
    /// Shared singleton instance.
    public static let shared = DrawingCache()
    
    /// Maximum number of entries before eviction.
    private let maxEntries: Int
    
    /// The cache storage.
    private var cache: [DrawingCacheKey: CacheEntry] = [:]
    
    /// Access order for LRU eviction.
    private var accessOrder: [DrawingCacheKey] = []
    
    /// Cache statistics.
    public private(set) var hits: Int = 0
    public private(set) var misses: Int = 0
    
    /// Creates a drawing cache with specified capacity.
    /// - Parameter maxEntries: Maximum entries before eviction (default: 100)
    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }
    
    // MARK: - Public Interface
    
    /// Gets a cached drawing or generates and caches a new one.
    /// - Parameters:
    ///   - drawable: The drawable to generate
    ///   - options: Rendering options
    ///   - size: Canvas size
    ///   - generator: Generator to use if cache miss
    /// - Returns: The drawing (from cache or newly generated)
    public func getOrGenerate(
        drawable: Drawable,
        options: Options,
        size: CGSize,
        generator: NativeGenerator
    ) -> Drawing? {
        let key = DrawingCacheKey(drawable: drawable, size: size, options: options)
        
        if let entry = cache[key] {
            hits += 1
            updateAccessOrder(key)
            return entry.drawing
        }
        
        misses += 1
        
        guard let drawing = generator.generate(drawable: drawable, options: options) else {
            return nil
        }
        
        store(key: key, drawing: drawing)
        return drawing
    }
    
    /// Gets a drawing from cache if available.
    /// - Parameter key: The cache key
    /// - Returns: The cached drawing, or nil if not found
    public func get(_ key: DrawingCacheKey) -> Drawing? {
        if let entry = cache[key] {
            hits += 1
            updateAccessOrder(key)
            return entry.drawing
        }
        misses += 1
        return nil
    }
    
    /// Stores a drawing in the cache.
    /// - Parameters:
    ///   - key: The cache key
    ///   - drawing: The drawing to cache
    public func store(key: DrawingCacheKey, drawing: Drawing) {
        // Evict if necessary
        while cache.count >= maxEntries {
            evictLRU()
        }
        
        cache[key] = CacheEntry(drawing: drawing, timestamp: Date())
        accessOrder.append(key)
    }
    
    /// Clears all cached drawings and resets statistics.
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
        hits = 0
        misses = 0
    }
    
    /// Clears cached drawings for a specific size.
    /// Useful when view size changes.
    public func clearForSize(_ size: CGSize) {
        let keysToRemove = cache.keys.filter { $0.size == size }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
        }
    }
    
    /// Returns cache statistics.
    public var statistics: (hits: Int, misses: Int, count: Int, hitRate: Double) {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0
        return (hits, misses, cache.count, hitRate)
    }
    
    /// Returns cache statistics in format expected by Engine.
    public var stats: (entries: Int, hitRate: Double, hits: Int, misses: Int) {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0
        return (cache.count, hitRate, hits, misses)
    }
    
    /// Alias for store (backwards compatibility).
    public func set(_ key: DrawingCacheKey, drawing: Drawing) {
        store(key: key, drawing: drawing)
    }
    
    /// Gets or generates a drawing using a closure (for backwards compatibility).
    /// - Parameters:
    ///   - key: The cache key
    ///   - generator: Closure to generate the drawing if not cached
    /// - Returns: The drawing (from cache or newly generated)
    public func getOrGenerate(_ key: DrawingCacheKey, generator: () -> Drawing?) -> Drawing? {
        if let entry = cache[key] {
            hits += 1
            updateAccessOrder(key)
            return entry.drawing
        }
        
        misses += 1
        
        guard let drawing = generator() else {
            return nil
        }
        
        store(key: key, drawing: drawing)
        return drawing
    }
    
    /// Resets cache statistics.
    public func resetStatistics() {
        hits = 0
        misses = 0
    }
    
    // MARK: - Private Methods
    
    /// Updates access order for LRU tracking.
    private func updateAccessOrder(_ key: DrawingCacheKey) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }
    
    /// Evicts the least recently used entry.
    private func evictLRU() {
        guard let lruKey = accessOrder.first else { return }
        cache.removeValue(forKey: lruKey)
        accessOrder.removeFirst()
    }
}

// MARK: - Cache Entry

/// A single cache entry with metadata.
private struct CacheEntry {
    let drawing: Drawing
    let timestamp: Date
}

