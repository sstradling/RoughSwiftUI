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
        // One seed covers the outline and every fill line. Nested RoughMath
        // and filler calls keep consuming this sequence.
        if options.seed != nil && !RoughRandom.isActive {
            return RoughRandom.with(seed: options.seed) {
                generateUncached(drawable: drawable, options: options)
            }
        }
        let arguments: [Any]
        if let fullable = drawable as? Fulfillable {
            arguments = fullable.arguments(size: Size(width: Float(size.width), height: Float(size.height)))
        } else {
            arguments = drawable.arguments
        }
        
        let method = drawable.method

        let drawing: Drawing?
        switch method {
        case "line":
            drawing = generateLine(arguments: arguments, options: options)
        case "rectangle":
            drawing = generateRectangle(arguments: arguments, options: options)
        case "ellipse":
            drawing = generateEllipse(arguments: arguments, options: options)
        case "circle":
            drawing = generateCircle(arguments: arguments, options: options)
        case "linearPath":
            drawing = generateLinearPath(arguments: arguments, options: options)
        case "polygon":
            drawing = generatePolygon(arguments: arguments, options: options)
        case "arc":
            drawing = generateArc(arguments: arguments, options: options)
        case "curve":
            drawing = generateCurve(arguments: arguments, options: options)
        case "path":
            // FullText already places the glyphs in the view. Marking the
            // drawing as "text" keeps the renderer from fitting it like an
            // SVG path, which would scale and center the word.
            if let generated = generatePath(arguments: arguments, options: options) {
                let shape = drawable is FullText ? "text" : generated.shape
                drawing = Drawing(shape: shape, sets: generated.sets, options: generated.options)
            } else {
                drawing = nil
            }
        case "roundedRectangle":
            drawing = generateRoundedRectangle(arguments: arguments, options: options)
        case "egg":
            drawing = generateEgg(arguments: arguments, options: options)
        default:
            drawing = nil
        }

        guard let drawing else { return nil }
        let guide = StickerGuide.rings(method: method, arguments: arguments)
        guard !guide.isEmpty else { return drawing }
        return Drawing(
            shape: drawing.shape,
            sets: drawing.sets,
            options: drawing.options,
            stickerGuide: guide
        )
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

        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.doubleLineOps(x1: x1, y1: y1, x2: x2, y2: y2, options: options)
        case .continuous:
            ops = RoughCurves.doubleLineOps(x1: x1, y1: y1, x2: x2, y2: y2, options: options)
        }
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
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.rectangleOps(x: x, y: y, width: width, height: height, options: options)
        case .continuous:
            ops = RoughCurves.rectangleOps(x: x, y: y, width: width, height: height, options: options)
        }
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
        
        let resolved = RoughMath.resolvedEllipseRadii(rx: width / 2, ry: height / 2, options: options)
        
        var sets: [OperationSet] = []
        
        // Fill the same radii the outline will use. Padding and offset are
        // applied inside the fill, so the stroke stays on the full ellipse.
        if let fillSet = generateEllipseFill(
            cx: cx, cy: cy, rx: resolved.rx, ry: resolved.ry, options: options
        ) {
            sets.append(fillSet)
        }
        
        // Stroke the same radii the fill used. Continuous mode does not
        // resolve them again.
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.ellipseStroke(
                cx: cx, cy: cy, rx: resolved.rx, ry: resolved.ry, options: options
            )
        case .continuous:
            ops = RoughCurves.ellipseOps(
                cx: cx, cy: cy, rx: resolved.rx, ry: resolved.ry, options: options
            )
        }
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
        
        let resolved = RoughMath.resolvedEllipseRadii(rx: diameter / 2, ry: diameter / 2, options: options)
        
        var sets: [OperationSet] = []
        
        if let fillSet = generateEllipseFill(
            cx: cx, cy: cy, rx: resolved.rx, ry: resolved.ry, options: options
        ) {
            sets.append(fillSet)
        }
        
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.ellipseStroke(
                cx: cx, cy: cy, rx: resolved.rx, ry: resolved.ry, options: options
            )
        case .continuous:
            ops = RoughCurves.ellipseOps(
                cx: cx, cy: cy, rx: resolved.rx, ry: resolved.ry, options: options
            )
        }
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))

        return Drawing(shape: "circle", sets: sets, options: options)
    }
    
    /// Generates a rough linear path drawing.
    private func generateLinearPath(arguments: [Any], options: Options) -> Drawing? {
        let points = extractPoints(from: arguments)
        guard !points.isEmpty else { return nil }

        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.linearPathOps(points: points, close: false, options: options)
        case .continuous:
            ops = RoughCurves.linearPathOps(points: points, close: false, options: options)
        }
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
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.polygonOps(points: points, options: options)
        case .continuous:
            ops = RoughCurves.polygonOps(points: points, options: options)
        }
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
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.arcOps(cx: cx, cy: cy, rx: rx, ry: ry, start: start, stop: stop, closed: closed, roughClosure: true, options: options)
        case .continuous:
            ops = RoughCurves.arcOps(cx: cx, cy: cy, rx: rx, ry: ry, start: start, stop: stop, closed: closed, options: options)
        }
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
    
    /// Generates a rough rounded rectangle drawing.
    private func generateRoundedRectangle(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 5,
              let x = (arguments[0] as? NSNumber)?.floatValue,
              let y = (arguments[1] as? NSNumber)?.floatValue,
              let width = (arguments[2] as? NSNumber)?.floatValue,
              let height = (arguments[3] as? NSNumber)?.floatValue,
              let cornerRadius = (arguments[4] as? NSNumber)?.floatValue else {
            return nil
        }
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generateRoundedRectangleFill(x: x, y: y, width: width, height: height, cornerRadius: cornerRadius, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.roundedRectangleOps(x: x, y: y, width: width, height: height, cornerRadius: cornerRadius, options: options)
        case .continuous:
            ops = RoughCurves.roundedRectangleOps(x: x, y: y, width: width, height: height, cornerRadius: cornerRadius, options: options)
        }
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))

        return Drawing(shape: "roundedRectangle", sets: sets, options: options)
    }
    
    /// Generates a rough egg shape drawing.
    private func generateEgg(arguments: [Any], options: Options) -> Drawing? {
        guard arguments.count >= 4,
              let cx = (arguments[0] as? NSNumber)?.floatValue,
              let cy = (arguments[1] as? NSNumber)?.floatValue,
              let width = (arguments[2] as? NSNumber)?.floatValue,
              let height = (arguments[3] as? NSNumber)?.floatValue else {
            return nil
        }
        
        let tilt = arguments.count >= 5 ? (arguments[4] as? NSNumber)?.floatValue ?? 0.3 : 0.3
        
        var sets: [OperationSet] = []
        
        // Generate fill if needed
        if let fillSet = generateEggFill(cx: cx, cy: cy, width: width, height: height, tilt: tilt, options: options) {
            sets.append(fillSet)
        }
        
        // Generate stroke
        let ops: [Operation]
        switch options.strokeContinuity {
        case .legacy:
            ops = RoughMath.eggOps(cx: cx, cy: cy, width: width, height: height, tilt: tilt, options: options)
        case .continuous:
            ops = RoughCurves.eggOps(cx: cx, cy: cy, width: width, height: height, tilt: tilt, options: options)
        }
        sets.append(OperationSet(type: .path, operations: ops, path: nil, size: nil))

        return Drawing(shape: "egg", sets: sets, options: options)
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
        guard let region = FillGeometry.ellipse(
            cx: cx, cy: cy, rx: rx, ry: ry,
            padding: options.fillPadding, offset: options.fillOffset
        ) else {
            return nil
        }
        let filler = FillPatternFactory.filler(for: options.fillStyle)
        return filler.fillEllipse(
            cx: region.cx, cy: region.cy, rx: region.rx, ry: region.ry, options: options
        )
    }
    
    /// Generates fill for a polygon.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    /// A padding that collapses the polygon produces no fill.
    private func generatePolygonFill(points: [[Float]], options: Options) -> OperationSet? {
        guard let region = FillGeometry.polygon(
            points, padding: options.fillPadding, offset: options.fillOffset
        ) else {
            return nil
        }
        let filler = FillPatternFactory.filler(for: options.fillStyle)
        return filler.fillPolygon(points: region, options: options)
    }
    
    /// Generates fill for an arc.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generateArcFill(cx: Float, cy: Float, rx: Float, ry: Float, start: Float, stop: Float, options: Options) -> OperationSet? {
        guard let region = FillGeometry.ellipse(
            cx: cx, cy: cy, rx: rx, ry: ry,
            padding: options.fillPadding, offset: options.fillOffset
        ) else {
            return nil
        }
        let filler = FillPatternFactory.filler(for: options.fillStyle)
        return filler.fillArc(
            cx: region.cx, cy: region.cy, rx: region.rx, ry: region.ry,
            start: start, stop: stop, options: options
        )
    }
    
    /// Generates fill for a rounded rectangle.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generateRoundedRectangleFill(x: Float, y: Float, width: Float, height: Float, cornerRadius: Float, options: Options) -> OperationSet? {
        // Approximate the rounded rectangle as a polygon for fill purposes
        let points = RoughMath.roundedRectanglePolygonPoints(x: x, y: y, width: width, height: height, cornerRadius: cornerRadius)
        return generatePolygonFill(points: points, options: options)
    }
    
    /// Generates fill for an egg shape.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generateEggFill(cx: Float, cy: Float, width: Float, height: Float, tilt: Float, options: Options) -> OperationSet? {
        // Approximate the egg as a polygon for fill purposes
        let points = RoughMath.eggPolygonPoints(cx: cx, cy: cy, width: width, height: height, tilt: tilt, stepCount: options.curveStepCount)
        return generatePolygonFill(points: points, options: options)
    }
    
    /// Generates fill for an SVG path.
    /// Note: Fill is always generated (matching rough.js behavior), even if color is clear.
    private func generatePathFill(pathString: String, options: Options) -> OperationSet? {
        let adjustsFill = options.fillPadding != 0 || options.fillOffset != .zero
        if adjustsFill {
            guard let contours = FillGeometry.svgContours(
                pathString, padding: options.fillPadding, offset: options.fillOffset
            ), let outer = contours.first else {
                return nil
            }
            let clipped = FillGeometry.svgPath(from: contours)
            if options.fillStyle == .solid || options.fillStyle == .watercolor {
                return OperationSet(type: .path2DFill, operations: [], path: clipped, size: nil)
            }
            let filler = FillPatternFactory.filler(for: options.fillStyle)
            guard let fillSet = filler.fillPolygon(points: outer, options: options) else { return nil }
            let bounds = UIBezierPath(svgPath: clipped).cgPath.boundingBox
            return OperationSet(
                type: .path2DPattern,
                operations: fillSet.operations,
                path: clipped,
                size: Size(width: Float(bounds.width), height: Float(bounds.height))
            )
        }

        if options.fillStyle == .solid || options.fillStyle == .watercolor {
            // Solid and watercolor fills use the path directly. The wash is painted later.
            return OperationSet(type: .path2DFill, operations: [], path: pathString, size: nil)
        } else {
            // Pattern fill
            let bezier = UIBezierPath(svgPath: pathString)
            let bounds = bezier.cgPath.boundingBox
            
            // Create a bounding box polygon for pattern that matches the actual path bounds
            // The hachure lines need to be positioned at the same location as the path
            let minX = Float(bounds.minX)
            let minY = Float(bounds.minY)
            let maxX = Float(bounds.maxX)
            let maxY = Float(bounds.maxY)
            
            let points: [[Float]] = [
                [minX, minY],
                [maxX, minY],
                [maxX, maxY],
                [minX, maxY]
            ]
            
            let filler = FillPatternFactory.filler(for: options.fillStyle)
            if let fillSet = filler.fillPolygon(points: points, options: options) {
                return OperationSet(
                    type: .path2DPattern,
                    operations: fillSet.operations,
                    path: pathString,
                    size: Size(width: Float(bounds.width), height: Float(bounds.height))
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
        var sourcePosition: CGPoint = .zero
        var firstSource: CGPoint?
        var bezierReflection: (x: Float, y: Float)?
        var quadReflection: (x: Float, y: Float)?
        
        func setPosition(_ x: Float, _ y: Float) {
            position = (x, y)
            if first == nil {
                first = (x, y)
            }
        }

        /// Records the unjittered SVG point. The subpath start is set only by a moveto.
        func setSourcePosition(_ point: CGPoint) {
            sourcePosition = point
        }

        func beginSourceSubpath(_ point: CGPoint) {
            sourcePosition = point
            firstSource = point
        }
    }
    
    /// Generates rough operations for an SVG path string.
    /// Uses a two-pass approach: first renders all contours with one offset,
    /// then renders all contours again with a different offset for the sketchy effect.
    static func pathOps(svgPath: String, options: Options) -> [Operation] {
        let svgParser = SVGPath(svgPath)
        let commands = svgParser.commands
        
        // Split commands into contours (each starting with a Move)
        var contours: [[SVGCommand]] = []
        var currentContour: [SVGCommand] = []
        
        for cmd in commands {
            if cmd.type == .move && !currentContour.isEmpty {
                contours.append(currentContour)
                currentContour = []
            }
            currentContour.append(cmd)
        }
        if !currentContour.isEmpty {
            contours.append(currentContour)
        }
        
        var ops: [Operation] = []
        let maxOff: Float = 1 * (1 + 0.2 * options.roughness)
        let maxOff2: Float = 1.5 * (1 + 0.22 * options.roughness)
        
        // First pass: render all contours with first offset
        for contour in contours {
            ops.append(contentsOf: renderContour(contour, options: options, offsetScale: maxOff))
        }
        
        // Second pass: render all contours with second offset
        for contour in contours {
            ops.append(contentsOf: renderContour(contour, options: options, offsetScale: maxOff2))
        }
        
        return ops
    }
    
    /// Renders a single contour (starting from Move, ending at Close or end of commands)
    /// as a continuous path with the given offset scale.
    private static func renderContour(
        _ commands: [SVGCommand],
        options: Options,
        offsetScale: Float
    ) -> [Operation] {
        var ops: [Operation] = []
        let state = PathState()
        
        for i in 0..<commands.count {
            let cmd = commands[i]
            ops.append(contentsOf: processCommandContinuous(
                cmd,
                state: state,
                options: options,
                offsetScale: offsetScale,
                isFirst: i == 0
            ))
        }
        
        return ops
    }
    
    /// Processes a single SVG command for continuous path rendering.
    /// Only emits Move for the first command in a contour.
    private static func processCommandContinuous(
        _ cmd: SVGCommand,
        state: PathState,
        options: Options,
        offsetScale: Float,
        isFirst: Bool
    ) -> [Operation] {
        var ops: [Operation] = []
        
        switch cmd.type {
        case .move:
            let x = Float(cmd.point.x) + RoughMath.randOffset(offsetScale, options: options)
            let y = Float(cmd.point.y) + RoughMath.randOffset(offsetScale, options: options)
            state.setPosition(x, y)
            state.beginSourceSubpath(cmd.point)
            // Always emit Move for the start of a contour
            ops.append(Move(data: [x, y]))
            
        case .line:
            let x = Float(cmd.point.x) + RoughMath.randOffset(offsetScale, options: options)
            let y = Float(cmd.point.y) + RoughMath.randOffset(offsetScale, options: options)
            ops.append(LineTo(data: [x, y]))
            state.setPosition(x, y)
            state.setSourcePosition(cmd.point)
            
        case .cubeCurve:
            let cp1x = Float(cmd.control1.x) + RoughMath.randOffset(offsetScale, options: options)
            let cp1y = Float(cmd.control1.y) + RoughMath.randOffset(offsetScale, options: options)
            let cp2x = Float(cmd.control2.x) + RoughMath.randOffset(offsetScale, options: options)
            let cp2y = Float(cmd.control2.y) + RoughMath.randOffset(offsetScale, options: options)
            let x = Float(cmd.point.x) + RoughMath.randOffset(offsetScale, options: options)
            let y = Float(cmd.point.y) + RoughMath.randOffset(offsetScale, options: options)
            
            ops.append(BezierCurveTo(data: [cp1x, cp1y, cp2x, cp2y, x, y]))
            
            state.bezierReflection = (x + (x - cp2x), y + (y - cp2y))
            state.setPosition(x, y)
            state.setSourcePosition(cmd.point)
            
        case .quadCurve:
            let cpx = Float(cmd.control1.x) + RoughMath.randOffset(offsetScale, options: options)
            let cpy = Float(cmd.control1.y) + RoughMath.randOffset(offsetScale, options: options)
            let x = Float(cmd.point.x) + RoughMath.randOffset(offsetScale, options: options)
            let y = Float(cmd.point.y) + RoughMath.randOffset(offsetScale, options: options)
            
            ops.append(QuadraticCurveTo(data: [cpx, cpy, x, y]))
            
            state.quadReflection = (x + (x - cpx), y + (y - cpy))
            state.setPosition(x, y)
            state.setSourcePosition(cmd.point)

        case .arc:
            let start = state.sourcePosition
            switch SVGArcConverter.convert(
                from: start,
                to: cmd.point,
                rx: cmd.rx,
                ry: cmd.ry,
                xAxisRotation: cmd.xAxisRotation,
                largeArc: cmd.largeArc,
                sweep: cmd.sweep
            ) {
            case .omitted:
                state.setSourcePosition(cmd.point)
            case .line:
                let x = Float(cmd.point.x) + RoughMath.randOffset(offsetScale, options: options)
                let y = Float(cmd.point.y) + RoughMath.randOffset(offsetScale, options: options)
                ops.append(LineTo(data: [x, y]))
                state.setPosition(x, y)
                state.setSourcePosition(cmd.point)
            case .cubic(let geometry):
                for curve in geometry.curves {
                    let cp1x = Float(curve.control1.x) + RoughMath.randOffset(offsetScale, options: options)
                    let cp1y = Float(curve.control1.y) + RoughMath.randOffset(offsetScale, options: options)
                    let cp2x = Float(curve.control2.x) + RoughMath.randOffset(offsetScale, options: options)
                    let cp2y = Float(curve.control2.y) + RoughMath.randOffset(offsetScale, options: options)
                    let x = Float(curve.point.x) + RoughMath.randOffset(offsetScale, options: options)
                    let y = Float(curve.point.y) + RoughMath.randOffset(offsetScale, options: options)

                    ops.append(BezierCurveTo(data: [cp1x, cp1y, cp2x, cp2y, x, y]))
                    state.bezierReflection = (x + (x - cp2x), y + (y - cp2y))
                    state.setPosition(x, y)
                }
                state.setSourcePosition(cmd.point)
            }

        case .close:
            // Close the subpath - this draws a line back to the start point
            // and marks the path as closed for proper fill rendering.
            // The unjittered current point returns to the moveto. It stays
            // there until the next moveto, so a later arc still starts there.
            ops.append(Close())
            state.first = nil
            if let firstSource = state.firstSource {
                state.sourcePosition = firstSource
            }
        }
        
        return ops
    }
}

