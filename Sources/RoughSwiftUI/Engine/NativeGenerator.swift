//
//  NativeGenerator.swift
//  RoughSwift
//
//  Native Swift implementation of rough.js generator.
//  Replaces JavaScriptCore-based Generator for better performance.
//
//  Created by Seth Stradling on 03/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//

import Foundation
import CoreGraphics
import UIKit

/// Native Swift generator for rough.js-style drawings.
/// Provides the same API as the JS-based Generator but with native performance.
@MainActor
public final class NativeGenerator {
    
    /// The canvas/drawing surface size.
    public let size: CGSize
    
    /// Optional cache for generated drawings.
    public weak var drawingCache: DrawingCache?
    
    /// Creates a native generator for the specified size.
    /// - Parameter size: The drawing surface size
    /// - Parameter drawingCache: Optional cache for reusing drawings
    public init(size: CGSize, drawingCache: DrawingCache? = nil) {
        self.size = size
        self.drawingCache = drawingCache
    }
    
    // MARK: - Main Generation Method
    
    /// Generates a Drawing for the given drawable with options.
    /// - Parameters:
    ///   - drawable: The shape to draw
    ///   - options: Rendering options
    /// - Returns: A Drawing containing operation sets for rendering
    public func generate(drawable: Drawable, options: Options = Options()) -> Drawing? {
        // Check cache first if available
        if let cache = drawingCache {
            let key = DrawingCacheKey(drawable: drawable, size: size, options: options)
            return cache.getOrGenerate(key) {
                generateUncached(drawable: drawable, options: options)
            }
        }
        
        return generateUncached(drawable: drawable, options: options)
    }
    
    /// Generates a Drawing without checking cache.
    private func generateUncached(drawable: Drawable, options: Options) -> Drawing? {
        let arguments: [Any]
        if let fullable = drawable as? Fulfillable {
            arguments = fullable.arguments(size: Size(width: Float(size.width), height: Float(size.height)))
        } else {
            arguments = drawable.arguments
        }
        
        let method = drawable.method
        
        switch method {
        case "line":
            return generateLine(arguments: arguments, options: options)
        case "rectangle":
            return generateRectangle(arguments: arguments, options: options)
        case "ellipse":
            return generateEllipse(arguments: arguments, options: options)
        case "circle":
            return generateCircle(arguments: arguments, options: options)
        case "linearPath":
            return generateLinearPath(arguments: arguments, options: options)
        case "polygon":
            return generatePolygon(arguments: arguments, options: options)
        case "arc":
            return generateArc(arguments: arguments, options: options)
        case "curve":
            return generateCurve(arguments: arguments, options: options)
        case "path":
            return generatePath(arguments: arguments, options: options)
        default:
            return nil
        }
    }
    
    // MARK: - Shape Generators
    
    /// Generates a rough line drawing.
    private func generateLine(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 4,
              let x1 = (arguments[0] as? NSNumber)?.floatValue,
              let y1 = (arguments[1] as? NSNumber)?.floatValue,
              let x2 = (arguments[2] as? NSNumber)?.floatValue,
              let y2 = (arguments[3] as? NSNumber)?.floatValue else {
            return nil
        }
        
        let ops = RoughMath.doubleLineOps(x1: x1, y1: y1, x2: x2, y2: y2, options: options)
        let pathSet = OperationSet(type: .path, operations: ops, path: nil, size: nil)
        
        return Drawing(shape: "line", sets: [pathSet], options: options)
    }
    
    /// Generates a rough rectangle drawing.
    private func generateRectangle(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 4,
              let x = (arguments[0] as? NSNumber)?.floatValue,
              let y = (arguments[1] as? NSNumber)?.floatValue,
              let width = (arguments[2] as? NSNumber)?.floatValue,
              let height = (arguments[3] as? NSNumber)?.floatValue else {
            return nil
        }
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generateRectangleFill(x: x, y: y, width: width, height: height, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke
        let ops = RoughMath.rectangleOps(x: x, y: y, width: width, height: height, options: options)
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))
        
        return Drawing(shape: "rectangle", sets: sets, options: options)
    }
    
    /// Generates a rough ellipse drawing.
    private func generateEllipse(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 4,
              let cx = (arguments[0] as? NSNumber)?.floatValue,
              let cy = (arguments[1] as? NSNumber)?.floatValue,
              let width = (arguments[2] as? NSNumber)?.floatValue,
              let height = (arguments[3] as? NSNumber)?.floatValue else {
            return nil
        }
        
        let rx = width / 2
        let ry = height / 2
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generateEllipseFill(cx: cx, cy: cy, rx: rx, ry: ry, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke
        let ops = RoughMath.ellipseOps(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))
        
        return Drawing(shape: "ellipse", sets: sets, options: options)
    }
    
    /// Generates a rough circle drawing.
    private func generateCircle(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 3,
              let cx = (arguments[0] as? NSNumber)?.floatValue,
              let cy = (arguments[1] as? NSNumber)?.floatValue,
              let diameter = (arguments[2] as? NSNumber)?.floatValue else {
            return nil
        }
        
        let r = diameter / 2
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generateEllipseFill(cx: cx, cy: cy, rx: r, ry: r, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke
        let ops = RoughMath.ellipseOps(cx: cx, cy: cy, rx: r, ry: r, options: options)
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))
        
        return Drawing(shape: "circle", sets: sets, options: options)
    }
    
    /// Generates a rough linear path drawing.
    private func generateLinearPath(arguments: [Any], options: Options) -> Drawing? {
        let points = extractPoints(from: arguments)
        guard !points.isEmpty else { return nil }
        
        let ops = RoughMath.linearPathOps(points: points, close: false, options: options)
        let pathSet = OperationSet(type: .path, operations: ops, path: nil, size: nil)
        
        return Drawing(shape: "linearPath", sets: [pathSet], options: options)
    }
    
    /// Generates a rough polygon drawing.
    private func generatePolygon(arguments: [Any], options: Options) -> Drawing? {
        let points = extractPoints(from: arguments)
        guard !points.isEmpty else { return nil }
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generatePolygonFill(points: points, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke
        let ops = RoughMath.polygonOps(points: points, options: options)
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))
        
        return Drawing(shape: "polygon", sets: sets, options: options)
    }
    
    /// Generates a rough arc drawing.
    private func generateArc(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 7,
              let cx = (arguments[0] as? NSNumber)?.floatValue,
              let cy = (arguments[1] as? NSNumber)?.floatValue,
              let width = (arguments[2] as? NSNumber)?.floatValue,
              let height = (arguments[3] as? NSNumber)?.floatValue,
              let start = (arguments[4] as? NSNumber)?.floatValue,
              let stop = (arguments[5] as? NSNumber)?.floatValue else {
            return nil
        }
        
        let closed = (arguments.count > 6 && (arguments[6] as? Bool) == true)
        let rx = width / 2
        let ry = height / 2
        
        var sets: [OperationSet] = []
        
        // Generate fill if closed and fill requested
        if closed {
            if let fillSet = generateArcFill(cx: cx, cy: cy, rx: rx, ry: ry, start: start, stop: stop, options: options) {
                sets.append(fillSet)
            }
        }
        
        // Generate stroke
        let ops = RoughMath.arcOps(cx: cx, cy: cy, rx: rx, ry: ry, start: start, stop: stop, closed: closed, roughClosure: true, options: options)
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))
        
        return Drawing(shape: "arc", sets: sets, options: options)
    }
    
    /// Generates a rough curve drawing.
    private func generateCurve(arguments: [Any], options: Options) -> Drawing? {
        let points = extractPoints(from: arguments)
        guard !points.isEmpty else { return nil }
        
        let ops = RoughMath.curveOps(points: points, options: options)
        let pathSet = OperationSet(type: .path, operations: ops, path: nil, size: nil)
        
        return Drawing(shape: "curve", sets: [pathSet], options: options)
    }
    
    /// Generates a rough SVG path drawing.
    private func generatePath(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 1,
              let pathString = arguments[0] as? String else {
            return nil
        }
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generatePathFill(pathString: pathString, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke using SVG path renderer
        let ops = SVGPathRenderer.pathOps(svgPath: pathString, options: options)
        sets.append(OperationSet(type: .path, operations: ops, path: pathString, size: nil))
        
        return Drawing(shape: "path", sets: sets, options: options)
    }
    
    // MARK: - Fill Generation
    
    /// Generates fill for a rectangle.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    /// The renderer will skip clear fills during drawing.
    private func generateRectangleFill(x: Float, y: Float, width: Float, height: Float, options: Options) -> OperationSet? {
        let points: [[Float]] = [
            [x, y],
            [x + width, y],
            [x + width, y + height],
            [x, y + height]
        ]
        
        return generatePolygonFill(points: points, options: options)
    }
    
    /// Generates fill for an ellipse.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generateEllipseFill(cx: Float, cy: Float, rx: Float, ry: Float, options: Options) -> OperationSet? {
        let filler = FillPatternFactory.filler(for: options.fillStyle)
        return filler.fillEllipse(cx: cx, cy: cy, rx: rx, ry: ry, options: options)
    }
    
    /// Generates fill for a polygon.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generatePolygonFill(points: [[Float]], options: Options) -> OperationSet? {
        let filler = FillPatternFactory.filler(for: options.fillStyle)
        return filler.fillPolygon(points: points, options: options)
    }
    
    /// Generates fill for an arc.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generateArcFill(cx: Float, cy: Float, rx: Float, ry: Float, start: Float, stop: Float, options: Options) -> OperationSet? {
        let filler = FillPatternFactory.filler(for: options.fillStyle)
        return filler.fillArc(cx: cx, cy: cy, rx: rx, ry: ry, start: start, stop: stop, options: options)
    }
    
    /// Generates fill for an SVG path.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generatePathFill(pathString: String, options: Options) -> OperationSet? {
        if options.fillStyle == .solid {
            // Solid fill uses the path directly
            return OperationSet(type: .path2DFill, operations: [], path: pathString, size: nil)
        } else {
            // Pattern fill
            let bezier = UIBezierPath(svgPath: pathString)
            let bounds = bezier.cgPath.boundingBox
            let polygonSize = [Float(bounds.width), Float(bounds.height)]
            
            // Create a bounding box polygon for pattern
            let points: [[Float]] = [
                [0, 0],
                [polygonSize[0], 0],
                [polygonSize[0], polygonSize[1]],
                [0, polygonSize[1]]
            ]
            
            let filler = FillPatternFactory.filler(for: options.fillStyle)
            if let fillSet = filler.fillPolygon(points: points, options: options) {
                return OperationSet(
                    type: .path2DPattern,
                    operations: fillSet.operations,
                    path: pathString,
                    size: Size(width: polygonSize[0], height: polygonSize[1])
                )
            }
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Extracts points from rough.js style arguments.
    private func extractPoints(from arguments: [Any]) -> [[Float]] {
        var points: [[Float]] = []
        
        for arg in arguments {
            if let pointDict = arg as? [String: Any],
               let x = (pointDict["x"] as? NSNumber)?.floatValue,
               let y = (pointDict["y"] as? NSNumber)?.floatValue {
                points.append([x, y])
            } else if let pointArray = arg as? [NSNumber], pointArray.count >= 2 {
                points.append([pointArray[0].floatValue, pointArray[1].floatValue])
            }
        }
        
        return points
    }
}

// MARK: - SVG Path Renderer

/// Native renderer for SVG path strings with rough.js style.
struct SVGPathRenderer {
    
    /// Internal state for path traversal.
    private class PathState {
        var position: (x: Float, y: Float) = (0, 0)
        var first: (x: Float, y: Float)?
        var bezierReflection: (x: Float, y: Float)?
        var quadReflection: (x: Float, y: Float)?
        
        func setPosition(_ x: Float, _ y: Float) {
            position = (x, y)
            if first == nil {
                first = (x, y)
            }
        }
    }
    
    /// Generates rough operations for an SVG path string.
    static func pathOps(svgPath: String, options: Options) -> [Operation] {
        let svgParser = SVGPath(svgPath)
        let commands = svgParser.commands
        
        var ops: [Operation] = []
        let state = PathState()
        
        for i in 0..<commands.count {
            let cmd = commands[i]
            let prevCmd = i > 0 ? commands[i - 1] : nil
            ops.append(contentsOf: processCommand(cmd, previous: prevCmd, state: state, options: options))
        }
        
        return ops
    }
    
    /// Processes a single SVG command and returns rough operations.
    private static func processCommand(
        _ cmd: SVGCommand,
        previous: SVGCommand?,
        state: PathState,
        options: Options
    ) -> [Operation] {
        var ops: [Operation] = []
        
        switch cmd.type {
        case .move:
            let maxOff = options.maxRandomnessOffset
            let x = Float(cmd.point.x) + RoughMath.randOffset(maxOff, options: options)
            let y = Float(cmd.point.y) + RoughMath.randOffset(maxOff, options: options)
            state.setPosition(x, y)
            ops.append(Move(data: [x, y]))
            
        case .line:
            let x = Float(cmd.point.x)
            let y = Float(cmd.point.y)
            ops.append(contentsOf: RoughMath.doubleLineOps(
                x1: state.position.x, y1: state.position.y,
                x2: x, y2: y,
                options: options
            ))
            state.setPosition(x, y)
            
        case .cubeCurve:
            let cp1x = Float(cmd.control1.x)
            let cp1y = Float(cmd.control1.y)
            let cp2x = Float(cmd.control2.x)
            let cp2y = Float(cmd.control2.y)
            let x = Float(cmd.point.x)
            let y = Float(cmd.point.y)
            
            ops.append(contentsOf: cubicCurveOps(
                x1: state.position.x, y1: state.position.y,
                cp1x: cp1x, cp1y: cp1y,
                cp2x: cp2x, cp2y: cp2y,
                x2: x, y2: y,
                state: state,
                options: options
            ))
            
            state.bezierReflection = (x + (x - cp2x), y + (y - cp2y))
            state.setPosition(x, y)
            
        case .quadCurve:
            let cpx = Float(cmd.control1.x)
            let cpy = Float(cmd.control1.y)
            let x = Float(cmd.point.x)
            let y = Float(cmd.point.y)
            
            ops.append(contentsOf: quadCurveOps(
                x1: state.position.x, y1: state.position.y,
                cpx: cpx, cpy: cpy,
                x2: x, y2: y,
                options: options
            ))
            
            state.quadReflection = (x + (x - cpx), y + (y - cpy))
            state.setPosition(x, y)
            
        case .close:
            if let first = state.first {
                ops.append(contentsOf: RoughMath.doubleLineOps(
                    x1: state.position.x, y1: state.position.y,
                    x2: first.x, y2: first.y,
                    options: options
                ))
                state.setPosition(first.x, first.y)
            }
            state.first = nil
        }
        
        return ops
    }
    
    /// Generates rough cubic Bezier curve operations.
    private static func cubicCurveOps(
        x1: Float, y1: Float,
        cp1x: Float, cp1y: Float,
        cp2x: Float, cp2y: Float,
        x2: Float, y2: Float,
        state: PathState,
        options: Options
    ) -> [Operation] {
        var ops: [Operation] = []
        let maxOff: Float = 1 * (1 + 0.2 * options.roughness)
        let maxOff2: Float = 1.5 * (1 + 0.22 * options.roughness)
        
        // First pass
        ops.append(Move(data: [x1 + RoughMath.randOffset(maxOff, options: options),
                               y1 + RoughMath.randOffset(maxOff, options: options)]))
        let end1 = [x2 + RoughMath.randOffset(maxOff, options: options),
                    y2 + RoughMath.randOffset(maxOff, options: options)]
        ops.append(BezierCurveTo(data: [
            cp1x + RoughMath.randOffset(maxOff, options: options),
            cp1y + RoughMath.randOffset(maxOff, options: options),
            cp2x + RoughMath.randOffset(maxOff, options: options),
            cp2y + RoughMath.randOffset(maxOff, options: options),
            end1[0], end1[1]
        ]))
        
        // Second pass
        ops.append(Move(data: [x1 + RoughMath.randOffset(maxOff2, options: options),
                               y1 + RoughMath.randOffset(maxOff2, options: options)]))
        let end2 = [x2 + RoughMath.randOffset(maxOff2, options: options),
                    y2 + RoughMath.randOffset(maxOff2, options: options)]
        ops.append(BezierCurveTo(data: [
            cp1x + RoughMath.randOffset(maxOff2, options: options),
            cp1y + RoughMath.randOffset(maxOff2, options: options),
            cp2x + RoughMath.randOffset(maxOff2, options: options),
            cp2y + RoughMath.randOffset(maxOff2, options: options),
            end2[0], end2[1]
        ]))
        
        return ops
    }
    
    /// Generates rough quadratic Bezier curve operations.
    private static func quadCurveOps(
        x1: Float, y1: Float,
        cpx: Float, cpy: Float,
        x2: Float, y2: Float,
        options: Options
    ) -> [Operation] {
        var ops: [Operation] = []
        let maxOff: Float = 1 * (1 + 0.2 * options.roughness)
        let maxOff2: Float = 1.5 * (1 + 0.22 * options.roughness)
        
        // First pass
        ops.append(Move(data: [x1 + RoughMath.randOffset(maxOff, options: options),
                               y1 + RoughMath.randOffset(maxOff, options: options)]))
        let end1 = [x2 + RoughMath.randOffset(maxOff, options: options),
                    y2 + RoughMath.randOffset(maxOff, options: options)]
        ops.append(QuadraticCurveTo(data: [
            cpx + RoughMath.randOffset(maxOff, options: options),
            cpy + RoughMath.randOffset(maxOff, options: options),
            end1[0], end1[1]
        ]))
        
        // Second pass
        ops.append(Move(data: [x1 + RoughMath.randOffset(maxOff2, options: options),
                               y1 + RoughMath.randOffset(maxOff2, options: options)]))
        let end2 = [x2 + RoughMath.randOffset(maxOff2, options: options),
                    y2 + RoughMath.randOffset(maxOff2, options: options)]
        ops.append(QuadraticCurveTo(data: [
            cpx + RoughMath.randOffset(maxOff2, options: options),
            cpy + RoughMath.randOffset(maxOff2, options: options),
            end2[0], end2[1]
        ]))
        
        return ops
    }
}

