//
//  Generator.swift
//  RoughSwift
//
//  Created by khoa on 19/03/2019.
//  Copyright © 2019 Khoa Pham. All rights reserved.
//

import Foundation

/// Protocol defining the generator interface for rough.js-style drawings.
///
/// Both the native Swift implementation (NativeGenerator) and the legacy
/// JavaScript implementation conform to this protocol.
public protocol RoughGenerator {
    /// The canvas size this generator is configured for.
    var size: CGSize { get }
    
    /// Generates a drawing for the given drawable.
    ///
    /// - Parameters:
    ///   - drawable: The shape to generate.
    ///   - options: Rendering options.
    /// - Returns: The generated drawing, or nil if generation failed.
    func generate(drawable: Drawable, options: Options) -> Drawing?
}

// MARK: - NativeGenerator Conformance

extension NativeGenerator: RoughGenerator {}

// MARK: - Type Alias for Backwards Compatibility

/// Type alias for backwards compatibility.
/// Code that previously used `Generator` will now use `NativeGenerator`.
public typealias Generator = NativeGenerator
