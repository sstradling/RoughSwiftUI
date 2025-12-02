//
//  PathVariance.swift
//  RoughSwift
//
//  Created by Cursor on 02/12/2025.
//
//  Applies subtle random variations to paths for animation effects.
//

import SwiftUI

/// Generates seeded random variations for path animation.
struct PathVarianceGenerator {
    /// The variance factor (0.0 to 1.0) controlling the amount of variation.
    let variance: Float
    
    /// Pre-computed offsets for each animation step.
    /// Each step contains a seed value for deterministic random generation.
    let stepSeeds: [UInt64]
    
    /// Creates a variance generator for the given animation config.
    /// - Parameters:
    ///   - config: The animation configuration.
    ///   - baseSeed: A base seed for reproducibility (defaults to random).
    init(config: AnimationConfig, baseSeed: UInt64 = UInt64.random(in: 0..<UInt64.max)) {
        self.variance = config.variance.factor
        
        // Generate deterministic seeds for each step
        var seeds: [UInt64] = []
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
    func applyVariance(to point: CGPoint, step: Int, index: Int) -> CGPoint {
        let seed = stepSeeds[step % stepSeeds.count]
        
        // Use simple deterministic pseudo-random based on seed and index
        let hash1 = (seed &+ UInt64(index) &* 0x517CC1B727220A95)
        let hash2 = (seed &+ UInt64(index + 1000) &* 0x517CC1B727220A95)
        
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
}

/// Extension to apply variance to SwiftUI paths.
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

/// Extension to apply variance to render commands.
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
            inverseClip: inverseClip
        )
    }
}

