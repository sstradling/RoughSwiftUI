//
//  StrokeToFill.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Converts strokes with variable-width brush profiles into filled paths.
//

import SwiftUI
import CoreGraphics
import os.signpost

// MARK: - Path Sample

/// A sampled point along a path with position and direction information.
struct PathSample {
    /// The position of the sample point.
    let point: CGPoint
    
    /// The tangent direction at this point (in radians).
    let tangentAngle: CGFloat
    
    /// The normalized position along the path (0 = start, 1 = end).
    let t: CGFloat
    
    /// The perpendicular (normal) direction at this point.
    var normalAngle: CGFloat {
        tangentAngle + .pi / 2
    }
}

// MARK: - Stroke To Fill Converter

/// Converts stroke paths into filled paths with variable width based on brush profiles.
///
/// The algorithm:
/// 1. Samples the input path at regular intervals
/// 2. Computes local stroke width at each sample based on brush tip and thickness profile
/// 3. Generates offset points perpendicular to the stroke direction
/// 4. Builds a closed filled path from these offset points
struct StrokeToFillConverter {
    
    /// Minimum number of samples per path segment.
    private static let minSamplesPerSegment = 4
    
    /// Maximum number of samples per segment to prevent excessive computation.
    private static let maxSamplesPerSegment = 64
    
    /// Maximum distance between samples (in points).
    private static let maxSampleSpacing: CGFloat = 4.0
    
    /// Base number of samples per unit of "curviness" for adaptive sampling.
    private static let samplesPerCurvinessUnit: CGFloat = 4.0
    
    // MARK: - Public API
    
    /// Converts a stroke path to a filled outline path.
    ///
    /// - Parameters:
    ///   - path: The source SwiftUI path to convert.
    ///   - baseWidth: The base stroke width.
    ///   - profile: The brush profile to apply.
    /// - Returns: A filled path representing the variable-width stroke.
    static func convert(
        path: SwiftUI.Path,
        baseWidth: CGFloat,
        profile: BrushProfile
    ) -> SwiftUI.Path {
        measurePerformance(PathOpsSignpost.strokeToFill, log: RoughPerformanceLog.pathOps, metadata: "width=\(Int(baseWidth))") {
            // Extract path elements
            let elements = extractElements(from: path)
            guard !elements.isEmpty else { return path }
            
            // Convert elements to subpaths (each starting with a move)
            let subpaths = splitIntoSubpaths(elements)
            
            // Convert each subpath
            var resultPath = SwiftUI.Path()
            for subpath in subpaths {
                if let outlinePath = convertSubpath(
                    subpath,
                    baseWidth: baseWidth,
                    profile: profile
                ) {
                    resultPath.addPath(outlinePath)
                }
            }
            
            return resultPath
        }
    }
    
    /// Converts operations from the engine into a filled outline path.
    ///
    /// - Parameters:
    ///   - operations: Array of engine operations (Move, LineTo, etc.).
    ///   - baseWidth: The base stroke width.
    ///   - profile: The brush profile to apply.
    /// - Returns: A filled path representing the variable-width stroke.
    static func convert(
        operations: [Operation],
        baseWidth: CGFloat,
        profile: BrushProfile
    ) -> SwiftUI.Path {
        measurePerformance(PathOpsSignpost.strokeToFill, log: RoughPerformanceLog.pathOps, metadata: "ops=\(operations.count)") {
            // Convert operations to path elements
            let elements = operationsToElements(operations)
            guard !elements.isEmpty else { return SwiftUI.Path() }
            
            // Convert elements to subpaths
            let subpaths = splitIntoSubpaths(elements)
            
            // Convert each subpath
            var resultPath = SwiftUI.Path()
            for subpath in subpaths {
                if let outlinePath = convertSubpath(
                    subpath,
                    baseWidth: baseWidth,
                    profile: profile
                ) {
                    resultPath.addPath(outlinePath)
                }
            }
            
            return resultPath
        }
    }
    
    // MARK: - Path Element Extraction
    
    /// Path element representation for processing.
    private enum PathElement {
        case move(to: CGPoint)
        case line(to: CGPoint)
        case quadCurve(to: CGPoint, control: CGPoint)
        case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
        case closeSubpath
    }
    
    /// Extracts path elements from a SwiftUI Path.
    private static func extractElements(from path: SwiftUI.Path) -> [PathElement] {
        var elements: [PathElement] = []
        
        path.forEach { element in
            switch element {
            case .move(to: let point):
                elements.append(.move(to: point))
            case .line(to: let point):
                elements.append(.line(to: point))
            case .quadCurve(to: let point, control: let control):
                elements.append(.quadCurve(to: point, control: control))
            case .curve(to: let point, control1: let c1, control2: let c2):
                elements.append(.curve(to: point, control1: c1, control2: c2))
            case .closeSubpath:
                elements.append(.closeSubpath)
            }
        }
        
        return elements
    }
    
    /// Converts engine operations to path elements.
    private static func operationsToElements(_ operations: [Operation]) -> [PathElement] {
        var elements: [PathElement] = []
        
        for op in operations {
            switch op {
            case let move as Move:
                elements.append(.move(to: move.point.cgPoint))
            case let line as LineTo:
                elements.append(.line(to: line.point.cgPoint))
            case let quad as QuadraticCurveTo:
                elements.append(.quadCurve(to: quad.point.cgPoint, control: quad.controlPoint.cgPoint))
            case let curve as BezierCurveTo:
                elements.append(.curve(
                    to: curve.point.cgPoint,
                    control1: curve.controlPoint1.cgPoint,
                    control2: curve.controlPoint2.cgPoint
                ))
            default:
                break
            }
        }
        
        return elements
    }
    
    /// Splits elements into separate subpaths (each starting with a move).
    private static func splitIntoSubpaths(_ elements: [PathElement]) -> [[PathElement]] {
        var subpaths: [[PathElement]] = []
        var currentSubpath: [PathElement] = []
        
        for element in elements {
            switch element {
            case .move:
                if !currentSubpath.isEmpty {
                    subpaths.append(currentSubpath)
                }
                currentSubpath = [element]
            default:
                currentSubpath.append(element)
            }
        }
        
        if !currentSubpath.isEmpty {
            subpaths.append(currentSubpath)
        }
        
        return subpaths
    }
    
    // MARK: - Subpath Conversion
    
    /// Converts a single subpath to a filled outline.
    private static func convertSubpath(
        _ elements: [PathElement],
        baseWidth: CGFloat,
        profile: BrushProfile
    ) -> SwiftUI.Path? {
        // Sample the subpath
        let samples = sampleSubpath(elements)
        guard samples.count >= 2 else { return nil }
        
        // Generate outline points
        let (leftPoints, rightPoints) = generateOutlinePoints(
            samples: samples,
            baseWidth: baseWidth,
            profile: profile
        )
        
        guard !leftPoints.isEmpty, !rightPoints.isEmpty else { return nil }
        
        // Build the filled path
        return buildOutlinePath(
            leftPoints: leftPoints,
            rightPoints: rightPoints,
            cap: profile.cap,
            samples: samples
        )
    }
    
    // MARK: - Path Sampling
    
    /// Intermediate sample with unnormalized accumulated length.
    /// Used during single-pass sampling before normalization.
    private struct RawSample {
        let point: CGPoint
        let tangentAngle: CGFloat
        let accumulatedLength: CGFloat
    }
    
    /// Samples a subpath at regular intervals using a single-pass algorithm.
    ///
    /// Performance optimization: Instead of two passes (one for total length, one for sampling),
    /// this collects samples with accumulated length in one pass, then normalizes t values.
    private static func sampleSubpath(_ elements: [PathElement]) -> [PathSample] {
        // Reserve capacity based on estimated sample count to reduce allocations
        var rawSamples: [RawSample] = []
        rawSamples.reserveCapacity(elements.count * minSamplesPerSegment)
        
        var currentPoint = CGPoint.zero
        var accumulatedLength: CGFloat = 0
        
        // Single pass: collect samples with accumulated length
        for (index, element) in elements.enumerated() {
            switch element {
            case .move(let to):
                currentPoint = to
                // Add starting point with initial tangent computed lazily
                let tangent = computeInitialTangentFast(elements: elements, startIndex: index)
                rawSamples.append(RawSample(point: to, tangentAngle: tangent, accumulatedLength: 0))
                
            case .line(let to):
                let segmentLength = distanceFast(currentPoint, to)
                guard segmentLength > 0 else {
                    currentPoint = to
                    continue
                }
                
                let numSamples = max(2, Int(ceil(segmentLength / maxSampleSpacing)))
                let tangent = atan2(to.y - currentPoint.y, to.x - currentPoint.x)
                
                for i in 1...numSamples {
                    let localT = CGFloat(i) / CGFloat(numSamples)
                    let point = lerpFast(currentPoint, to, t: localT)
                    let sampleAccLength = accumulatedLength + segmentLength * localT
                    rawSamples.append(RawSample(point: point, tangentAngle: tangent, accumulatedLength: sampleAccLength))
                }
                
                accumulatedLength += segmentLength
                currentPoint = to
                
            case .quadCurve(let to, let control):
                let segmentLength = quadCurveLengthFast(from: currentPoint, to: to, control: control)
                guard segmentLength > 0 else {
                    currentPoint = to
                    continue
                }
                
                // Adaptive sampling based on curve complexity
                let numSamples = adaptiveQuadSampleCount(from: currentPoint, to: to, control: control, length: segmentLength)
                
                for i in 1...numSamples {
                    let localT = CGFloat(i) / CGFloat(numSamples)
                    let point = quadraticBezierPoint(from: currentPoint, to: to, control: control, t: localT)
                    let tangent = quadraticBezierTangent(from: currentPoint, to: to, control: control, t: localT)
                    let sampleAccLength = accumulatedLength + segmentLength * localT
                    rawSamples.append(RawSample(point: point, tangentAngle: tangent, accumulatedLength: sampleAccLength))
                }
                
                accumulatedLength += segmentLength
                currentPoint = to
                
            case .curve(let to, let control1, let control2):
                let segmentLength = cubicCurveLengthFast(from: currentPoint, to: to, control1: control1, control2: control2)
                guard segmentLength > 0 else {
                    currentPoint = to
                    continue
                }
                
                // Adaptive sampling based on curve complexity
                let numSamples = adaptiveCubicSampleCount(from: currentPoint, to: to, control1: control1, control2: control2, length: segmentLength)
                
                for i in 1...numSamples {
                    let localT = CGFloat(i) / CGFloat(numSamples)
                    let point = cubicBezierPoint(from: currentPoint, to: to, control1: control1, control2: control2, t: localT)
                    let tangent = cubicBezierTangent(from: currentPoint, to: to, control1: control1, control2: control2, t: localT)
                    let sampleAccLength = accumulatedLength + segmentLength * localT
                    rawSamples.append(RawSample(point: point, tangentAngle: tangent, accumulatedLength: sampleAccLength))
                }
                
                accumulatedLength += segmentLength
                currentPoint = to
                
            case .closeSubpath:
                break
            }
        }
        
        // Total length is now known from the accumulated length
        let totalLength = accumulatedLength
        guard totalLength > 0, !rawSamples.isEmpty else { return [] }
        
        // Normalize t values in a single allocation
        let inverseTotalLength = 1.0 / totalLength
        return rawSamples.map { raw in
            PathSample(
                point: raw.point,
                tangentAngle: raw.tangentAngle,
                t: raw.accumulatedLength * inverseTotalLength
            )
        }
    }
    
    /// Computes the initial tangent direction starting from a specific index.
    /// Optimized version that doesn't need to search from the beginning.
    private static func computeInitialTangentFast(elements: [PathElement], startIndex: Int) -> CGFloat {
        guard startIndex < elements.count,
              case .move(let from) = elements[startIndex] else {
            return 0
        }
        
        for i in (startIndex + 1)..<elements.count {
            switch elements[i] {
            case .line(let to):
                return atan2(to.y - from.y, to.x - from.x)
            case .quadCurve(_, let control):
                return atan2(control.y - from.y, control.x - from.x)
            case .curve(_, let control1, _):
                return atan2(control1.y - from.y, control1.x - from.x)
            case .move:
                // Hit another move before finding a drawing command
                return 0
            case .closeSubpath:
                continue
            }
        }
        
        return 0
    }
    
    
    // MARK: - Outline Generation
    
    /// Generates left and right outline points from samples.
    private static func generateOutlinePoints(
        samples: [PathSample],
        baseWidth: CGFloat,
        profile: BrushProfile
    ) -> (left: [CGPoint], right: [CGPoint]) {
        var leftPoints: [CGPoint] = []
        var rightPoints: [CGPoint] = []
        
        for sample in samples {
            // Calculate thickness at this point
            let thicknessMultiplier = profile.thicknessProfile.multiplier(at: sample.t)
            
            // Calculate effective width based on brush tip and direction
            let effectiveWidth = profile.tip.effectiveWidth(
                baseWidth: baseWidth * thicknessMultiplier,
                strokeAngle: sample.tangentAngle
            )
            
            let halfWidth = effectiveWidth / 2
            
            // Calculate offset points perpendicular to the stroke
            let normalAngle = sample.normalAngle
            let dx = cos(normalAngle) * halfWidth
            let dy = sin(normalAngle) * halfWidth
            
            leftPoints.append(CGPoint(x: sample.point.x + dx, y: sample.point.y + dy))
            rightPoints.append(CGPoint(x: sample.point.x - dx, y: sample.point.y - dy))
        }
        
        return (leftPoints, rightPoints)
    }
    
    /// Builds a closed outline path from left and right points.
    private static func buildOutlinePath(
        leftPoints: [CGPoint],
        rightPoints: [CGPoint],
        cap: BrushCap,
        samples: [PathSample]
    ) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        
        guard !leftPoints.isEmpty, !rightPoints.isEmpty else { return path }
        
        // Start with the first left point
        path.move(to: leftPoints[0])
        
        // Draw along the left side (forward)
        for i in 1..<leftPoints.count {
            path.addLine(to: leftPoints[i])
        }
        
        // Add end cap
        if let lastLeft = leftPoints.last, let lastRight = rightPoints.last {
            addCap(to: &path, from: lastLeft, to: lastRight, cap: cap, isEnd: true)
        }
        
        // Draw along the right side (backward)
        for i in (0..<rightPoints.count - 1).reversed() {
            path.addLine(to: rightPoints[i])
        }
        
        // Add start cap
        if let firstLeft = leftPoints.first, let firstRight = rightPoints.first {
            addCap(to: &path, from: firstRight, to: firstLeft, cap: cap, isEnd: false)
        }
        
        path.closeSubpath()
        
        return path
    }
    
    /// Adds a cap (end or start) to the path.
    private static func addCap(
        to path: inout SwiftUI.Path,
        from: CGPoint,
        to: CGPoint,
        cap: BrushCap,
        isEnd: Bool
    ) {
        switch cap {
        case .butt:
            // Straight line across
            path.addLine(to: to)
            
        case .round:
            // Semicircular arc
            let center = CGPoint(
                x: (from.x + to.x) / 2,
                y: (from.y + to.y) / 2
            )
            let radius = distance(from, to) / 2
            let startAngle = atan2(from.y - center.y, from.x - center.x)
            
            path.addArc(
                center: center,
                radius: radius,
                startAngle: .radians(startAngle),
                endAngle: .radians(startAngle + .pi),
                clockwise: !isEnd
            )
            
        case .square:
            // Extended square cap
            let dx = to.x - from.x
            let dy = to.y - from.y
            let halfWidth = distance(from, to) / 2
            
            // Direction perpendicular to the cap line (along stroke direction)
            let perpAngle = atan2(dy, dx) + (isEnd ? .pi / 2 : -.pi / 2)
            let offsetX = cos(perpAngle) * halfWidth
            let offsetY = sin(perpAngle) * halfWidth
            
            path.addLine(to: CGPoint(x: from.x + offsetX, y: from.y + offsetY))
            path.addLine(to: CGPoint(x: to.x + offsetX, y: to.y + offsetY))
            path.addLine(to: to)
        }
    }
    
    // MARK: - Adaptive Bezier Sampling
    
    /// Calculates the optimal number of samples for a quadratic bezier curve.
    ///
    /// Uses adaptive sampling based on:
    /// - Curve length
    /// - Curviness ratio (control polygon length / chord length)
    ///
    /// Nearly straight curves get fewer samples; highly curved ones get more.
    @inline(__always)
    private static func adaptiveQuadSampleCount(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint,
        length: CGFloat
    ) -> Int {
        // Chord length: direct distance from start to end
        let chordLength = distanceFast(from, to)
        
        // Control polygon length
        let leg1 = distanceFast(from, control)
        let leg2 = distanceFast(control, to)
        let controlPolygonLength = leg1 + leg2
        
        // Curviness: ratio of control polygon to chord (1.0 = straight line)
        let curviness = chordLength > 0.001 ? controlPolygonLength / chordLength : 1.0
        
        // Samples from curviness (more curved = more samples)
        let curvinessContribution = (curviness - 1.0) * samplesPerCurvinessUnit
        
        // Samples from length (longer = more samples, but with diminishing returns)
        let lengthContribution = ceil(length / maxSampleSpacing)
        
        let rawSamples = Int(curvinessContribution + lengthContribution)
        
        return max(minSamplesPerSegment, min(maxSamplesPerSegment, rawSamples))
    }
    
    /// Calculates the optimal number of samples for a cubic bezier curve.
    ///
    /// Uses adaptive sampling based on:
    /// - Curve length
    /// - Curviness ratio (control polygon length / chord length)
    ///
    /// Cubic curves can have inflection points, so they get slightly more samples
    /// for the same curviness compared to quadratic curves.
    @inline(__always)
    private static func adaptiveCubicSampleCount(
        from: CGPoint,
        to: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        length: CGFloat
    ) -> Int {
        // Chord length: direct distance from start to end
        let chordLength = distanceFast(from, to)
        
        // Control polygon length: through both control points
        let leg1 = distanceFast(from, control1)
        let leg2 = distanceFast(control1, control2)
        let leg3 = distanceFast(control2, to)
        let controlPolygonLength = leg1 + leg2 + leg3
        
        // Curviness: ratio of control polygon to chord
        let curviness = chordLength > 0.001 ? controlPolygonLength / chordLength : 1.0
        
        // Cubic curves need slightly more samples due to potential inflection points
        let curvinessContribution = (curviness - 1.0) * samplesPerCurvinessUnit * 1.2
        
        // Samples from length
        let lengthContribution = ceil(length / maxSampleSpacing)
        
        let rawSamples = Int(curvinessContribution + lengthContribution)
        
        return max(minSamplesPerSegment, min(maxSamplesPerSegment, rawSamples))
    }
    
    // MARK: - Bezier Curve Math (Optimized)
    
    /// Linear interpolation between two points (inlined for performance).
    @inline(__always)
    private static func lerpFast(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t
        )
    }
    
    /// Distance between two points (optimized, avoids pow()).
    @inline(__always)
    private static func distanceFast(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Linear interpolation between two points.
    private static func lerp(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        lerpFast(a, b, t: t)
    }
    
    /// Distance between two points.
    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        distanceFast(a, b)
    }
    
    /// Point on a quadratic Bezier curve at parameter t.
    private static func quadraticBezierPoint(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        return CGPoint(
            x: oneMinusT * oneMinusT * from.x + 2 * oneMinusT * t * control.x + t * t * to.x,
            y: oneMinusT * oneMinusT * from.y + 2 * oneMinusT * t * control.y + t * t * to.y
        )
    }
    
    /// Tangent angle of a quadratic Bezier curve at parameter t.
    private static func quadraticBezierTangent(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint,
        t: CGFloat
    ) -> CGFloat {
        let oneMinusT = 1 - t
        let dx = 2 * oneMinusT * (control.x - from.x) + 2 * t * (to.x - control.x)
        let dy = 2 * oneMinusT * (control.y - from.y) + 2 * t * (to.y - control.y)
        return atan2(dy, dx)
    }
    
    /// Approximate length of a quadratic Bezier curve (optimized).
    /// Uses fewer samples and inlined distance calculation.
    @inline(__always)
    private static func quadCurveLengthFast(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint
    ) -> CGFloat {
        // Use 8 samples instead of 10 - good balance of accuracy vs speed
        var length: CGFloat = 0
        var prevX = from.x
        var prevY = from.y
        
        // Unrolled loop with precomputed t values for better performance
        let tValues: [CGFloat] = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
        
        for t in tValues {
            let oneMinusT = 1 - t
            let oneMinusT2 = oneMinusT * oneMinusT
            let t2 = t * t
            let twoOneMinusTT = 2 * oneMinusT * t
            
            let x = oneMinusT2 * from.x + twoOneMinusTT * control.x + t2 * to.x
            let y = oneMinusT2 * from.y + twoOneMinusTT * control.y + t2 * to.y
            
            let dx = x - prevX
            let dy = y - prevY
            length += sqrt(dx * dx + dy * dy)
            
            prevX = x
            prevY = y
        }
        
        return length
    }
    
    /// Approximate length of a quadratic Bezier curve.
    private static func quadCurveLength(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint
    ) -> CGFloat {
        quadCurveLengthFast(from: from, to: to, control: control)
    }
    
    /// Point on a cubic Bezier curve at parameter t.
    private static func cubicBezierPoint(
        from: CGPoint,
        to: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        t: CGFloat
    ) -> CGPoint {
        let oneMinusT = 1 - t
        let oneMinusT2 = oneMinusT * oneMinusT
        let oneMinusT3 = oneMinusT2 * oneMinusT
        let t2 = t * t
        let t3 = t2 * t
        
        return CGPoint(
            x: oneMinusT3 * from.x + 3 * oneMinusT2 * t * control1.x + 3 * oneMinusT * t2 * control2.x + t3 * to.x,
            y: oneMinusT3 * from.y + 3 * oneMinusT2 * t * control1.y + 3 * oneMinusT * t2 * control2.y + t3 * to.y
        )
    }
    
    /// Tangent angle of a cubic Bezier curve at parameter t.
    private static func cubicBezierTangent(
        from: CGPoint,
        to: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        t: CGFloat
    ) -> CGFloat {
        let oneMinusT = 1 - t
        let oneMinusT2 = oneMinusT * oneMinusT
        let t2 = t * t
        
        let dx = 3 * oneMinusT2 * (control1.x - from.x) +
                 6 * oneMinusT * t * (control2.x - control1.x) +
                 3 * t2 * (to.x - control2.x)
        let dy = 3 * oneMinusT2 * (control1.y - from.y) +
                 6 * oneMinusT * t * (control2.y - control1.y) +
                 3 * t2 * (to.y - control2.y)
        
        return atan2(dy, dx)
    }
    
    /// Approximate length of a cubic Bezier curve (optimized).
    /// Uses fewer samples and inlined calculations.
    @inline(__always)
    private static func cubicCurveLengthFast(
        from: CGPoint,
        to: CGPoint,
        control1: CGPoint,
        control2: CGPoint
    ) -> CGFloat {
        // Use 8 samples - good balance of accuracy vs speed
        var length: CGFloat = 0
        var prevX = from.x
        var prevY = from.y
        
        // Precomputed t values
        let tValues: [CGFloat] = [0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0]
        
        for t in tValues {
            let oneMinusT = 1 - t
            let oneMinusT2 = oneMinusT * oneMinusT
            let oneMinusT3 = oneMinusT2 * oneMinusT
            let t2 = t * t
            let t3 = t2 * t
            let threeOneMinusT2T = 3 * oneMinusT2 * t
            let threeOneMinusTT2 = 3 * oneMinusT * t2
            
            let x = oneMinusT3 * from.x + threeOneMinusT2T * control1.x + threeOneMinusTT2 * control2.x + t3 * to.x
            let y = oneMinusT3 * from.y + threeOneMinusT2T * control1.y + threeOneMinusTT2 * control2.y + t3 * to.y
            
            let dx = x - prevX
            let dy = y - prevY
            length += sqrt(dx * dx + dy * dy)
            
            prevX = x
            prevY = y
        }
        
        return length
    }
    
    /// Approximate length of a cubic Bezier curve.
    private static func cubicCurveLength(
        from: CGPoint,
        to: CGPoint,
        control1: CGPoint,
        control2: CGPoint
    ) -> CGFloat {
        cubicCurveLengthFast(from: from, to: to, control1: control1, control2: control2)
    }
}

