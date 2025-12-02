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
    private static let minSamplesPerSegment = 8
    
    /// Maximum distance between samples (in points).
    private static let maxSampleSpacing: CGFloat = 4.0
    
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
    
    /// Samples a subpath at regular intervals.
    private static func sampleSubpath(_ elements: [PathElement]) -> [PathSample] {
        var samples: [PathSample] = []
        var currentPoint = CGPoint.zero
        var totalLength: CGFloat = 0
        
        // First pass: calculate total length
        var lengths: [(element: PathElement, length: CGFloat)] = []
        for element in elements {
            switch element {
            case .move(let to):
                currentPoint = to
            case .line(let to):
                let len = distance(currentPoint, to)
                lengths.append((element, len))
                totalLength += len
                currentPoint = to
            case .quadCurve(let to, let control):
                let len = quadCurveLength(from: currentPoint, to: to, control: control)
                lengths.append((element, len))
                totalLength += len
                currentPoint = to
            case .curve(let to, let control1, let control2):
                let len = cubicCurveLength(from: currentPoint, to: to, control1: control1, control2: control2)
                lengths.append((element, len))
                totalLength += len
                currentPoint = to
            case .closeSubpath:
                break
            }
        }
        
        guard totalLength > 0 else { return [] }
        
        // Second pass: sample points
        currentPoint = CGPoint.zero
        var accumulatedLength: CGFloat = 0
        
        for element in elements {
            switch element {
            case .move(let to):
                currentPoint = to
                // Add starting point
                let tangent = computeInitialTangent(elements: elements)
                samples.append(PathSample(point: to, tangentAngle: tangent, t: 0))
                
            case .line(let to):
                let segmentLength = distance(currentPoint, to)
                let numSamples = max(2, Int(ceil(segmentLength / maxSampleSpacing)))
                
                for i in 1...numSamples {
                    let localT = CGFloat(i) / CGFloat(numSamples)
                    let point = lerp(currentPoint, to, t: localT)
                    let tangent = atan2(to.y - currentPoint.y, to.x - currentPoint.x)
                    let globalT = (accumulatedLength + segmentLength * localT) / totalLength
                    samples.append(PathSample(point: point, tangentAngle: tangent, t: globalT))
                }
                
                accumulatedLength += segmentLength
                currentPoint = to
                
            case .quadCurve(let to, let control):
                let segmentLength = quadCurveLength(from: currentPoint, to: to, control: control)
                let numSamples = max(minSamplesPerSegment, Int(ceil(segmentLength / maxSampleSpacing)))
                
                for i in 1...numSamples {
                    let localT = CGFloat(i) / CGFloat(numSamples)
                    let point = quadraticBezierPoint(from: currentPoint, to: to, control: control, t: localT)
                    let tangent = quadraticBezierTangent(from: currentPoint, to: to, control: control, t: localT)
                    let globalT = (accumulatedLength + segmentLength * localT) / totalLength
                    samples.append(PathSample(point: point, tangentAngle: tangent, t: globalT))
                }
                
                accumulatedLength += segmentLength
                currentPoint = to
                
            case .curve(let to, let control1, let control2):
                let segmentLength = cubicCurveLength(from: currentPoint, to: to, control1: control1, control2: control2)
                let numSamples = max(minSamplesPerSegment, Int(ceil(segmentLength / maxSampleSpacing)))
                
                for i in 1...numSamples {
                    let localT = CGFloat(i) / CGFloat(numSamples)
                    let point = cubicBezierPoint(from: currentPoint, to: to, control1: control1, control2: control2, t: localT)
                    let tangent = cubicBezierTangent(from: currentPoint, to: to, control1: control1, control2: control2, t: localT)
                    let globalT = (accumulatedLength + segmentLength * localT) / totalLength
                    samples.append(PathSample(point: point, tangentAngle: tangent, t: globalT))
                }
                
                accumulatedLength += segmentLength
                currentPoint = to
                
            case .closeSubpath:
                break
            }
        }
        
        return samples
    }
    
    /// Computes the initial tangent direction for a subpath.
    private static func computeInitialTangent(elements: [PathElement]) -> CGFloat {
        guard let firstMove = elements.first, case .move(let from) = firstMove else {
            return 0
        }
        
        for element in elements.dropFirst() {
            switch element {
            case .line(let to):
                return atan2(to.y - from.y, to.x - from.x)
            case .quadCurve(_, let control):
                return atan2(control.y - from.y, control.x - from.x)
            case .curve(_, let control1, _):
                return atan2(control1.y - from.y, control1.x - from.x)
            default:
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
    
    // MARK: - Bezier Curve Math
    
    /// Linear interpolation between two points.
    private static func lerp(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t
        )
    }
    
    /// Distance between two points.
    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        sqrt(pow(b.x - a.x, 2) + pow(b.y - a.y, 2))
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
    
    /// Approximate length of a quadratic Bezier curve.
    private static func quadCurveLength(
        from: CGPoint,
        to: CGPoint,
        control: CGPoint
    ) -> CGFloat {
        // Approximate by sampling
        var length: CGFloat = 0
        var prev = from
        let steps = 10
        
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let point = quadraticBezierPoint(from: from, to: to, control: control, t: t)
            length += distance(prev, point)
            prev = point
        }
        
        return length
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
    
    /// Approximate length of a cubic Bezier curve.
    private static func cubicCurveLength(
        from: CGPoint,
        to: CGPoint,
        control1: CGPoint,
        control2: CGPoint
    ) -> CGFloat {
        // Approximate by sampling
        var length: CGFloat = 0
        var prev = from
        let steps = 10
        
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let point = cubicBezierPoint(from: from, to: to, control1: control1, control2: control2, t: t)
            length += distance(prev, point)
            prev = point
        }
        
        return length
    }
}

