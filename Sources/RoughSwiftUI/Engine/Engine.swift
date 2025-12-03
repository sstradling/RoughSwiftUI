//
//  Engine.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import UIKit
import JavaScriptCore
import os.signpost

public typealias JSONDictionary = [String: Any]
public typealias JSONArray = [JSONDictionary]

/// Main entry point for interacting with the underlying `rough.js` engine.
///
/// This type is annotated with `@MainActor` to ensure all JavaScriptCore work
/// happens on the main thread, which matches SwiftUI's rendering model.
@MainActor
public final class Engine {
    private let context: JSContext
    private let rough: JSValue
    
    /// Cache for generators by size (avoids repeated JS calls).
    private let generatorCache = GeneratorCache()
    
    /// Cache for generated drawings (avoids repeated JS generation).
    private let drawingCache = DrawingCache()
    
    public static let shared = Engine()

    public init() {
        guard let context = JSContext() else {
            fatalError("RoughSwiftUI.Engine failed to create JSContext")
        }
        self.context = context

        // Capture JavaScript exceptions emitted by rough.js
        context.exceptionHandler = { _, exception in
            if let message = exception?.toString() {
                print("RoughSwiftUI.Engine JavaScript exception: \(message)")
            }
        }

        let bundle = Bundle.module
        guard let path = bundle.url(forResource: "rough", withExtension: "js") else {
            fatalError("RoughSwiftUI.Engine could not locate rough.js in the module bundle")
        }

        do {
            let content = try String(contentsOf: path)
            context.evaluateScript(content)
        } catch {
            fatalError("RoughSwiftUI.Engine failed to load rough.js: \(error)")
        }

        guard let rough = context.objectForKeyedSubscript("rough") else {
            fatalError("RoughSwiftUI.Engine could not find `rough` global after evaluating rough.js")
        }

        self.rough = rough
    }

    /// Returns a cached `Generator` for the given canvas size.
    ///
    /// Generators are cached by size to avoid repeated JavaScript context calls.
    /// The cache automatically evicts old entries when it reaches capacity.
    ///
    /// - Parameter size: The drawing surface size.
    /// - Returns: A generator for the requested size.
    public func generator(size: CGSize) -> Generator {
        generatorCache.generator(for: size, using: self)
    }
    
    /// Creates a new `Generator` without caching.
    ///
    /// This is used internally by the GeneratorCache. Most code should use
    /// `generator(size:)` instead to benefit from caching.
    ///
    /// - Parameter size: The drawing surface size.
    /// - Returns: A new generator instance.
    internal func createGenerator(size: CGSize) -> Generator {
        measurePerformance(GenerationSignpost.createGenerator, log: RoughPerformanceLog.generation, metadata: "\(Int(size.width))x\(Int(size.height))") {
            let drawingSurface: JSONDictionary = [
                "width": size.width,
                "height": size.height
            ]

            guard let value = rough.invokeMethod("generator", withArguments: [drawingSurface]) else {
                fatalError("RoughSwiftUI.Engine failed to create rough.js generator")
            }

            return Generator(size: size, jsValue: value, drawingCache: drawingCache)
        }
    }
    
    /// Clears all cached generators and drawings.
    ///
    /// Call this when memory pressure is detected or when starting a new
    /// drawing session.
    public func clearCaches() {
        generatorCache.clear()
        drawingCache.clear()
    }
    
    /// Returns cache statistics for debugging.
    public var cacheStats: (generators: Int, drawings: Int, hitRate: Double) {
        let drawingStats = drawingCache.stats
        return (generatorCache.count, drawingStats.entries, drawingStats.hitRate)
    }
}
