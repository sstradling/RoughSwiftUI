//
//  RoughMath.swift
//  RoughSwift
//
//  Native Swift implementation of rough.js core math algorithms.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation
import CoreGraphics

// MARK: - Random Number Generation

/// Core randomization functions for rough.js-style rendering.
/// These functions introduce controlled randomness to create hand-drawn effects.
public struct RoughMath {
    
    // MARK: - Random Offset Functions
    
    /// Returns a random offset within the range [-max, max] scaled by roughness.
    /// - Parameters:
    ///   - max: Maximum offset value
    ///   - options: Options containing roughness parameter
    /// - Returns: A random offset value
    @inlinable
    public static func randOffset(_ max: Float, options: Options) -> Float {
        randOffsetWithRange(-max, max, options: options)
    }
    
    /// Returns a random value in the range [min, max] scaled by roughness.
    /// - Parameters:
    ///   - min: Minimum value
    ///   - max: Maximum value
    ///   - options: Options containing roughness parameter
    /// - Returns: A random value in the specified range
    @inlinable
    public static func randOffsetWithRange(_ min: Float, _ max: Float, options: Options) -> Float {
        options.roughness * (Float.random(in: 0...1) * (max - min) + min)
    }
    
    // MARK: - Line Operations
    
    /// Generates operations for a double-stroked rough line (the signature rough.js effect).
    /// - Parameters:
    ///   - x1: Start x coordinate
    ///   - y1: Start y coordinate
    ///   - x2: End x coordinate
    ///   - y2: End y coordinate
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the double line
    public static func doubleLineOps(
        x1: Float, y1: Float,
        x2: Float, y2: Float,
        options: Options
    ) -> [Operation] {
        let ops1 = lineOps(x1: x1, y1: y1, x2: x2, y2: y2, options: options, move: true, overlay: false)
        let ops2 = lineOps(x1: x1, y1: y1, x2: x2, y2: y2, options: options, move: true, overlay: true)
        return ops1 + ops2
    }
    
    /// Generates operations for a single rough line with bowing effect.
    /// - Parameters:
    ///   - x1: Start x coordinate
    ///   - y1: Start y coordinate
    ///   - x2: End x coordinate
    ///   - y2: End y coordinate
    ///   - options: Rendering options
    ///   - move: Whether to include a move operation at the start
    ///   - overlay: Whether this is an overlay pass (uses different randomness)
    /// - Returns: Array of operations representing the line
    public static func lineOps(
        x1: Float, y1: Float,
        x2: Float, y2: Float,
        options: Options,
        move: Bool,
        overlay: Bool
    ) -> [Operation] {
        let lengthSq = pow(x1 - x2, 2) + pow(y1 - y2, 2)
        var maxOffset = options.maxRandomnessOffset
        
        // Reduce randomness for short lines
        if maxOffset * maxOffset * 100 > lengthSq {
            maxOffset = sqrt(lengthSq) / 10
        }
        
        let halfOffset = maxOffset / 2
        let divergePoint: Float = 0.2 + 0.2 * Float.random(in: 0...1)
        
        // Bowing effect - perpendicular displacement
        var midDispX = options.bowing * options.maxRandomnessOffset * (y2 - y1) / 200
        var midDispY = options.bowing * options.maxRandomnessOffset * (x1 - x2) / 200
        midDispX = randOffset(midDispX, options: options)
        midDispY = randOffset(midDispY, options: options)
        
        var ops: [Operation] = []
        
        // Helper closures for randomness
        let halfOffsetRand = { randOffset(halfOffset, options: options) }
        let fullOffsetRand = { randOffset(maxOffset, options: options) }
        
        if move {
            if overlay {
                ops.append(Move(data: [x1 + halfOffsetRand(), y1 + halfOffsetRand()]))
            } else {
                ops.append(Move(data: [x1 + randOffset(maxOffset, options: options),
                                       y1 + randOffset(maxOffset, options: options)]))
            }
        }
        
        if overlay {
            ops.append(BezierCurveTo(data: [
                midDispX + x1 + (x2 - x1) * divergePoint + halfOffsetRand(),
                midDispY + y1 + (y2 - y1) * divergePoint + halfOffsetRand(),
                midDispX + x1 + 2 * (x2 - x1) * divergePoint + halfOffsetRand(),
                midDispY + y1 + 2 * (y2 - y1) * divergePoint + halfOffsetRand(),
                x2 + halfOffsetRand(),
                y2 + halfOffsetRand()
            ]))
        } else {
            ops.append(BezierCurveTo(data: [
                midDispX + x1 + (x2 - x1) * divergePoint + fullOffsetRand(),
                midDispY + y1 + (y2 - y1) * divergePoint + fullOffsetRand(),
                midDispX + x1 + 2 * (x2 - x1) * divergePoint + fullOffsetRand(),
                midDispY + y1 + 2 * (y2 - y1) * divergePoint + fullOffsetRand(),
                x2 + fullOffsetRand(),
                y2 + fullOffsetRand()
            ]))
        }
        
        return ops
    }
    
    // MARK: - Curve Operations
    
    /// Generates operations for a rough curve through the given points.
    /// Uses Catmull-Rom spline conversion to Bezier curves.
    /// - Parameters:
    ///   - points: Array of points defining the curve
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the curve
    public static func curveOps(points: [[Float]], options: Options) -> [Operation] {
        let o1 = curveWithOffset(points: points, offset: 1 * (1 + 0.2 * options.roughness), options: options)
        let o2 = curveWithOffset(points: points, offset: 1.5 * (1 + 0.22 * options.roughness), options: options)
        return o1 + o2
    }
    
    /// Generates a curve with specified offset/roughness.
    private static func curveWithOffset(points: [[Float]], offset: Float, options: Options) -> [Operation] {
        var ps: [[Float]] = []
        
        ps.append([points[0][0] + randOffset(offset, options: options),
                   points[0][1] + randOffset(offset, options: options)])
        ps.append([points[0][0] + randOffset(offset, options: options),
                   points[0][1] + randOffset(offset, options: options)])
        
        for i in 1..<points.count {
            ps.append([points[i][0] + randOffset(offset, options: options),
                       points[i][1] + randOffset(offset, options: options)])
            if i == points.count - 1 {
                ps.append([points[i][0] + randOffset(offset, options: options),
                           points[i][1] + randOffset(offset, options: options)])
            }
        }
        
        return bezierFromPoints(ps, close: nil, options: options)
    }
    
    /// Converts a series of points to Bezier curve operations using Catmull-Rom conversion.
    /// - Parameters:
    ///   - points: Control points
    ///   - close: Optional closing point
    ///   - options: Rendering options
    /// - Returns: Array of Bezier curve operations
    public static func bezierFromPoints(_ points: [[Float]], close: [Float]?, options: Options) -> [Operation] {
        var ops: [Operation] = []
        let len = points.count
        
        if len > 3 {
            var b: [[Float]] = []
            let s: Float = 1 - options.curveTightness
            ops.append(Move(data: [points[1][0], points[1][1]]))
            
            for i in 1..<(len - 2) {
                let cachedVertArray = points[i]
                b = [[cachedVertArray[0], cachedVertArray[1]]]
                b.append([
                    cachedVertArray[0] + (s * points[i + 1][0] - s * points[i - 1][0]) / 6,
                    cachedVertArray[1] + (s * points[i + 1][1] - s * points[i - 1][1]) / 6
                ])
                b.append([
                    points[i + 1][0] + (s * points[i][0] - s * points[i + 2][0]) / 6,
                    points[i + 1][1] + (s * points[i][1] - s * points[i + 2][1]) / 6
                ])
                b.append([points[i + 1][0], points[i + 1][1]])
                ops.append(BezierCurveTo(data: [
                    b[1][0], b[1][1],
                    b[2][0], b[2][1],
                    b[3][0], b[3][1]
                ]))
            }
            
            if let closePoint = close, closePoint.count == 2 {
                let maxOff = options.maxRandomnessOffset
                ops.append(LineTo(data: [
                    closePoint[0] + randOffset(maxOff, options: options),
                    closePoint[1] + randOffset(maxOff, options: options)
                ]))
            }
        } else if len == 3 {
            ops.append(Move(data: [points[1][0], points[1][1]]))
            ops.append(BezierCurveTo(data: [
                points[1][0], points[1][1],
                points[2][0], points[2][1],
                points[2][0], points[2][1]
            ]))
        } else if len == 2 {
            ops.append(contentsOf: doubleLineOps(
                x1: points[0][0], y1: points[0][1],
                x2: points[1][0], y2: points[1][1],
                options: options
            ))
        }
        
        return ops
    }
    
    // MARK: - Ellipse Operations
    
    /// Generates operations for a rough ellipse.
    /// - Parameters:
    ///   - cx: Center x coordinate
    ///   - cy: Center y coordinate
    ///   - rx: Horizontal radius
    ///   - ry: Vertical radius
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the ellipse
    public static func ellipseOps(
        cx: Float, cy: Float,
        rx: Float, ry: Float,
        options: Options
    ) -> [Operation] {
        let increment = (2 * Float.pi) / options.curveStepCount
        var rx = rx
        var ry = ry
        
        // Add slight randomness to radii
        rx += randOffset(rx * 0.05, options: options)
        ry += randOffset(ry * 0.05, options: options)
        
        let o1 = ellipseWithParams(
            increment: increment, cx: cx, cy: cy, rx: rx, ry: ry,
            offset: 1, overlap: increment * randOffsetWithRange(0.1, randOffsetWithRange(0.4, 1, options: options), options: options),
            options: options
        )
        let o2 = ellipseWithParams(
            increment: increment, cx: cx, cy: cy, rx: rx, ry: ry,
            offset: 1.5, overlap: 0,
            options: options
        )
        return o1 + o2
    }
    
    /// Generates ellipse with specific parameters.
    private static func ellipseWithParams(
        increment: Float, cx: Float, cy: Float, rx: Float, ry: Float,
        offset: Float, overlap: Float,
        options: Options
    ) -> [Operation] {
        let radOffset = randOffset(0.5, options: options) - Float.pi / 2
        var points: [[Float]] = []
        
        points.append([
            randOffset(offset, options: options) + cx + 0.9 * rx * cos(radOffset - increment),
            randOffset(offset, options: options) + cy + 0.9 * ry * sin(radOffset - increment)
        ])
        
        var angle = radOffset
        while angle < Float.pi * 2 + radOffset - 0.01 {
            points.append([
                randOffset(offset, options: options) + cx + rx * cos(angle),
                randOffset(offset, options: options) + cy + ry * sin(angle)
            ])
            angle += increment
        }
        
        points.append([
            randOffset(offset, options: options) + cx + rx * cos(radOffset + Float.pi * 2 + overlap * 0.5),
            randOffset(offset, options: options) + cy + ry * sin(radOffset + Float.pi * 2 + overlap * 0.5)
        ])
        points.append([
            randOffset(offset, options: options) + cx + 0.98 * rx * cos(radOffset + overlap),
            randOffset(offset, options: options) + cy + 0.98 * ry * sin(radOffset + overlap)
        ])
        points.append([
            randOffset(offset, options: options) + cx + 0.9 * rx * cos(radOffset + overlap * 0.5),
            randOffset(offset, options: options) + cy + 0.9 * ry * sin(radOffset + overlap * 0.5)
        ])
        
        return bezierFromPoints(points, close: nil, options: options)
    }
    
    // MARK: - Arc Operations
    
    /// Generates operations for a rough arc.
    /// - Parameters:
    ///   - cx: Center x coordinate
    ///   - cy: Center y coordinate
    ///   - rx: Horizontal radius
    ///   - ry: Vertical radius
    ///   - start: Start angle in radians
    ///   - stop: End angle in radians
    ///   - closed: Whether to close the arc
    ///   - roughClosure: Whether to use rough lines for closure
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the arc
    public static func arcOps(
        cx: Float, cy: Float,
        rx: Float, ry: Float,
        start: Float, stop: Float,
        closed: Bool,
        roughClosure: Bool,
        options: Options
    ) -> [Operation] {
        var rx = rx
        var ry = ry
        rx += randOffset(rx * 0.01, options: options)
        ry += randOffset(ry * 0.01, options: options)
        
        var strt = start
        var stp = stop
        
        while strt < 0 {
            strt += Float.pi * 2
            stp += Float.pi * 2
        }
        if stp - strt > Float.pi * 2 {
            strt = 0
            stp = Float.pi * 2
        }
        
        let increment = (2 * Float.pi) / options.curveStepCount
        let arcInc = min(increment / 2, (stp - strt) / 2)
        
        let o1 = arcWithParams(arcInc: arcInc, cx: cx, cy: cy, rx: rx, ry: ry, start: strt, stop: stp, offset: 1, options: options)
        let o2 = arcWithParams(arcInc: arcInc, cx: cx, cy: cy, rx: rx, ry: ry, start: strt, stop: stp, offset: 1.5, options: options)
        
        var ops = o1 + o2
        
        if closed {
            if roughClosure {
                ops.append(contentsOf: doubleLineOps(x1: cx, y1: cy, x2: cx + rx * cos(strt), y2: cy + ry * sin(strt), options: options))
                ops.append(contentsOf: doubleLineOps(x1: cx, y1: cy, x2: cx + rx * cos(stp), y2: cy + ry * sin(stp), options: options))
            } else {
                ops.append(LineTo(data: [cx, cy]))
                ops.append(LineTo(data: [cx + rx * cos(strt), cy + ry * sin(strt)]))
            }
        }
        
        return ops
    }
    
    /// Generates arc with specific parameters.
    private static func arcWithParams(
        arcInc: Float, cx: Float, cy: Float,
        rx: Float, ry: Float,
        start: Float, stop: Float,
        offset: Float, options: Options
    ) -> [Operation] {
        let radOffset = start + randOffset(0.1, options: options)
        var points: [[Float]] = []
        
        points.append([
            randOffset(offset, options: options) + cx + 0.9 * rx * cos(radOffset - arcInc),
            randOffset(offset, options: options) + cy + 0.9 * ry * sin(radOffset - arcInc)
        ])
        
        var angle = radOffset
        while angle <= stop {
            points.append([
                randOffset(offset, options: options) + cx + rx * cos(angle),
                randOffset(offset, options: options) + cy + ry * sin(angle)
            ])
            angle += arcInc
        }
        
        points.append([
            cx + rx * cos(stop),
            cy + ry * sin(stop)
        ])
        points.append([
            cx + rx * cos(stop),
            cy + ry * sin(stop)
        ])
        
        return bezierFromPoints(points, close: nil, options: options)
    }
    
    // MARK: - Polygon Operations
    
    /// Generates operations for a rough polygon outline.
    /// - Parameters:
    ///   - points: Vertices of the polygon
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the polygon outline
    public static func polygonOps(points: [[Float]], options: Options) -> [Operation] {
        return linearPathOps(points: points, close: true, options: options)
    }
    
    /// Generates operations for a rough linear path (open or closed).
    /// - Parameters:
    ///   - points: Vertices of the path
    ///   - close: Whether to close the path
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the path
    public static func linearPathOps(points: [[Float]], close: Bool, options: Options) -> [Operation] {
        let len = points.count
        if len > 2 {
            var ops: [Operation] = []
            for i in 0..<(len - 1) {
                ops.append(contentsOf: doubleLineOps(
                    x1: points[i][0], y1: points[i][1],
                    x2: points[i + 1][0], y2: points[i + 1][1],
                    options: options
                ))
            }
            if close {
                ops.append(contentsOf: doubleLineOps(
                    x1: points[len - 1][0], y1: points[len - 1][1],
                    x2: points[0][0], y2: points[0][1],
                    options: options
                ))
            }
            return ops
        } else if len == 2 {
            return doubleLineOps(
                x1: points[0][0], y1: points[0][1],
                x2: points[1][0], y2: points[1][1],
                options: options
            )
        }
        return []
    }
    
    /// Generates operations for a solid fill path (no roughness).
    /// - Parameters:
    ///   - points: Vertices of the polygon
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the fill path
    public static func solidFillPathOps(points: [[Float]], options: Options) -> [Operation] {
        var ops: [Operation] = []
        let len = points.count
        
        if len > 0 {
            let maxOffset = options.maxRandomnessOffset
            ops.append(Move(data: [
                points[0][0] + randOffset(maxOffset, options: options),
                points[0][1] + randOffset(maxOffset, options: options)
            ]))
            for i in 1..<len {
                ops.append(LineTo(data: [
                    points[i][0] + randOffset(maxOffset, options: options),
                    points[i][1] + randOffset(maxOffset, options: options)
                ]))
            }
        }
        
        return ops
    }
    
    // MARK: - Rectangle Operations
    
    /// Generates operations for a rough rectangle.
    /// - Parameters:
    ///   - x: Top-left x coordinate
    ///   - y: Top-left y coordinate
    ///   - width: Width of rectangle
    ///   - height: Height of rectangle
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the rectangle outline
    public static func rectangleOps(
        x: Float, y: Float,
        width: Float, height: Float,
        options: Options
    ) -> [Operation] {
        let points: [[Float]] = [
            [x, y],
            [x + width, y],
            [x + width, y + height],
            [x, y + height]
        ]
        return polygonOps(points: points, options: options)
    }
    
    // MARK: - Rounded Rectangle Operations
    
    /// Generates operations for a rough rounded rectangle.
    /// - Parameters:
    ///   - x: Top-left x coordinate
    ///   - y: Top-left y coordinate
    ///   - width: Width of rectangle
    ///   - height: Height of rectangle
    ///   - cornerRadius: Radius of rounded corners
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the rounded rectangle outline
    public static func roundedRectangleOps(
        x: Float, y: Float,
        width: Float, height: Float,
        cornerRadius: Float,
        options: Options
    ) -> [Operation] {
        // Clamp corner radius to valid range
        let maxRadius = min(width, height) / 2
        let r = min(cornerRadius, maxRadius)
        
        if r <= 0 {
            // No rounding, use regular rectangle
            return rectangleOps(x: x, y: y, width: width, height: height, options: options)
        }
        
        var ops: [Operation] = []
        
        // Draw the four sides with arcs at corners
        // Top edge (left to right)
        ops.append(contentsOf: doubleLineOps(x1: x + r, y1: y, x2: x + width - r, y2: y, options: options))
        
        // Top-right corner arc
        ops.append(contentsOf: cornerArcOps(cx: x + width - r, cy: y + r, r: r, startAngle: -Float.pi / 2, endAngle: 0, options: options))
        
        // Right edge (top to bottom)
        ops.append(contentsOf: doubleLineOps(x1: x + width, y1: y + r, x2: x + width, y2: y + height - r, options: options))
        
        // Bottom-right corner arc
        ops.append(contentsOf: cornerArcOps(cx: x + width - r, cy: y + height - r, r: r, startAngle: 0, endAngle: Float.pi / 2, options: options))
        
        // Bottom edge (right to left)
        ops.append(contentsOf: doubleLineOps(x1: x + width - r, y1: y + height, x2: x + r, y2: y + height, options: options))
        
        // Bottom-left corner arc
        ops.append(contentsOf: cornerArcOps(cx: x + r, cy: y + height - r, r: r, startAngle: Float.pi / 2, endAngle: Float.pi, options: options))
        
        // Left edge (bottom to top)
        ops.append(contentsOf: doubleLineOps(x1: x, y1: y + height - r, x2: x, y2: y + r, options: options))
        
        // Top-left corner arc
        ops.append(contentsOf: cornerArcOps(cx: x + r, cy: y + r, r: r, startAngle: Float.pi, endAngle: 3 * Float.pi / 2, options: options))
        
        return ops
    }
    
    /// Generates rough operations for a corner arc (quarter circle).
    private static func cornerArcOps(
        cx: Float, cy: Float, r: Float,
        startAngle: Float, endAngle: Float,
        options: Options
    ) -> [Operation] {
        let steps = max(2, Int(options.curveStepCount / 4))
        let increment = (endAngle - startAngle) / Float(steps)
        
        var points: [[Float]] = []
        var angle = startAngle
        
        while angle <= endAngle + 0.001 {
            points.append([
                cx + r * cos(angle) + randOffset(1, options: options),
                cy + r * sin(angle) + randOffset(1, options: options)
            ])
            angle += increment
        }
        
        // Ensure we hit the exact end angle
        let lastPoint = [cx + r * cos(endAngle), cy + r * sin(endAngle)]
        if points.isEmpty || (points.last![0] != lastPoint[0] || points.last![1] != lastPoint[1]) {
            points.append(lastPoint)
        }
        
        // Convert points to bezier curves
        if points.count >= 2 {
            return bezierFromPoints(points, close: nil, options: options)
        }
        
        return []
    }
    
    /// Generates polygon approximation points for a rounded rectangle (for fills).
    /// - Parameters:
    ///   - x: Top-left x coordinate
    ///   - y: Top-left y coordinate
    ///   - width: Width of rectangle
    ///   - height: Height of rectangle
    ///   - cornerRadius: Radius of rounded corners
    ///   - arcSteps: Number of points per corner arc (default 8)
    /// - Returns: Array of polygon points approximating the rounded rectangle
    public static func roundedRectanglePolygonPoints(
        x: Float, y: Float,
        width: Float, height: Float,
        cornerRadius: Float,
        arcSteps: Int = 8
    ) -> [[Float]] {
        let maxRadius = min(width, height) / 2
        let r = min(cornerRadius, maxRadius)
        
        if r <= 0 {
            return [
                [x, y],
                [x + width, y],
                [x + width, y + height],
                [x, y + height]
            ]
        }
        
        var points: [[Float]] = []
        
        // Top-left corner
        for i in 0...arcSteps {
            let angle = Float.pi + Float(i) * (Float.pi / 2) / Float(arcSteps)
            points.append([x + r + r * cos(angle), y + r + r * sin(angle)])
        }
        
        // Top-right corner
        for i in 0...arcSteps {
            let angle = -Float.pi / 2 + Float(i) * (Float.pi / 2) / Float(arcSteps)
            points.append([x + width - r + r * cos(angle), y + r + r * sin(angle)])
        }
        
        // Bottom-right corner
        for i in 0...arcSteps {
            let angle = Float(i) * (Float.pi / 2) / Float(arcSteps)
            points.append([x + width - r + r * cos(angle), y + height - r + r * sin(angle)])
        }
        
        // Bottom-left corner
        for i in 0...arcSteps {
            let angle = Float.pi / 2 + Float(i) * (Float.pi / 2) / Float(arcSteps)
            points.append([x + r + r * cos(angle), y + height - r + r * sin(angle)])
        }
        
        return points
    }
    
    // MARK: - Egg Shape Operations
    
    /// Generates operations for a rough egg shape.
    /// The egg is an asymmetric ellipse, wider at one end.
    /// - Parameters:
    ///   - cx: Center x coordinate
    ///   - cy: Center y coordinate
    ///   - width: Width of the egg at its widest point
    ///   - height: Total height of the egg
    ///   - tilt: Asymmetry factor (0.0 = symmetric, positive = narrower top, negative = narrower bottom)
    ///   - options: Rendering options
    /// - Returns: Array of operations representing the egg outline
    public static func eggOps(
        cx: Float, cy: Float,
        width: Float, height: Float,
        tilt: Float,
        options: Options
    ) -> [Operation] {
        let increment = (2 * Float.pi) / options.curveStepCount
        var rx = width / 2
        var ry = height / 2
        
        // Add slight randomness to radii
        rx += randOffset(rx * 0.05, options: options)
        ry += randOffset(ry * 0.05, options: options)
        
        let o1 = eggWithParams(
            increment: increment, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt,
            offset: 1, overlap: increment * randOffsetWithRange(0.1, randOffsetWithRange(0.4, 1, options: options), options: options),
            options: options
        )
        let o2 = eggWithParams(
            increment: increment, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt,
            offset: 1.5, overlap: 0,
            options: options
        )
        return o1 + o2
    }
    
    /// Generates egg shape with specific parameters.
    private static func eggWithParams(
        increment: Float, cx: Float, cy: Float, rx: Float, ry: Float, tilt: Float,
        offset: Float, overlap: Float,
        options: Options
    ) -> [Operation] {
        let radOffset = randOffset(0.5, options: options) - Float.pi / 2
        var points: [[Float]] = []
        
        // Initial point with slight offset
        let (initX, initY) = eggPoint(angle: radOffset - increment, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt)
        points.append([
            randOffset(offset, options: options) + initX * 0.9 + cx * 0.1,
            randOffset(offset, options: options) + initY * 0.9 + cy * 0.1
        ])
        
        var angle = radOffset
        while angle < Float.pi * 2 + radOffset - 0.01 {
            let (px, py) = eggPoint(angle: angle, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt)
            points.append([
                randOffset(offset, options: options) + px,
                randOffset(offset, options: options) + py
            ])
            angle += increment
        }
        
        // Overlap points for smooth closure
        let (overlapX1, overlapY1) = eggPoint(angle: radOffset + Float.pi * 2 + overlap * 0.5, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt)
        points.append([
            randOffset(offset, options: options) + overlapX1,
            randOffset(offset, options: options) + overlapY1
        ])
        
        let (overlapX2, overlapY2) = eggPoint(angle: radOffset + overlap, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt)
        points.append([
            randOffset(offset, options: options) + overlapX2 * 0.98 + cx * 0.02,
            randOffset(offset, options: options) + overlapY2 * 0.98 + cy * 0.02
        ])
        
        let (overlapX3, overlapY3) = eggPoint(angle: radOffset + overlap * 0.5, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt)
        points.append([
            randOffset(offset, options: options) + overlapX3 * 0.9 + cx * 0.1,
            randOffset(offset, options: options) + overlapY3 * 0.9 + cy * 0.1
        ])
        
        return bezierFromPoints(points, close: nil, options: options)
    }
    
    /// Calculates a point on the egg curve at a given angle.
    /// The egg shape is achieved by modulating the horizontal radius based on the y-position.
    private static func eggPoint(
        angle: Float, cx: Float, cy: Float, rx: Float, ry: Float, tilt: Float
    ) -> (Float, Float) {
        // Normalize the vertical position (-1 at top, 1 at bottom)
        let normalizedY = sin(angle)
        
        // Modulate the horizontal radius based on vertical position
        // When tilt > 0: top is narrower (egg pointing up)
        // When tilt < 0: bottom is narrower (egg pointing down)
        let radiusModulation = 1.0 - tilt * normalizedY
        let effectiveRx = rx * radiusModulation
        
        let x = cx + effectiveRx * cos(angle)
        let y = cy + ry * sin(angle)
        
        return (x, y)
    }
    
    /// Generates polygon approximation points for an egg shape (for fills).
    /// - Parameters:
    ///   - cx: Center x coordinate
    ///   - cy: Center y coordinate
    ///   - width: Width of the egg at its widest point
    ///   - height: Total height of the egg
    ///   - tilt: Asymmetry factor
    ///   - stepCount: Number of points around the perimeter
    /// - Returns: Array of polygon points approximating the egg
    public static func eggPolygonPoints(
        cx: Float, cy: Float,
        width: Float, height: Float,
        tilt: Float,
        stepCount: Float
    ) -> [[Float]] {
        let rx = width / 2
        let ry = height / 2
        let increment = (2 * Float.pi) / stepCount
        
        var points: [[Float]] = []
        var angle: Float = 0
        
        while angle < 2 * Float.pi {
            let (x, y) = eggPoint(angle: angle, cx: cx, cy: cy, rx: rx, ry: ry, tilt: tilt)
            points.append([x, y])
            angle += increment
        }
        
        return points
    }
}

// MARK: - Geometry Utilities

extension RoughMath {
    
    /// Calculates the centroid of a polygon.
    /// - Parameter points: Vertices of the polygon
    /// - Returns: Centroid point as [x, y]
    public static func polygonCentroid(_ points: [[Float]]) -> [Float] {
        var area: Float = 0
        var cx: Float = 0
        var cy: Float = 0
        
        for i in 0..<points.count {
            let j = (i + 1) % points.count
            let factor = points[i][0] * points[j][1] - points[j][0] * points[i][1]
            area += factor
            cx += (points[i][0] + points[j][0]) * factor
            cy += (points[i][1] + points[j][1]) * factor
        }
        
        area /= 2
        let areaFactor = 6 * area
        
        return [cx / areaFactor, cy / areaFactor]
    }
    
    /// Calculates the bounding box of a polygon.
    /// - Parameter points: Vertices of the polygon
    /// - Returns: Tuple of (minX, maxX, minY, maxY)
    public static func polygonBounds(_ points: [[Float]]) -> (minX: Float, maxX: Float, minY: Float, maxY: Float) {
        guard let first = points.first else {
            return (0, 0, 0, 0)
        }
        
        var minX = first[0]
        var maxX = first[0]
        var minY = first[1]
        var maxY = first[1]
        
        for point in points.dropFirst() {
            minX = min(minX, point[0])
            maxX = max(maxX, point[0])
            minY = min(minY, point[1])
            maxY = max(maxY, point[1])
        }
        
        return (minX, maxX, minY, maxY)
    }
    
    /// Calculates the length of a line segment.
    /// - Parameter segment: Line as [[x1, y1], [x2, y2]]
    /// - Returns: Length of the segment
    public static func lineLength(_ segment: [[Float]]) -> Float {
        let dx = segment[1][0] - segment[0][0]
        let dy = segment[1][1] - segment[0][1]
        return sqrt(dx * dx + dy * dy)
    }
}

