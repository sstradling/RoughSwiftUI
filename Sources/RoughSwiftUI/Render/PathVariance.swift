//
//  PathVariance.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Applies subtle random variations to paths for animation effects.
//

import SwiftUI

// MARK: - Path Element Representation

/// A pre-extracted path element for efficient variance application.
///
/// By extracting elements once, we avoid repeated Path iteration
/// when computing multiple animation frames.
enum ExtractedPathElement {
    case move(CGPoint)
    case line(CGPoint)
    case quadCurve(to: CGPoint, control: CGPoint)
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case close
    
    /// Number of points that need variance applied.
    var pointCount: Int {
        switch self {
        case .move, .line: return 1
        case .quadCurve: return 2
        case .curve: return 3
        case .close: return 0
        }
    }
}

/// A pre-extracted path with elements stored for efficient reuse.
struct ExtractedPath {
    /// The extracted elements.
    let elements: [ExtractedPathElement]
    
    /// Total number of points (for variance indexing).
    let totalPointCount: Int
    
    /// Extracts elements from a SwiftUI path.
    init(from path: SwiftUI.Path) {
        var elements: [ExtractedPathElement] = []
        var pointCount = 0
        
        path.forEach { element in
            switch element {
            case .move(to: let point):
                elements.append(.move(point))
                pointCount += 1
            case .line(to: let point):
                elements.append(.line(point))
                pointCount += 1
            case .quadCurve(to: let point, control: let control):
                elements.append(.quadCurve(to: point, control: control))
                pointCount += 2
            case .curve(to: let point, control1: let c1, control2: let c2):
                elements.append(.curve(to: point, control1: c1, control2: c2))
                pointCount += 3
            case .closeSubpath:
                elements.append(.close)
            }
        }
        
        self.elements = elements
        self.totalPointCount = pointCount
    }
    
    /// Builds a new path with variance applied using the generator.
    func buildPath(generator: PathVarianceGenerator, step: Int) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        var pointIndex = 0
        
        for element in elements {
            switch element {
            case .move(let point):
                let varied = generator.applyVariance(to: point, step: step, index: pointIndex)
                path.move(to: varied)
                pointIndex += 1
                
            case .line(let point):
                let varied = generator.applyVariance(to: point, step: step, index: pointIndex)
                path.addLine(to: varied)
                pointIndex += 1
                
            case .quadCurve(let point, let control):
                let variedPoint = generator.applyVariance(to: point, step: step, index: pointIndex)
                let variedControl = generator.applyVariance(to: control, step: step, index: pointIndex + 1)
                path.addQuadCurve(to: variedPoint, control: variedControl)
                pointIndex += 2
                
            case .curve(let point, let control1, let control2):
                let variedPoint = generator.applyVariance(to: point, step: step, index: pointIndex)
                let variedC1 = generator.applyVariance(to: control1, step: step, index: pointIndex + 1)
                let variedC2 = generator.applyVariance(to: control2, step: step, index: pointIndex + 2)
                path.addCurve(to: variedPoint, control1: variedC1, control2: variedC2)
                pointIndex += 3
                
            case .close:
                path.closeSubpath()
            }
        }
        
        return path
    }
}

// MARK: - Variance Generator

/// Generates seeded random variations for path animation.
///
/// The generator uses deterministic pseudo-random values based on a seed,
/// ensuring consistent results across animation cycles.
struct PathVarianceGenerator {
    /// The variance factor (0.0 to 1.0) controlling the amount of variation.
    let variance: Float
    
    /// Pre-computed offsets for each animation step.
    /// Each step contains a seed value for deterministic random generation.
    let stepSeeds: [UInt64]
    
    /// Number of animation steps.
    var stepCount: Int { stepSeeds.count }
    
    /// Creates a variance generator for the given animation config.
    /// - Parameters:
    ///   - config: The animation configuration.
    ///   - baseSeed: A base seed for reproducibility (defaults to random).
    init(config: AnimationConfig, baseSeed: UInt64 = UInt64.random(in: 0..<UInt64.max)) {
        self.variance = config.variance.factor
        
        // Generate deterministic seeds for each step
        var seeds: [UInt64] = []
        seeds.reserveCapacity(config.steps)
        for i in 0..<config.steps {
            seeds.append(baseSeed &+ UInt64(i) &* 0x9E3779B97F4A7C15)
        }
        self.stepSeeds = seeds
    }
    
    /// Applies variance to a CGPoint using the given step index.
    /// - Parameters:
    ///   - point: The original point.
    ///   - step: The current animation step.
    ///   - index: An index to vary the randomness per point.
    /// - Returns: The point with variance applied.
    @inline(__always)
    func applyVariance(to point: CGPoint, step: Int, index: Int) -> CGPoint {
        guard variance > 0 else { return point }
        
        let seed = stepSeeds[step % stepSeeds.count]
        
        // Use simple deterministic pseudo-random based on seed and index
        // Golden ratio hashing for better distribution
        let hash1 = seed &+ UInt64(truncatingIfNeeded: index) &* 0x517CC1B727220A95
        let hash2 = seed &+ UInt64(truncatingIfNeeded: index + 1000) &* 0x517CC1B727220A95
        
        // Convert to float in range [-1, 1]
        let rand1 = Float(Int64(bitPattern: hash1 % 2000000)) / 1000000.0 - 1.0
        let rand2 = Float(Int64(bitPattern: hash2 % 2000000)) / 1000000.0 - 1.0
        
        // Apply variance based on point magnitude for scale-independent variation
        let magnitude = max(abs(Float(point.x)), abs(Float(point.y)), 10.0)
        let offset = magnitude * variance
        
        return CGPoint(
            x: point.x + CGFloat(rand1 * offset),
            y: point.y + CGFloat(rand2 * offset)
        )
    }
    
    /// Pre-computes varied paths for all animation steps.
    ///
    /// This is more efficient than calling `withVariance` multiple times
    /// because the path is only extracted once.
    ///
    /// - Parameters:
    ///   - path: The source path.
    /// - Returns: Array of varied paths, one for each animation step.
    func precomputeAllSteps(for path: SwiftUI.Path) -> [SwiftUI.Path] {
        let extracted = ExtractedPath(from: path)
        
        return (0..<stepCount).map { step in
            extracted.buildPath(generator: self, step: step)
        }
    }
}

// MARK: - Path Extension

extension SwiftUI.Path {
    /// Creates a new path with variance applied to all points.
    /// - Parameters:
    ///   - generator: The variance generator to use.
    ///   - step: The current animation step.
    /// - Returns: A new path with variance applied.
    func withVariance(generator: PathVarianceGenerator, step: Int) -> SwiftUI.Path {
        var newPath = SwiftUI.Path()
        var pointIndex = 0
        
        self.forEach { element in
            switch element {
            case .move(to: let point):
                let variedPoint = generator.applyVariance(to: point, step: step, index: pointIndex)
                newPath.move(to: variedPoint)
                pointIndex += 1
                
            case .line(to: let point):
                let variedPoint = generator.applyVariance(to: point, step: step, index: pointIndex)
                newPath.addLine(to: variedPoint)
                pointIndex += 1
                
            case .quadCurve(to: let point, control: let control):
                let variedPoint = generator.applyVariance(to: point, step: step, index: pointIndex)
                let variedControl = generator.applyVariance(to: control, step: step, index: pointIndex + 1)
                newPath.addQuadCurve(to: variedPoint, control: variedControl)
                pointIndex += 2
                
            case .curve(to: let point, control1: let control1, control2: let control2):
                let variedPoint = generator.applyVariance(to: point, step: step, index: pointIndex)
                let variedControl1 = generator.applyVariance(to: control1, step: step, index: pointIndex + 1)
                let variedControl2 = generator.applyVariance(to: control2, step: step, index: pointIndex + 2)
                newPath.addCurve(to: variedPoint, control1: variedControl1, control2: variedControl2)
                pointIndex += 3
                
            case .closeSubpath:
                newPath.closeSubpath()
            }
        }
        
        return newPath
    }
}

// MARK: - RoughRenderCommand Extension

extension RoughRenderCommand {
    /// Creates a new command with variance applied to the path.
    /// - Parameters:
    ///   - generator: The variance generator to use.
    ///   - step: The current animation step.
    /// - Returns: A new command with variance applied.
    func withVariance(generator: PathVarianceGenerator, step: Int) -> RoughRenderCommand {
        let variedPath = path.withVariance(generator: generator, step: step)
        let variedClipPath = clipPath?.withVariance(generator: generator, step: step)
        
        return RoughRenderCommand(
            path: variedPath,
            style: style,
            clipPath: variedClipPath,
            inverseClip: inverseClip,
            cap: cap,
            join: join
        )
    }
    
    /// Pre-computes varied commands for all animation steps.
    ///
    /// More efficient than calling `withVariance` multiple times
    /// when you need all frames upfront.
    ///
    /// - Parameter generator: The variance generator to use.
    /// - Returns: Array of varied commands, one for each animation step.
    func precomputeAllSteps(generator: PathVarianceGenerator) -> [RoughRenderCommand] {
        // Extract paths once
        let extractedPath = ExtractedPath(from: path)
        let extractedClipPath = clipPath.map { ExtractedPath(from: $0) }
        
        return (0..<generator.stepCount).map { step in
            let variedPath = extractedPath.buildPath(generator: generator, step: step)
            let variedClipPath = extractedClipPath?.buildPath(generator: generator, step: step)
            
            return RoughRenderCommand(
                path: variedPath,
                style: style,
                clipPath: variedClipPath,
                inverseClip: inverseClip,
                cap: cap,
                join: join
            )
        }
    }
}
