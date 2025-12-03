//
//  Engine.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//
//  Modifications Copyright © 2025 Seth Stradling. All rights reserved.
//

import UIKit

public typealias JSONDictionary = [String: Any]
public typealias JSONArray = [JSONDictionary]

/// Main entry point for creating rough.js-style drawings.
///
/// This type is annotated with `@MainActor` to ensure all drawing operations
/// happen on the main thread, which matches SwiftUI's rendering model.
///
/// The engine now uses a native Swift implementation instead of JavaScriptCore,
/// providing significantly improved performance.
@MainActor
public final class Engine {
    
    /// Cache for generators by size (avoids repeated allocations).
    private var generatorCache: [CGSize: NativeGenerator] = [:]
    
    /// Maximum number of cached generators.
    private let maxCachedGenerators = 10
    
    /// Cache for generated drawings.
    public let drawingCache = DrawingCache()
    
    /// Shared singleton instance.
    public static let shared = Engine()
    
    public init() {
        // Native engine requires no initialization
    }
    
    /// Returns a cached `NativeGenerator` for the given canvas size.
    ///
    /// Generators are cached by size to avoid repeated allocations.
    /// The cache automatically evicts old entries when it reaches capacity.
    ///
    /// - Parameter size: The drawing surface size.
    /// - Returns: A generator for the requested size.
    public func generator(size: CGSize) -> NativeGenerator {
        // Round size to avoid floating point key issues
        let roundedSize = CGSize(
            width: round(size.width * 10) / 10,
            height: round(size.height * 10) / 10
        )
        
        if let cached = generatorCache[roundedSize] {
            return cached
        }
        
        // Evict if at capacity
        if generatorCache.count >= maxCachedGenerators {
            generatorCache.removeAll()
        }
        
        let newGenerator = NativeGenerator(size: roundedSize, drawingCache: drawingCache)
        generatorCache[roundedSize] = newGenerator
        return newGenerator
    }
    
    /// Generates a drawing for the given drawable, using the cache.
    ///
    /// This is a convenience method that combines generator creation and
    /// drawing generation with caching.
    ///
    /// - Parameters:
    ///   - drawable: The shape to generate.
    ///   - options: Rendering options.
    ///   - size: The canvas size.
    /// - Returns: The generated drawing, or nil if generation failed.
    public func generate(drawable: Drawable, options: Options, size: CGSize) -> Drawing? {
        let gen = generator(size: size)
        return drawingCache.getOrGenerate(
            drawable: drawable,
            options: options,
            size: size,
            generator: gen
        )
    }
    
    /// Clears all cached generators and drawings.
    ///
    /// Call this when memory pressure is detected or when starting a new
    /// drawing session.
    public func clearCaches() {
        generatorCache.removeAll()
        drawingCache.clear()
    }
    
    /// Returns cache statistics for debugging.
    public var cacheStats: (generators: Int, drawings: Int, hitRate: Double) {
        let drawingStats = drawingCache.stats
        return (generatorCache.count, drawingStats.entries, drawingStats.hitRate)
    }
}

// MARK: - Generator Cache Size Extension

extension CGSize: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
    }
}
