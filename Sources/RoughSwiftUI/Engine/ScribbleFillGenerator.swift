//
//  ScribbleFillGenerator.swift
//  RoughSwift
//
//  Created by Cursor on 02/12/2025.
//
//  Native Swift generator for scribble fill patterns.
//

import Foundation
import CoreGraphics
import UIKit

/// Generates scribble fill patterns for shapes.
///
/// The scribble fill creates a continuous zig-zag line that traverses from one edge
/// of a shape to the opposite edge, with configurable tightness and vertex curvature.
/// For concave shapes, the fill is split into separate stroke segments.
public struct ScribbleFillGenerator {
    
    // MARK: - Public Interface
    
    /// Generates scribble fill operations for a given path.
    ///
    /// - Parameters:
    ///   - path: The CGPath to fill with scribble pattern.
    ///   - options: The rendering options containing scribble parameters.
    /// - Returns: An array of OperationSets, one per continuous stroke segment.
    public static func generate(for path: CGPath, options: Options) -> [OperationSet] {
        let bounds = path.boundingBox
        guard bounds.width > 0, bounds.height > 0 else { return [] }
        
        let originAngle = CGFloat(options.scribbleOrigin) * .pi / 180
        // Curvature as a 0-1 value
        let curvatureNormalized = CGFloat(max(0, min(50, options.scribbleCurvature))) / 50.0
        // Scale curvature for the curve generation (how much of segment to use for curve)
        // Use smaller value to keep curves tight near vertices
        let curvature = curvatureNormalized * 0.30
        
        // Reduce effective tightness when curvature is high to create longer segments
        // This gives curves more room to be fluid without pulling vertices from edges
        // At max curvature, reduce tightness by up to 60%
        let tightnessReduction = 1.0 - (curvatureNormalized * 0.6)
        
        // Calculate traversal direction (perpendicular to the origin angle)
        let traversalAngle = originAngle + .pi / 2
        
        // Calculate the extent of the shape along the traversal direction
        let (minProjection, maxProjection) = projectBoundsOntoAxis(bounds: bounds, angle: traversalAngle)
        let traversalLength = maxProjection - minProjection
        
        guard traversalLength > 0 else { return [] }
        
        // Edge padding: minimal fixed value to keep vertices very close to edges
        let edgePadding = min(bounds.width, bounds.height) * 0.02
        
        // Generate vertex positions based on tightness pattern or uniform tightness
        let vertexPositions = generateVertexPositions(
            pattern: options.scribbleTightnessPattern,
            uniformTightness: options.scribbleTightness,
            tightnessReduction: tightnessReduction,
            minProjection: minProjection,
            traversalLength: traversalLength
        )
        
        guard !vertexPositions.isEmpty else { return [] }
        
        // Generate zig-zag by alternating between left and right edges at each position
        var allSegments: [[CGPoint]] = []
        var currentSegment: [CGPoint] = []
        var goToRight = true  // Which side to go to next
        var lastSpacing: CGFloat = traversalLength / CGFloat(vertexPositions.count + 1)
        
        for (index, position) in vertexPositions.enumerated() {
            // Cast a ray perpendicular to traversal direction at this position
            let rayOrigin = pointOnAxis(center: CGPoint(x: bounds.midX, y: bounds.midY),
                                        angle: traversalAngle,
                                        distance: position - (minProjection + maxProjection) / 2)
            
            let intersections = findRayIntersections(
                path: path,
                rayOrigin: rayOrigin,
                rayAngle: originAngle,
                bounds: bounds
            )
            
            guard intersections.count >= 2 else {
                // No valid intersections at this level - save current segment and start fresh
                if !currentSegment.isEmpty {
                    allSegments.append(currentSegment)
                    currentSegment = []
                }
                continue
            }
            
            // Sort intersections along the ray direction (always left to right)
            let sortedIntersections = intersections.sorted { p1, p2 in
                let d1 = projectPointOntoAxis(point: p1, origin: rayOrigin, angle: originAngle)
                let d2 = projectPointOntoAxis(point: p2, origin: rayOrigin, angle: originAngle)
                return d1 < d2
            }
            
            // Get left-most and right-most intersection points
            let leftEdge = sortedIntersections.first!
            let rightEdge = sortedIntersections.last!
            
            // Calculate the inset point (vertex) for this level
            let segmentWidth = hypot(rightEdge.x - leftEdge.x, rightEdge.y - leftEdge.y)
            let insetAmount = min(edgePadding, segmentWidth * 0.35)
            
            let dx = (rightEdge.x - leftEdge.x) / segmentWidth
            let dy = (rightEdge.y - leftEdge.y) / segmentWidth
            
            // Choose the vertex point based on which side we're going to
            let vertex: CGPoint
            if goToRight {
                // Vertex near the right edge, inset toward center
                vertex = CGPoint(
                    x: rightEdge.x - dx * insetAmount,
                    y: rightEdge.y - dy * insetAmount
                )
            } else {
                // Vertex near the left edge, inset toward center
                vertex = CGPoint(
                    x: leftEdge.x + dx * insetAmount,
                    y: leftEdge.y + dy * insetAmount
                )
            }
            
            // Calculate expected spacing for gap detection
            if index > 0 {
                lastSpacing = vertexPositions[index] - vertexPositions[index - 1]
            }
            
            // Check for concave gaps (if the new vertex is too far from the last point)
            if !currentSegment.isEmpty {
                let lastPoint = currentSegment.last!
                let distanceToVertex = hypot(vertex.x - lastPoint.x, vertex.y - lastPoint.y)
                let expectedMaxDistance = segmentWidth + lastSpacing * 1.5
                
                if distanceToVertex > expectedMaxDistance {
                    // Gap detected - save current segment and start new one
                    allSegments.append(currentSegment)
                    currentSegment = []
                }
            }
            
            currentSegment.append(vertex)
            goToRight.toggle()
        }
        
        // Save final segment
        if !currentSegment.isEmpty {
            allSegments.append(currentSegment)
        }
        
        // Convert segments to OperationSets with curvature
        return allSegments.map { segment in
            createOperationSet(from: segment, curvature: curvature)
        }
    }
    
    /// Generates vertex positions along the traversal axis.
    /// Supports both uniform tightness and variable tightness patterns.
    private static func generateVertexPositions(
        pattern: [Int]?,
        uniformTightness: Int,
        tightnessReduction: CGFloat,
        minProjection: CGFloat,
        traversalLength: CGFloat
    ) -> [CGFloat] {
        if let pattern = pattern, !pattern.isEmpty {
            // Variable tightness: divide traversal into sections
            return generatePatternPositions(
                pattern: pattern,
                tightnessReduction: tightnessReduction,
                minProjection: minProjection,
                traversalLength: traversalLength
            )
        } else {
            // Uniform tightness
            let baseTightness = max(1, min(100, uniformTightness))
            let effectiveTightness = max(2, Int(CGFloat(baseTightness) * tightnessReduction))
            
            var positions: [CGFloat] = []
            for i in 1...effectiveTightness {
                let t = CGFloat(i) / CGFloat(effectiveTightness + 1)
                positions.append(minProjection + t * traversalLength)
            }
            return positions
        }
    }
    
    /// Generates vertex positions for a variable tightness pattern.
    private static func generatePatternPositions(
        pattern: [Int],
        tightnessReduction: CGFloat,
        minProjection: CGFloat,
        traversalLength: CGFloat
    ) -> [CGFloat] {
        var positions: [CGFloat] = []
        let sectionLength = traversalLength / CGFloat(pattern.count)
        
        for (sectionIndex, sectionTightness) in pattern.enumerated() {
            let sectionStart = minProjection + CGFloat(sectionIndex) * sectionLength
            let baseTightness = max(1, min(100, sectionTightness))
            let effectiveTightness = max(1, Int(CGFloat(baseTightness) * tightnessReduction))
            
            // Generate vertices within this section
            for i in 1...effectiveTightness {
                let t = CGFloat(i) / CGFloat(effectiveTightness + 1)
                let position = sectionStart + t * sectionLength
                positions.append(position)
            }
        }
        
        return positions
    }
    
    // MARK: - Geometry Helpers
    
    /// Projects the bounding box onto an axis defined by an angle.
    private static func projectBoundsOntoAxis(bounds: CGRect, angle: CGFloat) -> (min: CGFloat, max: CGFloat) {
        let corners = [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
            CGPoint(x: bounds.minX, y: bounds.maxY)
        ]
        
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let projections = corners.map { projectPointOntoAxis(point: $0, origin: center, angle: angle) }
        
        return (projections.min() ?? 0, projections.max() ?? 0)
    }
    
    /// Projects a point onto an axis defined by origin and angle.
    private static func projectPointOntoAxis(point: CGPoint, origin: CGPoint, angle: CGFloat) -> CGFloat {
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        return dx * cos(angle) + dy * sin(angle)
    }
    
    /// Returns a point on an axis at a given distance from the center.
    private static func pointOnAxis(center: CGPoint, angle: CGFloat, distance: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + distance * cos(angle),
            y: center.y + distance * sin(angle)
        )
    }
    
    // MARK: - Ray Casting
    
    /// Finds all intersections between a ray and a CGPath.
    private static func findRayIntersections(
        path: CGPath,
        rayOrigin: CGPoint,
        rayAngle: CGFloat,
        bounds: CGRect
    ) -> [CGPoint] {
        // Create a very long line segment for the ray
        let rayLength = max(bounds.width, bounds.height) * 3
        let rayStart = CGPoint(
            x: rayOrigin.x - rayLength * cos(rayAngle),
            y: rayOrigin.y - rayLength * sin(rayAngle)
        )
        let rayEnd = CGPoint(
            x: rayOrigin.x + rayLength * cos(rayAngle),
            y: rayOrigin.y + rayLength * sin(rayAngle)
        )
        
        // Extract path elements and find intersections
        var intersections: [CGPoint] = []
        var currentPoint = CGPoint.zero
        var startPoint = CGPoint.zero
        
        path.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                currentPoint = element.pointee.points[0]
                startPoint = currentPoint
                
            case .addLineToPoint:
                let endPoint = element.pointee.points[0]
                if let intersection = lineIntersection(
                    p1: rayStart, p2: rayEnd,
                    p3: currentPoint, p4: endPoint
                ) {
                    intersections.append(intersection)
                }
                currentPoint = endPoint
                
            case .addQuadCurveToPoint:
                let controlPoint = element.pointee.points[0]
                let endPoint = element.pointee.points[1]
                // Approximate quad curve with line segments
                let curveIntersections = findQuadCurveIntersections(
                    start: currentPoint,
                    control: controlPoint,
                    end: endPoint,
                    rayStart: rayStart,
                    rayEnd: rayEnd
                )
                intersections.append(contentsOf: curveIntersections)
                currentPoint = endPoint
                
            case .addCurveToPoint:
                let control1 = element.pointee.points[0]
                let control2 = element.pointee.points[1]
                let endPoint = element.pointee.points[2]
                // Approximate cubic curve with line segments
                let curveIntersections = findCubicCurveIntersections(
                    start: currentPoint,
                    control1: control1,
                    control2: control2,
                    end: endPoint,
                    rayStart: rayStart,
                    rayEnd: rayEnd
                )
                intersections.append(contentsOf: curveIntersections)
                currentPoint = endPoint
                
            case .closeSubpath:
                if let intersection = lineIntersection(
                    p1: rayStart, p2: rayEnd,
                    p3: currentPoint, p4: startPoint
                ) {
                    intersections.append(intersection)
                }
                currentPoint = startPoint
                
            @unknown default:
                break
            }
        }
        
        // Remove duplicate intersections (within tolerance)
        return removeDuplicatePoints(intersections, tolerance: 0.5)
    }
    
    /// Finds intersection point between two line segments, if any.
    private static func lineIntersection(
        p1: CGPoint, p2: CGPoint,
        p3: CGPoint, p4: CGPoint
    ) -> CGPoint? {
        let d1 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let d2 = CGPoint(x: p4.x - p3.x, y: p4.y - p3.y)
        
        let cross = d1.x * d2.y - d1.y * d2.x
        guard abs(cross) > 1e-10 else { return nil } // Parallel lines
        
        let d3 = CGPoint(x: p1.x - p3.x, y: p1.y - p3.y)
        let t1 = (d2.x * d3.y - d2.y * d3.x) / cross
        let t2 = (d1.x * d3.y - d1.y * d3.x) / cross
        
        // Check if intersection is within both segments
        guard t1 >= 0, t1 <= 1, t2 >= 0, t2 <= 1 else { return nil }
        
        return CGPoint(
            x: p1.x + t1 * d1.x,
            y: p1.y + t1 * d1.y
        )
    }
    
    /// Finds intersections between a ray and a quadratic bezier curve.
    private static func findQuadCurveIntersections(
        start: CGPoint,
        control: CGPoint,
        end: CGPoint,
        rayStart: CGPoint,
        rayEnd: CGPoint
    ) -> [CGPoint] {
        var intersections: [CGPoint] = []
        let segments = 10
        
        for i in 0..<segments {
            let t1 = CGFloat(i) / CGFloat(segments)
            let t2 = CGFloat(i + 1) / CGFloat(segments)
            
            let p1 = quadraticBezierPoint(start: start, control: control, end: end, t: t1)
            let p2 = quadraticBezierPoint(start: start, control: control, end: end, t: t2)
            
            if let intersection = lineIntersection(p1: rayStart, p2: rayEnd, p3: p1, p4: p2) {
                intersections.append(intersection)
            }
        }
        
        return intersections
    }
    
    /// Finds intersections between a ray and a cubic bezier curve.
    private static func findCubicCurveIntersections(
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint,
        rayStart: CGPoint,
        rayEnd: CGPoint
    ) -> [CGPoint] {
        var intersections: [CGPoint] = []
        let segments = 15
        
        for i in 0..<segments {
            let t1 = CGFloat(i) / CGFloat(segments)
            let t2 = CGFloat(i + 1) / CGFloat(segments)
            
            let p1 = cubicBezierPoint(start: start, control1: control1, control2: control2, end: end, t: t1)
            let p2 = cubicBezierPoint(start: start, control1: control1, control2: control2, end: end, t: t2)
            
            if let intersection = lineIntersection(p1: rayStart, p2: rayEnd, p3: p1, p4: p2) {
                intersections.append(intersection)
            }
        }
        
        return intersections
    }
    
    /// Evaluates a point on a quadratic bezier curve.
    private static func quadraticBezierPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * start.x + 2 * mt * t * control.x + t * t * end.x,
            y: mt * mt * start.y + 2 * mt * t * control.y + t * t * end.y
        )
    }
    
    /// Evaluates a point on a cubic bezier curve.
    private static func cubicBezierPoint(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t
        
        return CGPoint(
            x: mt3 * start.x + 3 * mt2 * t * control1.x + 3 * mt * t2 * control2.x + t3 * end.x,
            y: mt3 * start.y + 3 * mt2 * t * control1.y + 3 * mt * t2 * control2.y + t3 * end.y
        )
    }
    
    /// Removes duplicate points within a tolerance.
    private static func removeDuplicatePoints(_ points: [CGPoint], tolerance: CGFloat) -> [CGPoint] {
        var result: [CGPoint] = []
        for point in points {
            let isDuplicate = result.contains { existing in
                hypot(existing.x - point.x, existing.y - point.y) < tolerance
            }
            if !isDuplicate {
                result.append(point)
            }
        }
        return result
    }
    
    // MARK: - Intersection Pairing
    
    /// Groups sorted intersections into entry/exit pairs.
    private static func pairIntersections(_ intersections: [CGPoint]) -> [(CGPoint, CGPoint)] {
        var pairs: [(CGPoint, CGPoint)] = []
        var i = 0
        
        while i + 1 < intersections.count {
            pairs.append((intersections[i], intersections[i + 1]))
            i += 2
        }
        
        return pairs
    }
    
    // MARK: - Operation Set Creation
    
    /// Creates an OperationSet from a segment of points with optional curvature.
    private static func createOperationSet(from points: [CGPoint], curvature: CGFloat) -> OperationSet {
        guard points.count >= 2 else {
            return OperationSet(type: .fillSketch, operations: [], path: nil, size: nil)
        }
        
        var operations: [Operation] = []
        
        // Move to first point
        operations.append(Move(data: [Float(points[0].x), Float(points[0].y)]))
        
        if curvature <= 0 || points.count < 3 {
            // Sharp corners - just use line segments
            for i in 1..<points.count {
                operations.append(LineTo(data: [Float(points[i].x), Float(points[i].y)]))
            }
        } else {
            // Curved corners using quadratic bezier curves
            for i in 1..<points.count {
                if i < points.count - 1 {
                    // Interior point - add curve
                    let prev = points[i - 1]
                    let curr = points[i]
                    let next = points[i + 1]
                    
                    // Calculate distances
                    let distToPrev = hypot(curr.x - prev.x, curr.y - prev.y)
                    let distToNext = hypot(next.x - curr.x, next.y - curr.y)
                    
                    // Use each segment's own length for the curve offset
                    // This ensures curves are visible even when segment lengths differ
                    let entryOffset = distToPrev * curvature
                    let exitOffset = distToNext * curvature
                    
                    // Entry point (along line from prev to curr, offset back from curr)
                    let entryT = max(0.1, 1.0 - entryOffset / distToPrev)
                    let entryPoint = CGPoint(
                        x: prev.x + (curr.x - prev.x) * entryT,
                        y: prev.y + (curr.y - prev.y) * entryT
                    )
                    
                    // Exit point (along line from curr to next, offset forward from curr)
                    let exitT = min(0.9, exitOffset / distToNext)
                    let exitPoint = CGPoint(
                        x: curr.x + (next.x - curr.x) * exitT,
                        y: curr.y + (next.y - curr.y) * exitT
                    )
                    
                    // Line to entry point
                    operations.append(LineTo(data: [Float(entryPoint.x), Float(entryPoint.y)]))
                    
                    // Quadratic curve through corner
                    operations.append(QuadraticCurveTo(data: [
                        Float(curr.x), Float(curr.y),  // control point (the corner)
                        Float(exitPoint.x), Float(exitPoint.y)  // end point
                    ]))
                } else {
                    // Last point - just line to it
                    operations.append(LineTo(data: [Float(points[i].x), Float(points[i].y)]))
                }
            }
        }
        
        return OperationSet(type: .fillSketch, operations: operations, path: nil, size: nil)
    }
}

