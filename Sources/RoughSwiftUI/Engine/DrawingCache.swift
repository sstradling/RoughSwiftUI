//
//  DrawingCache.swift
//  RoughSwift
//
//  Created by Performance Optimization
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Caching layer for generated drawings to avoid repeated JS bridge calls.
//

import Foundation
import CoreGraphics

// MARK: - Cache Key

/// A hashable key for caching generated drawings.
///
/// The key uniquely identifies a drawing based on:
/// - The drawable type and its arguments
/// - The canvas size
/// - Relevant rendering options that affect the output
public struct DrawingCacheKey: Hashable {
    /// Identifier for the drawable (method name + arguments hash)
    let drawableIdentifier: String
    
    /// The canvas size (rounded to avoid floating point variations)
    let sizeKey: SizeKey
    
    /// Hash of options that affect drawing generation
    let optionsHash: Int
    
    /// Rounded size representation for consistent hashing
    struct SizeKey: Hashable {
        let width: Int
        let height: Int
        
        init(_ size: CGSize) {
            // Round to nearest pixel to avoid cache misses from tiny variations
            self.width = Int(size.width.rounded())
            self.height = Int(size.height.rounded())
        }
    }
    
    /// Creates a cache key from a drawable and options.
    ///
    /// - Parameters:
    ///   - drawable: The drawable to cache.
    ///   - size: The canvas size.
    ///   - options: The rendering options.
    public init(drawable: Drawable, size: CGSize, options: Options) {
        // Build a string identifier from the drawable
        let args = drawable.arguments.map { "\($0)" }.joined(separator: ",")
        self.drawableIdentifier = "\(drawable.method):\(args)"
        
        self.sizeKey = SizeKey(size)
        self.optionsHash = options.cacheHash
    }
}

// MARK: - Options Cache Hash

extension Options {
    /// Computes a hash of options that affect drawing generation.
    ///
    /// This excludes options that only affect rendering (like opacity)
    /// and focuses on options that change the generated path data.
    var cacheHash: Int {
        var hasher = Hasher()
        
        // Core shape parameters
        hasher.combine(maxRandomnessOffset)
        hasher.combine(roughness)
        hasher.combine(bowing)
        hasher.combine(strokeWidth)
        hasher.combine(curveTightness)
        hasher.combine(curveStepCount)
        
        // Fill style parameters
        hasher.combine(fillStyle.rawValue)
        hasher.combine(fillWeight)
        hasher.combine(fillAngle)
        hasher.combine(fillSpacing)
        hasher.combine(dashOffset)
        hasher.combine(dashGap)
        hasher.combine(zigzagOffset)
        
        // Fill spacing pattern (if any)
        if let pattern = fillSpacingPattern {
            for value in pattern {
                hasher.combine(value)
            }
        }
        
        return hasher.finalize()
    }
}

// MARK: - Cache Entry

/// A cached drawing with metadata for cache management.
struct CacheEntry {
    /// The cached drawing.
    let drawing: Drawing
    
    /// When this entry was last accessed.
    var lastAccessed: Date
    
    /// Number of times this entry has been accessed.
    var accessCount: Int
    
    init(drawing: Drawing) {
        self.drawing = drawing
        self.lastAccessed = Date()
        self.accessCount = 1
    }
    
    mutating func recordAccess() {
        lastAccessed = Date()
        accessCount += 1
    }
}

// MARK: - Drawing Cache

/// Thread-safe cache for generated drawings.
///
/// This cache stores the results of rough.js drawing generation to avoid
/// repeated expensive JavaScript bridge calls. The cache uses LRU eviction
/// when it exceeds its maximum size.
@MainActor
public final class DrawingCache {
    
    /// Shared singleton instance.
    public static let shared = DrawingCache()
    
    /// Maximum number of entries before eviction.
    private let maxEntries: Int
    
    /// The cache storage.
    private var cache: [DrawingCacheKey: CacheEntry] = [:]
    
    /// Statistics for debugging/monitoring.
    private(set) var hits: Int = 0
    private(set) var misses: Int = 0
    
    /// Creates a new drawing cache.
    ///
    /// - Parameter maxEntries: Maximum number of cached drawings. Default is 100.
    public init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }
    
    /// Retrieves a cached drawing if available.
    ///
    /// - Parameter key: The cache key.
    /// - Returns: The cached drawing, or nil if not found.
    public func get(_ key: DrawingCacheKey) -> Drawing? {
        if var entry = cache[key] {
            hits += 1
            entry.recordAccess()
            cache[key] = entry
            return entry.drawing
        }
        misses += 1
        return nil
    }
    
    /// Stores a drawing in the cache.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - drawing: The drawing to cache.
    public func set(_ key: DrawingCacheKey, drawing: Drawing) {
        // Evict if necessary
        if cache.count >= maxEntries {
            evictLRU()
        }
        
        cache[key] = CacheEntry(drawing: drawing)
    }
    
    /// Retrieves a drawing from cache, or generates and caches it if not present.
    ///
    /// - Parameters:
    ///   - key: The cache key.
    ///   - generator: Closure to generate the drawing if not cached.
    /// - Returns: The drawing (from cache or newly generated).
    public func getOrGenerate(_ key: DrawingCacheKey, generator: () -> Drawing?) -> Drawing? {
        if let cached = get(key) {
            return cached
        }
        
        if let drawing = generator() {
            set(key, drawing: drawing)
            return drawing
        }
        
        return nil
    }
    
    /// Clears all cached drawings.
    public func clear() {
        cache.removeAll()
        hits = 0
        misses = 0
    }
    
    /// Returns cache statistics.
    public var stats: (entries: Int, hits: Int, misses: Int, hitRate: Double) {
        let total = hits + misses
        let hitRate = total > 0 ? Double(hits) / Double(total) : 0
        return (cache.count, hits, misses, hitRate)
    }
    
    // MARK: - Private
    
    /// Evicts the least recently used entries.
    private func evictLRU() {
        // Remove 25% of entries (the least recently used)
        let entriesToRemove = max(1, maxEntries / 4)
        
        let sortedKeys = cache.keys.sorted { key1, key2 in
            guard let entry1 = cache[key1], let entry2 = cache[key2] else {
                return false
            }
            return entry1.lastAccessed < entry2.lastAccessed
        }
        
        for key in sortedKeys.prefix(entriesToRemove) {
            cache.removeValue(forKey: key)
        }
    }
}

// MARK: - Generator Cache

/// Cache for Generator instances by canvas size.
///
/// Generators are relatively expensive to create since they involve
/// JavaScript context method calls. This cache reuses generators
/// for the same canvas size.
@MainActor
public final class GeneratorCache {
    
    /// Shared singleton instance.
    public static let shared = GeneratorCache()
    
    /// Maximum number of cached generators.
    private let maxEntries: Int
    
    /// Cache storage keyed by rounded size.
    private var cache: [SizeKey: GeneratorEntry] = [:]
    
    /// Size key for consistent hashing.
    private struct SizeKey: Hashable {
        let width: Int
        let height: Int
        
        init(_ size: CGSize) {
            self.width = Int(size.width.rounded())
            self.height = Int(size.height.rounded())
        }
        
        var cgSize: CGSize {
            CGSize(width: width, height: height)
        }
    }
    
    /// Cache entry with access tracking.
    private struct GeneratorEntry {
        let generator: Generator
        var lastAccessed: Date
        
        init(generator: Generator) {
            self.generator = generator
            self.lastAccessed = Date()
        }
        
        mutating func recordAccess() {
            lastAccessed = Date()
        }
    }
    
    /// Creates a new generator cache.
    ///
    /// - Parameter maxEntries: Maximum number of cached generators. Default is 10.
    public init(maxEntries: Int = 10) {
        self.maxEntries = maxEntries
    }
    
    /// Gets or creates a generator for the given size.
    ///
    /// - Parameters:
    ///   - size: The canvas size.
    ///   - engine: The engine to use for creating new generators.
    /// - Returns: A generator for the requested size.
    public func generator(for size: CGSize, using engine: Engine) -> Generator {
        let key = SizeKey(size)
        
        if var entry = cache[key] {
            entry.recordAccess()
            cache[key] = entry
            return entry.generator
        }
        
        // Evict if necessary
        if cache.count >= maxEntries {
            evictLRU()
        }
        
        // Create new generator
        let generator = engine.createGenerator(size: key.cgSize)
        cache[key] = GeneratorEntry(generator: generator)
        return generator
    }
    
    /// Clears all cached generators.
    public func clear() {
        cache.removeAll()
    }
    
    /// Returns the number of cached generators.
    public var count: Int {
        cache.count
    }
    
    // MARK: - Private
    
    private func evictLRU() {
        guard let oldestKey = cache.min(by: { $0.value.lastAccessed < $1.value.lastAccessed })?.key else {
            return
        }
        cache.removeValue(forKey: oldestKey)
    }
}

