//
//  StarburstFiller.swift
//  RoughSwift
//
//  Starburst/Sunburst fill pattern generator - radial lines from centroid.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Generates starburst fill patterns (radial lines emanating from center).
/// Used for both "starburst" and "sunburst" fill styles.
public struct StarburstFiller: FillGenerator {
    
    public init() {}
    
    public func fillPolygon(points: [[Float]], options: Options) -> OperationSet? {
        guard points.count >= 3 else { return nil }
        
        let bounds = RoughMath.polygonBounds(points)
        let centroid = RoughMath.polygonCentroid(points)
        
        // Calculate maximum radius from centroid to corners
        let maxRadius = max(
            sqrt(pow(centroid[0] - bounds.minX, 2) + pow(centroid[1] - bounds.minY, 2)),
            sqrt(pow(centroid[0] - bounds.maxX, 2) + pow(centroid[1] - bounds.minY, 2)),
            sqrt(pow(centroid[0] - bounds.maxX, 2) + pow(centroid[1] - bounds.maxY, 2)),
            sqrt(pow(centroid[0] - bounds.minX, 2) + pow(centroid[1] - bounds.maxY, 2))
        )
        
        var gap = options.computedHachureGap
        if gap < 0 {
            gap = options.strokeWidth * 4
        }
        gap = max(gap, 1)
        
        // Calculate number of rays based on circumference
        let rayCount = max(1, Int(Float.pi * maxRadius / gap))
        
        // Find intersection points for each ray
        var intersectionPoints: [(x: Float, y: Float)] = []
        
        for i in 0..<rayCount {
            let angle = Float(i) * Float.pi / Float(rayCount)
            let ray = (
                start: (centroid[0], centroid[1]),
                end: (centroid[0] + maxRadius * cos(angle), centroid[1] + maxRadius * sin(angle))
            )
            
            let intersections = LineHelper.linePolygonIntersections(line: ray, polygon: points)
            for point in intersections {
                // Only keep points that are actually on the polygon boundary
                if point.x >= bounds.minX && point.x <= bounds.maxX &&
                   point.y >= bounds.minY && point.y <= bounds.maxY {
                    intersectionPoints.append(point)
                }
            }
        }
        
        // Remove duplicates
        intersectionPoints = removeDuplicatePoints(intersectionPoints, tolerance: 0.5)
        
        // Generate lines from centroid to each intersection
        let lines = intersectionPoints.map { point in
            FillLine(start: (centroid[0], centroid[1]), end: (point.x, point.y))
        }
        
        let ops = drawRadialLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        var gap = options.computedHachureGap
        if gap < 0 {
            gap = options.strokeWidth * 4
        }
        gap = max(gap, 1)
        
        // Calculate number of rays based on perimeter approximation
        let perimeter = Float.pi * (3 * (rx + ry) - sqrt((3 * rx + ry) * (rx + 3 * ry)))
        let rayCount = max(1, Int(perimeter / gap))
        
        // Generate radial lines
        var lines: [FillLine] = []
        for i in 0..<rayCount {
            let angle = Float(i) * 2 * Float.pi / Float(rayCount)
            
            // Point on ellipse at this angle
            let x = cx + rx * cos(angle)
            let y = cy + ry * sin(angle)
            
            lines.append(FillLine(start: (cx, cy), end: (x, y)))
        }
        
        let ops = drawRadialLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    public func fillArc(cx: Float, cy: Float, rx: Float, ry: Float, start: Float, stop: Float, options: Options) -> OperationSet? {
        var gap = options.computedHachureGap
        if gap < 0 {
            gap = options.strokeWidth * 4
        }
        gap = max(gap, 1)
        
        // Calculate arc length
        let arcAngle = abs(stop - start)
        let avgRadius = (rx + ry) / 2
        let arcLength = arcAngle * avgRadius
        let rayCount = max(1, Int(arcLength / gap))
        
        // Generate radial lines within arc
        var lines: [FillLine] = []
        for i in 0...rayCount {
            let t = Float(i) / Float(rayCount)
            let angle = start + t * (stop - start)
            
            let x = cx + rx * cos(angle)
            let y = cy + ry * sin(angle)
            
            lines.append(FillLine(start: (cx, cy), end: (x, y)))
        }
        
        let ops = drawRadialLines(lines: lines, options: options)
        return OperationSet(type: .fillSketch, operations: ops, path: nil, size: nil)
    }
    
    // MARK: - Helpers
    
    /// Draws radial lines with rough effect.
    private func drawRadialLines(lines: [FillLine], options: Options) -> [Operation] {
        var ops: [Operation] = []
        
        for line in lines {
            ops.append(contentsOf: RoughMath.doubleLineOps(
                x1: line.start.x, y1: line.start.y,
                x2: line.end.x, y2: line.end.y,
                options: options
            ))
        }
        
        return ops
    }
    
    /// Removes duplicate points within tolerance.
    private func removeDuplicatePoints(_ points: [(x: Float, y: Float)], tolerance: Float) -> [(x: Float, y: Float)] {
        var result: [(x: Float, y: Float)] = []
        
        for point in points {
            let isDuplicate = result.contains { existing in
                let dx = existing.x - point.x
                let dy = existing.y - point.y
                return sqrt(dx * dx + dy * dy) < tolerance
            }
            if !isDuplicate {
                result.append(point)
            }
        }
        
        return result
    }
}

