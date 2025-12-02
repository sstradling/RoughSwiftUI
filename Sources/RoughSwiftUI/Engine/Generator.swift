//
//  Generator.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import JavaScriptCore

/// Wrapper around a `rough.js` generator bound to a specific canvas size.
///
/// Constrained to the main actor to match `Engine` and SwiftUI's rendering model.
///
/// Generators cache their drawing outputs to avoid repeated JavaScript bridge
/// calls for the same drawable/options combinations.
@MainActor
public final class Generator {
    private let size: CGSize
    private let jsValue: JSValue
    private let drawingCache: DrawingCache?
    
    /// Creates a generator with optional caching.
    ///
    /// - Parameters:
    ///   - size: The canvas size.
    ///   - jsValue: The underlying JavaScript generator object.
    ///   - drawingCache: Optional cache for generated drawings.
    public init(
        size: CGSize,
        jsValue: JSValue,
        drawingCache: DrawingCache? = nil
    ) {
        self.size = size
        self.jsValue = jsValue
        self.drawingCache = drawingCache
    }

    /// Generates a drawing for the given drawable.
    ///
    /// If a drawing cache is configured, this method will return cached results
    /// for identical drawable/options combinations, avoiding repeated JavaScript
    /// bridge calls.
    ///
    /// - Parameters:
    ///   - drawable: The shape to generate.
    ///   - options: Rendering options.
    /// - Returns: The generated drawing, or nil if generation failed.
    public func generate(drawable: Drawable, options: Options = .init()) -> Drawing? {
        // Check cache first
        if let cache = drawingCache {
            let cacheKey = DrawingCacheKey(drawable: drawable, size: size, options: options)
            
            return cache.getOrGenerate(cacheKey) {
                generateUncached(drawable: drawable, options: options)
            }
        }
        
        // No cache, generate directly
        return generateUncached(drawable: drawable, options: options)
    }
    
    /// Generates a drawing without checking the cache.
    ///
    /// This is used internally and by the cache's generator closure.
    private func generateUncached(drawable: Drawable, options: Options) -> Drawing? {
        let arguments: [Any]
        if let fullable = drawable as? Fulfillable {
            arguments = fullable.arguments(size: size.toSize)
        } else {
            arguments = drawable.arguments
        }

        return jsValue.invokeMethod(
            drawable.method,
            withArguments: arguments + [options.toRoughDictionary()]
        ).toDrawing
    }
}

private extension JSValue {
    var toDrawing: Drawing? {
        Drawing(roughDrawing: self)
    }
}

private extension CGSize {
    var toSize: Size {
        Size(width: Float(width), height: Float(height))
    }
}
