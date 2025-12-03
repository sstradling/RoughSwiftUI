//
//  FillGenerator.swift
//  RoughSwift
//
//  Protocol and factory for fill pattern generators.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation

/// Protocol for fill pattern generators.
/// Each fill style (hachure, dots, cross-hatch, etc.) implements this protocol.
public protocol FillGenerator {
    /// Generates fill operations for a polygon.
    /// - Parameters:
    ///   - points: Vertices of the polygon as [[x, y], ...]
    ///   - options: Rendering options
    /// - Returns: An OperationSet containing the fill operations
    func fillPolygon(points: [[Float]], options: Options) -> OperationSet?
    
    /// Generates fill operations for an ellipse.
    /// - Parameters:
    ///   - cx: Center x coordinate
    ///   - cy: Center y coordinate
    ///   - rx: Horizontal radius
    ///   - ry: Vertical radius
    ///   - options: Rendering options
    /// - Returns: An OperationSet containing the fill operations
    func fillEllipse(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet?
    
    /// Generates fill operations for an arc.
    /// - Parameters:
    ///   - cx: Center x coordinate
    ///   - cy: Center y coordinate
    ///   - rx: Horizontal radius
    ///   - ry: Vertical radius
    ///   - start: Start angle in radians
    ///   - stop: End angle in radians
    ///   - options: Rendering options
    /// - Returns: An OperationSet containing the fill operations, or nil if not supported
    func fillArc(cx: Float, cy: Float, rx: Float, ry: Float, start: Float, stop: Float, options: Options) -> OperationSet?
}

// MARK: - Default Implementations

extension FillGenerator {
    /// Default arc fill - most fillers don't support arc-specific fills
    public func fillArc(cx: Float, cy: Float, rx: Float, ry: Float, start: Float, stop: Float, options: Options) -> OperationSet? {
        // Default: approximate arc as polygon segments + center
        var points: [[Float]] = [[cx, cy]]
        let increment = (stop - start) / options.curveStepCount
        
        var angle = start
        while angle <= stop {
            points.append([cx + rx * cos(angle), cy + ry * sin(angle)])
            angle += increment
        }
        points.append([cx + rx * cos(stop), cy + ry * sin(stop)])
        
        return fillPolygon(points: points, options: options)
    }
}

// MARK: - Fill Pattern Factory

/// Factory for creating fill pattern generators.
public struct FillPatternFactory {
    
    /// Cached filler instances (they are stateless, so can be reused)
    private static var fillers: [FillStyle: FillGenerator] = [:]
    
    /// Returns a filler for the specified fill style.
    /// - Parameter style: The fill style
    /// - Returns: A FillGenerator implementation
    public static func filler(for style: FillStyle) -> FillGenerator {
        if let cached = fillers[style] {
            return cached
        }
        
        let newFiller: FillGenerator
        switch style {
        case .hachure:
            newFiller = HachureFiller()
        case .solid:
            newFiller = SolidFiller()
        case .zigzag:
            newFiller = ZigzagFiller()
        case .crossHatch:
            newFiller = CrossHatchFiller()
        case .dots:
            newFiller = DotsFiller()
        case .dashed:
            newFiller = DashedFiller()
        case .zigzagLine:
            newFiller = ZigzagLineFiller()
        case .sunBurst, .starBurst:
            newFiller = StarburstFiller()
        case .scribble:
            // Scribble is handled natively in SwiftUIRenderer
            newFiller = HachureFiller()
        }
        
        fillers[style] = newFiller
        return newFiller
    }
}

// MARK: - Helper Structures

/// Represents a line segment for fill pattern generation.
public struct FillLine {
    public let start: (x: Float, y: Float)
    public let end: (x: Float, y: Float)
    
    public init(start: (Float, Float), end: (Float, Float)) {
        self.start = start
        self.end = end
    }
    
    public var length: Float {
        let dx = end.x - start.x
        let dy = end.y - start.y
        return sqrt(dx * dx + dy * dy)
    }
}

/// Helper for line intersection calculations.
public struct LineHelper {
    
    /// Represents a line equation: ax + by + c = 0
    public struct Line {
        let a: Float
        let b: Float
        let c: Float
        let p1: (x: Float, y: Float)
        let p2: (x: Float, y: Float)
        let isUndefined: Bool
        
        public init(p1: (Float, Float), p2: (Float, Float)) {
            self.p1 = p1
            self.p2 = p2
            self.a = p2.1 - p1.1  // y2 - y1
            self.b = p1.0 - p2.0  // x1 - x2
            self.c = p2.0 * p1.1 - p1.0 * p2.1
            self.isUndefined = (a == 0 && b == 0 && c == 0)
        }
    }
    
    /// Finds intersection point between two line segments.
    /// - Parameters:
    ///   - l1: First line segment
    ///   - l2: Second line segment
    /// - Returns: Intersection point if exists and within both segments
    public static func intersection(_ l1: Line, _ l2: Line) -> (x: Float, y: Float)? {
        if l1.isUndefined || l2.isUndefined {
            return nil
        }
        
        var slope1 = Float.greatestFiniteMagnitude
        var slope2 = Float.greatestFiniteMagnitude
        var intercept1: Float = 0
        var intercept2: Float = 0
        
        if abs(l1.b) > 1e-5 {
            slope1 = -l1.a / l1.b
            intercept1 = -l1.c / l1.b
        }
        
        if abs(l2.b) > 1e-5 {
            slope2 = -l2.a / l2.b
            intercept2 = -l2.c / l2.b
        }
        
        // Both vertical
        if slope1 == .greatestFiniteMagnitude && slope2 == .greatestFiniteMagnitude {
            return nil
        }
        
        var xi: Float
        var yi: Float
        
        // First line is vertical
        if slope1 == .greatestFiniteMagnitude {
            xi = l1.p1.x
            yi = slope2 * xi + intercept2
            if !inRange(yi, l1.p1.y, l1.p2.y) || !inRange(yi, l2.p1.y, l2.p2.y) {
                return nil
            }
            if abs(l2.a) < 1e-5 && !inRange(xi, l2.p1.x, l2.p2.x) {
                return nil
            }
            return (xi, yi)
        }
        
        // Second line is vertical
        if slope2 == .greatestFiniteMagnitude {
            xi = l2.p1.x
            yi = slope1 * xi + intercept1
            if !inRange(yi, l1.p1.y, l1.p2.y) || !inRange(yi, l2.p1.y, l2.p2.y) {
                return nil
            }
            if abs(l1.a) < 1e-5 && !inRange(xi, l1.p1.x, l1.p2.x) {
                return nil
            }
            return (xi, yi)
        }
        
        // Parallel lines
        if slope1 == slope2 {
            if intercept1 == intercept2 {
                // Same line - check if segments overlap
                if inRange(l1.p1.x, l2.p1.x, l2.p2.x) {
                    return l1.p1
                }
                if inRange(l1.p2.x, l2.p1.x, l2.p2.x) {
                    return l1.p2
                }
            }
            return nil
        }
        
        // General case
        xi = (intercept2 - intercept1) / (slope1 - slope2)
        yi = slope1 * xi + intercept1
        
        if !inRange(xi, l1.p1.x, l1.p2.x) || !inRange(xi, l2.p1.x, l2.p2.x) {
            return nil
        }
        
        return (xi, yi)
    }
    
    /// Checks if a value is in range [a, b] or [b, a].
    private static func inRange(_ value: Float, _ a: Float, _ b: Float) -> Bool {
        let min = Swift.min(a, b) - 1e-5
        let max = Swift.max(a, b) + 1e-5
        return value >= min && value <= max
    }
    
    /// Finds all intersections between a line and polygon edges.
    public static func linePolygonIntersections(
        line: (start: (Float, Float), end: (Float, Float)),
        polygon: [[Float]]
    ) -> [(x: Float, y: Float)] {
        var intersections: [(x: Float, y: Float)] = []
        let scanLine = Line(p1: line.start, p2: line.end)
        
        for i in 0..<polygon.count {
            let j = (i + 1) % polygon.count
            let edge = Line(
                p1: (polygon[i][0], polygon[i][1]),
                p2: (polygon[j][0], polygon[j][1])
            )
            
            if let point = intersection(scanLine, edge) {
                intersections.append(point)
            }
        }
        
        return intersections
    }
}

