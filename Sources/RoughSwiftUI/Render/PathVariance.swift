//
//  PathVariance.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Applies subtle random variations to paths for animation effects.
//
//  ## Performance Architecture
//
//  This module uses a two-tier caching strategy for animation:
//
//  1. **ExtractedPath**: Extracts path elements once to avoid repeated iteration
//  2. **PrecomputedVarianceOffsets**: Stores only X/Y offsets per step, not full paths
//
//  During animation, paths are reconstructed from:
//  `original_point + precomputed_offset[step][point_index]`
//
//  This is faster and more memory-efficient than storing full `SwiftUI.Path` objects
//  for each animation frame.
//

import SwiftUI
import simd

// MARK: - SIMD-Optimized Point Storage

/// A contiguous array of 2D points stored for SIMD-friendly access.
///
/// Points are stored as alternating X,Y values for cache-friendly iteration.
/// This allows vectorized operations when applying variance.
struct ContiguousPointArray {
    /// Interleaved X,Y values: [x0, y0, x1, y1, ...]
    private(set) var values: [CGFloat]
    
    /// Number of points stored.
    var count: Int { values.count / 2 }
    
    /// Creates an empty array with reserved capacity.
    init(capacity: Int = 0) {
        values = []
        values.reserveCapacity(capacity * 2)
    }
    
    /// Appends a point.
    @inline(__always)
    mutating func append(_ point: CGPoint) {
        values.append(point.x)
        values.append(point.y)
    }
    
    /// Gets the point at index.
    @inline(__always)
    func point(at index: Int) -> CGPoint {
        let i = index * 2
        return CGPoint(x: values[i], y: values[i + 1])
    }
    
    /// Sets the point at index.
    @inline(__always)
    mutating func setPoint(_ point: CGPoint, at index: Int) {
        let i = index * 2
        values[i] = point.x
        values[i + 1] = point.y
    }
    
    /// Adds offsets to all points, storing result in destination.
    /// Uses vectorized operations when possible.
    @inline(__always)
    func addingOffsets(_ offsets: ContiguousPointArray, into destination: inout ContiguousPointArray) {
        let count = values.count
        destination.values.removeAll(keepingCapacity: true)
        destination.values.reserveCapacity(count)
        
        // Process in chunks of 4 for potential SIMD optimization
        var i = 0
        while i + 4 <= count {
            destination.values.append(values[i] + offsets.values[i])
            destination.values.append(values[i + 1] + offsets.values[i + 1])
            destination.values.append(values[i + 2] + offsets.values[i + 2])
            destination.values.append(values[i + 3] + offsets.values[i + 3])
            i += 4
        }
        
        // Handle remainder
        while i < count {
            destination.values.append(values[i] + offsets.values[i])
            i += 1
        }
    }
}

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

/// A compact representation of path structure for fast reconstruction.
///
/// Stores element types separately from point data for cache-friendly access.
struct CompactPathStructure {
    /// Element types in order (no point data).
    let elementTypes: [UInt8]
    
    /// Original points stored contiguously.
    let originalPoints: ContiguousPointArray
    
    /// Mapping from element index to starting point index.
    let elementPointOffsets: [Int]
    
    /// Total number of points.
    var pointCount: Int { originalPoints.count }
    
    /// Creates from extracted path elements.
    init(elements: [ExtractedPathElement]) {
        var types: [UInt8] = []
        var points = ContiguousPointArray(capacity: elements.count * 2)
        var offsets: [Int] = []
        
        types.reserveCapacity(elements.count)
        offsets.reserveCapacity(elements.count)
        
        for element in elements {
            offsets.append(points.count)
            
            switch element {
            case .move(let p):
                types.append(0)
                points.append(p)
            case .line(let p):
                types.append(1)
                points.append(p)
            case .quadCurve(let to, let control):
                types.append(2)
                points.append(to)
                points.append(control)
            case .curve(let to, let c1, let c2):
                types.append(3)
                points.append(to)
                points.append(c1)
                points.append(c2)
            case .close:
                types.append(4)
            }
        }
        
        self.elementTypes = types
        self.originalPoints = points
        self.elementPointOffsets = offsets
    }
    
    /// Builds a SwiftUI path from varied points.
    func buildPath(from variedPoints: ContiguousPointArray) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        
        for (elementIndex, elementType) in elementTypes.enumerated() {
            let pointOffset = elementPointOffsets[elementIndex]
            
            switch elementType {
            case 0: // move
                path.move(to: variedPoints.point(at: pointOffset))
            case 1: // line
                path.addLine(to: variedPoints.point(at: pointOffset))
            case 2: // quadCurve
                path.addQuadCurve(
                    to: variedPoints.point(at: pointOffset),
                    control: variedPoints.point(at: pointOffset + 1)
                )
            case 3: // curve
                path.addCurve(
                    to: variedPoints.point(at: pointOffset),
                    control1: variedPoints.point(at: pointOffset + 1),
                    control2: variedPoints.point(at: pointOffset + 2)
                )
            case 4: // close
                path.closeSubpath()
            default:
                break
            }
        }
        
        return path
    }
}

// MARK: - Pre-computed Variance Cache

/// Pre-computed variance offsets for all animation steps.
///
/// This stores only the delta values (offsets) for each animation step,
/// not full paths. This is more memory-efficient and allows fast
/// path reconstruction: `original_point + offset[step][point]`
struct PrecomputedVarianceOffsets: Sendable {
    /// Offsets for each step, stored as contiguous point arrays.
    /// offsets[step] contains X,Y offsets for all points in that step.
    let offsets: [ContiguousPointArray]
    
    /// Number of animation steps.
    var stepCount: Int { offsets.count }
    
    /// Creates empty offsets.
    static var empty: PrecomputedVarianceOffsets {
        PrecomputedVarianceOffsets(offsets: [])
    }
    
    /// Pre-computes variance offsets for all steps.
    ///
    /// This is the main performance optimization: we compute all random
    /// offsets once, then just add them to original points during animation.
    ///
    /// - Parameters:
    ///   - pointCount: Number of points in the path.
    ///   - generator: The variance generator with step seeds.
    ///   - originalPoints: The original point positions (for magnitude calculation).
    /// - Returns: Pre-computed offsets for all steps.
    static func precompute(
        pointCount: Int,
        generator: PathVarianceGenerator,
        originalPoints: ContiguousPointArray
    ) -> PrecomputedVarianceOffsets {
        guard pointCount > 0, generator.variance > 0 else {
            // No variance needed - return zero offsets
            let zeroOffsets = ContiguousPointArray(capacity: pointCount)
            return PrecomputedVarianceOffsets(offsets: Array(repeating: zeroOffsets, count: generator.stepCount))
        }
        
        var allOffsets: [ContiguousPointArray] = []
        allOffsets.reserveCapacity(generator.stepCount)
        
        for step in 0..<generator.stepCount {
            var stepOffsets = ContiguousPointArray(capacity: pointCount)
            
            for pointIndex in 0..<pointCount {
                let original = originalPoints.point(at: pointIndex)
                let offset = generator.computeOffset(for: original, step: step, index: pointIndex)
                stepOffsets.append(offset)
            }
            
            allOffsets.append(stepOffsets)
        }
        
        return PrecomputedVarianceOffsets(offsets: allOffsets)
    }
}

/// Complete pre-computed variance data for a single path.
///
/// Contains both the path structure and pre-computed offsets for all steps.
/// This allows O(1) path reconstruction for any animation step.
struct PrecomputedPathVariance {
    /// The compact path structure (element types + original points).
    let structure: CompactPathStructure
    
    /// Pre-computed offsets for each animation step.
    let offsets: PrecomputedVarianceOffsets
    
    /// Temporary buffer for varied points (reused across builds).
    private var variedPointsBuffer: ContiguousPointArray
    
    /// Number of animation steps.
    var stepCount: Int { offsets.stepCount }
    
    /// Creates pre-computed variance from a path.
    init(from path: SwiftUI.Path, generator: PathVarianceGenerator) {
        let extracted = ExtractedPath(from: path)
        self.structure = CompactPathStructure(elements: extracted.elements)
        self.offsets = PrecomputedVarianceOffsets.precompute(
            pointCount: structure.pointCount,
            generator: generator,
            originalPoints: structure.originalPoints
        )
        self.variedPointsBuffer = ContiguousPointArray(capacity: structure.pointCount)
    }
    
    /// Builds the path for a specific animation step.
    ///
    /// This is very fast because we just:
    /// 1. Add pre-computed offsets to original points
    /// 2. Build path from the varied points
    ///
    /// - Parameter step: The animation step (0 to stepCount-1).
    /// - Returns: The path with variance applied for this step.
    mutating func buildPath(forStep step: Int) -> SwiftUI.Path {
        guard step < offsets.stepCount else {
            return structure.buildPath(from: structure.originalPoints)
        }
        
        // Add offsets to original points
        structure.originalPoints.addingOffsets(offsets.offsets[step], into: &variedPointsBuffer)
        
        // Build path from varied points
        return structure.buildPath(from: variedPointsBuffer)
    }
    
    /// Pre-builds all paths for all steps.
    ///
    /// Use this when you want to avoid any computation during animation playback.
    /// More memory usage, but zero computation during animation.
    func prebuiltPaths() -> [SwiftUI.Path] {
        var mutableSelf = self
        return (0..<stepCount).map { step in
            mutableSelf.buildPath(forStep: step)
        }
    }
}

// MARK: - Legacy ExtractedPath (for backward compatibility)

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
///
/// ## Performance Tips
///
/// For best animation performance, use `precomputeVariance(for:)` to get a
/// `PrecomputedPathVariance` which stores only offsets and reconstructs paths
/// on-demand with minimal computation.
struct PathVarianceGenerator {
    /// The variance factor (0.0 to 1.0) controlling the amount of variation.
    let variance: Float
    
    /// Pre-computed seeds for each animation step.
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
    
    /// Computes the variance offset for a point (not the final position).
    ///
    /// This returns the delta that should be added to the original point,
    /// used for pre-computing offsets.
    ///
    /// - Parameters:
    ///   - point: The original point (used for magnitude calculation).
    ///   - step: The animation step.
    ///   - index: The point index for randomness variation.
    /// - Returns: The offset (dx, dy) to add to the original point.
    @inline(__always)
    func computeOffset(for point: CGPoint, step: Int, index: Int) -> CGPoint {
        guard variance > 0 else { return .zero }
        
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
            x: CGFloat(rand1 * offset),
            y: CGFloat(rand2 * offset)
        )
    }
    
    /// Applies variance to a CGPoint using the given step index.
    /// - Parameters:
    ///   - point: The original point.
    ///   - step: The current animation step.
    ///   - index: An index to vary the randomness per point.
    /// - Returns: The point with variance applied.
    @inline(__always)
    func applyVariance(to point: CGPoint, step: Int, index: Int) -> CGPoint {
        let offset = computeOffset(for: point, step: step, index: index)
        return CGPoint(x: point.x + offset.x, y: point.y + offset.y)
    }
    
    /// Creates pre-computed variance data for a path.
    ///
    /// This is the recommended way to prepare paths for animation.
    /// The returned `PrecomputedPathVariance` stores only offsets,
    /// making frame reconstruction very fast.
    ///
    /// - Parameter path: The source path.
    /// - Returns: Pre-computed variance data for all animation steps.
    func precomputeVariance(for path: SwiftUI.Path) -> PrecomputedPathVariance {
        PrecomputedPathVariance(from: path, generator: self)
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

// MARK: - Optimized Pre-computed Command Variance

/// Pre-computed variance data for a single render command.
///
/// Stores the pre-computed variance for both the main path and optional clip path,
/// allowing fast path reconstruction for any animation step.
struct PrecomputedCommandVariance {
    /// Pre-computed variance for the main path.
    private var pathVariance: PrecomputedPathVariance
    
    /// Pre-computed variance for the clip path (if any).
    private var clipPathVariance: PrecomputedPathVariance?
    
    /// The original command's style.
    let style: RoughRenderCommand.Style
    
    /// Whether to use inverse clipping.
    let inverseClip: Bool
    
    /// Stroke cap style.
    let cap: BrushCap
    
    /// Stroke join style.
    let join: BrushJoin
    
    /// Number of animation steps.
    var stepCount: Int { pathVariance.stepCount }
    
    /// Creates pre-computed variance for a command.
    init(from command: RoughRenderCommand, generator: PathVarianceGenerator) {
        self.pathVariance = PrecomputedPathVariance(from: command.path, generator: generator)
        self.clipPathVariance = command.clipPath.map {
            PrecomputedPathVariance(from: $0, generator: generator)
        }
        self.style = command.style
        self.inverseClip = command.inverseClip
        self.cap = command.cap
        self.join = command.join
    }
    
    /// Builds the command for a specific animation step.
    ///
    /// - Parameter step: The animation step.
    /// - Returns: The command with variance applied for this step.
    mutating func buildCommand(forStep step: Int) -> RoughRenderCommand {
        let variedPath = pathVariance.buildPath(forStep: step)
        let variedClipPath = clipPathVariance?.buildPath(forStep: step)
        
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

// MARK: - Optimized Animation Frame Cache

/// Optimized cache for pre-computed animation frames.
///
/// This version stores `PrecomputedCommandVariance` instead of full paths,
/// reducing memory usage significantly for complex animations.
/// Paths are reconstructed on-demand with minimal computation.
struct OptimizedAnimationFrameCache {
    /// Pre-computed variance data for each command.
    private var commandVariances: [PrecomputedCommandVariance]
    
    /// The size this cache was computed for.
    let size: CGSize
    
    /// Number of animation steps.
    var stepCount: Int {
        commandVariances.first?.stepCount ?? 0
    }
    
    /// Number of commands.
    var commandCount: Int { commandVariances.count }
    
    /// Whether the cache is empty.
    var isEmpty: Bool { commandVariances.isEmpty }
    
    /// Creates an empty cache.
    static var empty: OptimizedAnimationFrameCache {
        OptimizedAnimationFrameCache(commandVariances: [], size: .zero)
    }
    
    /// Creates a cache from pre-computed command variances.
    private init(commandVariances: [PrecomputedCommandVariance], size: CGSize) {
        self.commandVariances = commandVariances
        self.size = size
    }
    
    /// Pre-computes variance data for all commands.
    ///
    /// This is more memory-efficient than `AnimationFrameCache` because
    /// it stores only variance offsets, not full paths for each frame.
    ///
    /// - Parameters:
    ///   - commands: The base render commands.
    ///   - generator: The variance generator.
    ///   - size: The canvas size.
    /// - Returns: An optimized frame cache.
    static func precompute(
        commands: [RoughRenderCommand],
        generator: PathVarianceGenerator,
        size: CGSize
    ) -> OptimizedAnimationFrameCache {
        let variances = commands.map { command in
            PrecomputedCommandVariance(from: command, generator: generator)
        }
        return OptimizedAnimationFrameCache(commandVariances: variances, size: size)
    }
    
    /// Gets commands for a specific animation step.
    ///
    /// This reconstructs paths from pre-computed offsets, which is very fast.
    ///
    /// - Parameter step: The animation step.
    /// - Returns: Array of commands with variance applied.
    mutating func commands(forStep step: Int) -> [RoughRenderCommand] {
        return commandVariances.indices.map { index in
            commandVariances[index].buildCommand(forStep: step)
        }
    }
    
    /// Pre-builds all frames for all steps.
    ///
    /// Use this if you want to completely eliminate computation during
    /// animation playback. More memory usage, but zero per-frame computation.
    mutating func prebuiltFrames() -> [[RoughRenderCommand]] {
        return (0..<stepCount).map { step in
            commands(forStep: step)
        }
    }
}
