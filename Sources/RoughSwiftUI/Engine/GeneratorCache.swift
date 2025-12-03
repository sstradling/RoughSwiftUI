//
//  GeneratorCache.swift
//  RoughSwift
//
//  Cache for NativeGenerator instances by size.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation
import CoreGraphics

/// Cache for NativeGenerator instances indexed by canvas size.
/// Generators are reused when the same size is requested multiple times.
@MainActor
public final class GeneratorCache {
    
    /// The maximum number of generators to cache.
    private let maxEntries: Int
    
    /// Cached generators by size (rounded to integers).
    private var cache: [CGSize: NativeGenerator] = [:]
    
    /// Access order for LRU eviction.
    private var accessOrder: [CGSize] = []
    
    /// Creates a generator cache with specified capacity.
    /// - Parameter maxEntries: Maximum entries before eviction (default: 10)
    public init(maxEntries: Int = 10) {
        self.maxEntries = maxEntries
    }
    
    /// Returns a generator for the given size, creating one if needed.
    /// - Parameters:
    ///   - size: The canvas size
    ///   - engine: The engine to use for creating new generators (ignored in native implementation)
    /// - Returns: A generator for the specified size
    public func generator(for size: CGSize, using engine: Engine) -> NativeGenerator {
        // Round size to avoid floating point key issues
        let roundedSize = CGSize(
            width: round(size.width),
            height: round(size.height)
        )
        
        if let cached = cache[roundedSize] {
            updateAccessOrder(roundedSize)
            return cached
        }
        
        // Evict if at capacity
        while cache.count >= maxEntries {
            evictLRU()
        }
        
        let newGenerator = NativeGenerator(size: roundedSize)
        cache[roundedSize] = newGenerator
        accessOrder.append(roundedSize)
        return newGenerator
    }
    
    /// Returns the number of cached generators.
    public var count: Int {
        cache.count
    }
    
    /// Clears all cached generators.
    public func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func updateAccessOrder(_ size: CGSize) {
        accessOrder.removeAll { $0 == size }
        accessOrder.append(size)
    }
    
    private func evictLRU() {
        guard let lruKey = accessOrder.first else { return }
        cache.removeValue(forKey: lruKey)
        accessOrder.removeFirst()
    }
}

