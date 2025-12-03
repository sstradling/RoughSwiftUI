//
//  SwiftUIRenderer.swift
//  RoughSwift
//
//  Created by Seth Stradling on 30/11/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//  Native SwiftUI renderer for RoughSwift drawings.
//

import SwiftUI
import UIKit
import os.signpost

/// Internal alias to disambiguate SwiftUI's `Path` from the engine's `Path` drawable.
private typealias SwiftPath = SwiftUI.Path

/// High‑level description of how a path should be drawn in SwiftUI.
public struct RoughRenderCommand {
    /// The path to render.
    public let path: SwiftUI.Path

    /// The style used when rendering the path.
    public let style: Style
    
    /// The clip path for inside/outside stroke alignment (optional).
    public let clipPath: SwiftUI.Path?
    
    /// Whether to use inverse clipping (for outside strokes).
    public let inverseClip: Bool
    
    /// Line cap style for strokes.
    public let cap: BrushCap
    
    /// Line join style for strokes.
    public let join: BrushJoin

    /// Description of stroke or fill styling.
    public enum Style {
        /// Stroke path with a color and line width.
        case stroke(Color, lineWidth: CGFloat)
        /// Fill path with a solid color.
        case fill(Color)
    }
    
    public init(
        path: SwiftUI.Path,
        style: Style,
        clipPath: SwiftUI.Path? = nil,
        inverseClip: Bool = false,
        cap: BrushCap = .round,
        join: BrushJoin = .round
    ) {
        self.path = path
        self.style = style
        self.clipPath = clipPath
        self.inverseClip = inverseClip
        self.cap = cap
        self.join = join
    }
}

/// Convert `Drawing`/`OperationSet` data into SwiftUI `Path` commands and render them.
public struct SwiftUIRenderer {

    /// Build a list of draw commands representing the given `Drawing`.
    ///
    /// This function is side‑effect free and suitable for unit testing.
    ///
    /// - Parameters:
    ///   - drawing: The engine `Drawing` to render.
    ///   - options: The original options (preserves SVG-specific settings that may not be in drawing.options).
    ///   - size: The available canvas size.
    /// - Returns: A collection of `RoughRenderCommand` describing how to render the drawing.
    public func commands(for drawing: Drawing, options: Options, in size: CGSize) -> [RoughRenderCommand] {
        measurePerformance(RenderingSignpost.buildCommands, log: RoughPerformanceLog.rendering, metadata: "shape=\(drawing.shape)") {
            // SVG paths need scaling to fit the canvas since they have their own coordinate system
            let isSVGPath = drawing.shape == "path"
            
            // For SVG paths, compute a single transform from the original SVG bounds
            // so that stroke and fill align properly
            var svgTransform: CGAffineTransform? = nil
            var scaledSVGClipPath: SwiftPath? = nil
            
            if isSVGPath {
                svgTransform = measurePerformance(RenderingSignpost.svgTransform, log: RoughPerformanceLog.rendering) {
                    // Find the original SVG path from one of the sets
                    let svgPath = drawing.sets.compactMap { $0.path }.first
                    if let svg = svgPath {
                        let transform = computeSVGTransform(svg, in: size)
                        // Pre-compute the scaled SVG path for clipping (used for inside/outside stroke alignment)
                        let basePath = SwiftPath(UIBezierPath(svgPath: svg).cgPath)
                        scaledSVGClipPath = basePath.applying(transform)
                        return transform
                    }
                    return nil
                }
            }
            
            var result: [RoughRenderCommand] = []
            
            // Check if scribble fill is requested - handle it with native generation
            if options.fillStyle == .scribble {
                let scribbleCommands = scribbleFillCommands(
                    for: drawing,
                    options: options,
                    in: size,
                    svgTransform: svgTransform,
                    isSVGPath: isSVGPath
                )
                result.append(contentsOf: scribbleCommands)
            }
            
            // Process standard operation sets
            result.append(contentsOf: drawing.sets.flatMap { set in
                commands(for: set, options: options, in: size, svgTransform: svgTransform, isSVGPath: isSVGPath, svgClipPath: scaledSVGClipPath)
            })
            
            return result
        }
    }

    /// Render a `Drawing` directly into a SwiftUI `GraphicsContext`.
    ///
    /// - Parameters:
    ///   - drawing: The engine `Drawing` to render.
    ///   - options: The original options (preserves SVG-specific settings).
    ///   - context: The SwiftUI graphics context to draw into.
    ///   - size: The available canvas size.
    public func render(
        drawing: Drawing,
        options: Options,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let commands = commands(for: drawing, options: options, in: size)
        for command in commands {
            // Handle clipping for inside/outside stroke alignment
            if let clipPath = command.clipPath {
                var clippedContext = context
                if command.inverseClip {
                    clippedContext.clip(to: clipPath, options: .inverse)
                } else {
                    clippedContext.clip(to: clipPath)
                }
                renderCommand(command, in: &clippedContext)
            } else {
                renderCommand(command, in: &context)
            }
        }
    }
    
    private func renderCommand(_ command: RoughRenderCommand, in context: inout GraphicsContext) {
        switch command.style {
        case let .stroke(color, lineWidth):
            let strokeStyle = StrokeStyle(
                lineWidth: lineWidth,
                lineCap: command.cap.cgLineCap,
                lineJoin: command.join.cgLineJoin
            )
            context.stroke(
                command.path,
                with: .color(color),
                style: strokeStyle
            )
        case let .fill(color):
            context.fill(
                command.path,
                with: .color(color)
            )
        }
    }
}

// MARK: - Internal helpers

private extension SwiftUIRenderer {
    func commands(
        for set: OperationSet,
        options: Options,
        in size: CGSize,
        svgTransform: CGAffineTransform? = nil,
        isSVGPath: Bool = false,
        svgClipPath: SwiftPath? = nil
    ) -> [RoughRenderCommand] {
        // Use SVG-specific widths when rendering SVG paths
        let strokeWidth = isSVGPath ? options.effectiveSVGStrokeWidth : options.strokeWidth
        let fillWeight: Float = {
            let base = isSVGPath ? options.effectiveSVGFillWeight : options.fillWeight
            return base < 0 ? strokeWidth / 2 : base
        }()
        
        // Determine stroke alignment settings for fill strokes
        let alignment = isSVGPath ? options.svgFillStrokeAlignment : .center
        let (effectiveFillWeight, clipPath, inverseClip) = strokeAlignmentSettings(
            lineWidth: fillWeight,
            alignment: alignment,
            clipPath: svgClipPath
        )
        
        switch set.type {
        case .path:
            let basePath = SwiftPath.from(operationSet: set)
            let path: SwiftPath
            if let transform = svgTransform {
                path = basePath.applying(transform)
            } else {
                path = basePath
            }
            let strokeColor = Color(options.stroke).opacity(Double(options.strokeOpacity))
            
            // Check if brush profile requires custom rendering
            if options.brushProfile.requiresCustomRendering {
                // Convert stroke to filled path with variable width
                let filledPath = StrokeToFillConverter.convert(
                    operations: set.operations,
                    baseWidth: CGFloat(strokeWidth),
                    profile: options.brushProfile
                )
                // Apply transform if needed
                let finalPath: SwiftPath
                if let transform = svgTransform {
                    finalPath = filledPath.applying(transform)
                } else {
                    finalPath = filledPath
                }
                return [
                    RoughRenderCommand(
                        path: finalPath,
                        style: .fill(strokeColor)
                    )
                ]
            } else {
                // Standard stroke rendering with cap and join
                return [
                    RoughRenderCommand(
                        path: path,
                        style: .stroke(strokeColor, lineWidth: CGFloat(strokeWidth)),
                        cap: options.strokeCap,
                        join: options.strokeJoin
                    )
                ]
            }

        case .fillSketch:
            // Skip fillSketch when using scribble fill (we handle it separately)
            if options.fillStyle == .scribble {
                return []
            }
            
            let basePath = SwiftPath.from(operationSet: set)
            let path: SwiftPath
            if let transform = svgTransform {
                path = basePath.applying(transform)
            } else {
                path = basePath
            }
            let color = Color(options.fill).opacity(Double(options.fillOpacity))
            return [
                RoughRenderCommand(
                    path: path,
                    style: .stroke(color, lineWidth: CGFloat(effectiveFillWeight)),
                    clipPath: clipPath,
                    inverseClip: inverseClip,
                    cap: options.strokeCap,
                    join: options.strokeJoin
                )
            ]

        case .fillPath:
            // Skip fillPath when using scribble fill (we handle it separately)
            if options.fillStyle == .scribble {
                return []
            }
            
            let basePath = SwiftPath.from(operationSet: set)
            let path: SwiftPath
            if let transform = svgTransform {
                path = basePath.applying(transform)
            } else {
                path = basePath
            }
            let color = Color(options.fill).opacity(Double(options.fillOpacity))
            return [
                RoughRenderCommand(
                    path: path,
                    style: .fill(color)
                )
            ]

        case .path2DFill:
            guard let svgPathString = set.path else { return [] }
            let basePath = SwiftPath(UIBezierPath(svgPath: svgPathString).cgPath)
            let path: SwiftPath
            if let transform = svgTransform {
                path = basePath.applying(transform)
            } else {
                path = basePath
            }
            let color = Color(options.fill).opacity(Double(options.fillOpacity))
            return [
                RoughRenderCommand(
                    path: path,
                    style: .fill(color)
                )
            ]

        case .path2DPattern:
            // Approximate the pattern fill by stroking the SVG path with fill color.
            guard let svgPathString = set.path else { return [] }
            let basePath = SwiftPath(UIBezierPath(svgPath: svgPathString).cgPath)
            let path: SwiftPath
            if let transform = svgTransform {
                path = basePath.applying(transform)
            } else {
                path = basePath
            }
            let color = Color(options.fill).opacity(Double(options.fillOpacity))
            return [
                RoughRenderCommand(
                    path: path,
                    style: .stroke(color, lineWidth: CGFloat(effectiveFillWeight)),
                    clipPath: clipPath,
                    inverseClip: inverseClip,
                    cap: options.strokeCap,
                    join: options.strokeJoin
                )
            ]
        }
    }
    
    // MARK: - Scribble Fill
    
    /// Generates scribble fill commands for a drawing.
    func scribbleFillCommands(
        for drawing: Drawing,
        options: Options,
        in size: CGSize,
        svgTransform: CGAffineTransform?,
        isSVGPath: Bool
    ) -> [RoughRenderCommand] {
        // Extract the shape path from the drawing
        guard let shapePath = extractShapePath(from: drawing, svgTransform: svgTransform, isSVGPath: isSVGPath) else {
            return []
        }
        
        // Only use clip path for SVG paths (which may be concave shapes like stars)
        // Simple shapes like rectangles and circles don't need clipping
        let clipPath: SwiftPath? = isSVGPath ? SwiftPath(shapePath) : nil
        
        // Generate scribble fill operation sets
        let scribbleSets = ScribbleFillGenerator.generate(for: shapePath, options: options)
        
        // Calculate fill weight
        let strokeWidth = isSVGPath ? options.effectiveSVGStrokeWidth : options.strokeWidth
        let fillWeight: Float = {
            let base = isSVGPath ? options.effectiveSVGFillWeight : options.fillWeight
            return base < 0 ? strokeWidth / 2 : base
        }()
        
        let color = Color(options.fill).opacity(Double(options.fillOpacity))
        
        // Convert each scribble set to render commands
        return scribbleSets.flatMap { set -> [RoughRenderCommand] in
            let basePath = SwiftPath.from(operationSet: set)
            
            // Check if brush strokes are enabled and profile needs custom rendering
            let useBrushStroke = options.scribbleUseBrushStroke && 
                (options.brushProfile.requiresCustomRendering || 
                 options.thicknessProfile != .uniform ||
                 options.brushTip.roundness < 0.99)
            
            if useBrushStroke {
                // Convert to filled path with variable width
                let filledPath = StrokeToFillConverter.convert(
                    operations: set.operations,
                    baseWidth: CGFloat(fillWeight),
                    profile: options.brushProfile
                )
                return [
                    RoughRenderCommand(
                        path: filledPath,
                        style: .fill(color),
                        clipPath: clipPath,
                        inverseClip: false
                    )
                ]
            } else {
                // Standard stroke rendering
                return [
                    RoughRenderCommand(
                        path: basePath,
                        style: .stroke(color, lineWidth: CGFloat(fillWeight)),
                        clipPath: clipPath,
                        inverseClip: false,
                        cap: options.strokeCap,
                        join: options.strokeJoin
                    )
                ]
            }
        }
    }
    
    /// Extracts the shape path from a drawing for scribble fill generation.
    func extractShapePath(
        from drawing: Drawing,
        svgTransform: CGAffineTransform?,
        isSVGPath: Bool
    ) -> CGPath? {
        // For SVG paths, use the path string
        if isSVGPath {
            if let svgPathString = drawing.sets.compactMap({ $0.path }).first {
                let basePath = UIBezierPath(svgPath: svgPathString).cgPath
                if let transform = svgTransform {
                    return basePath.copy(using: [transform])
                }
                return basePath
            }
        }
        
        // For other shapes, reconstruct the path from the stroke operations
        // Look for the outline path (type == .path)
        for set in drawing.sets where set.type == .path {
            let swiftPath = SwiftPath.from(operationSet: set)
            let cgPath = swiftPath.cgPath
            
            // Check if the path is valid for ray-casting (has reasonable bounds)
            let bounds = cgPath.boundingBox
            if bounds.width > 1 && bounds.height > 1 {
                // For rough.js shapes, the path might not be closed.
                // Create a closed version by using the bounding box as an approximation
                // for circle/ellipse shapes, or use the path directly for polygons.
                
                // Check if path approximates a circle/ellipse by comparing bounds aspect
                let aspect = bounds.width / bounds.height
                if drawing.shape == "circle" || drawing.shape == "ellipse" || 
                   (aspect > 0.8 && aspect < 1.2 && drawing.shape != "rectangle") {
                    // Create an ellipse path that matches the bounds
                    let ellipsePath = UIBezierPath(ovalIn: bounds)
                    return ellipsePath.cgPath
                }
                
                return cgPath
            }
        }
        
        // Fallback: try fillPath type
        for set in drawing.sets where set.type == .fillPath {
            let swiftPath = SwiftPath.from(operationSet: set)
            return swiftPath.cgPath
        }
        
        return nil
    }
    
    /// Calculate effective line width and clipping for stroke alignment.
    /// - Parameters:
    ///   - lineWidth: The desired visual line width.
    ///   - alignment: The stroke alignment mode.
    ///   - clipPath: The path to use for clipping (typically the SVG outline).
    /// - Returns: Tuple of (effectiveLineWidth, clipPath, inverseClip).
    func strokeAlignmentSettings(
        lineWidth: Float,
        alignment: SVGFillStrokeAlignment,
        clipPath: SwiftPath?
    ) -> (Float, SwiftPath?, Bool) {
        switch alignment {
        case .center:
            // No clipping needed, use normal line width
            return (lineWidth, nil, false)
        case .inside:
            // Clip to path, stroke with 2x width (outside half gets clipped)
            return (lineWidth * 2, clipPath, false)
        case .outside:
            // Clip to inverse of path, stroke with 2x width (inside half gets clipped)
            return (lineWidth * 2, clipPath, true)
        }
    }

    /// Compute a transform that scales and centers an SVG path to fit the canvas.
    /// This transform can be applied to all related paths (stroke, fill) to ensure alignment.
    func computeSVGTransform(_ svg: String, in size: CGSize) -> CGAffineTransform {
        let bezier = UIBezierPath(svgPath: svg)
        let bounds = bezier.cgPath.boundingBox
        
        guard bounds.width > 0, bounds.height > 0 else {
            return .identity
        }
        
        let frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: max(size.width, 1),
                height: max(size.height, 1)
            )
        )
        
        // Calculate scale factor to fit while maintaining aspect ratio
        let sw = frame.width / bounds.width
        let sh = frame.height / bounds.height
        let scaleFactor = min(sw, sh)
        
        // Build transform: scale around center, then move to frame center
        let centerX = bounds.midX
        let centerY = bounds.midY
        
        var transform = CGAffineTransform.identity
        // Translate center of bounds to origin
        transform = transform.translatedBy(x: -centerX, y: -centerY)
        // Scale
        transform = transform.scaledBy(x: scaleFactor, y: scaleFactor)
        // Translate to center of frame
        transform = transform.translatedBy(x: frame.midX / scaleFactor, y: frame.midY / scaleFactor)
        
        return transform
    }
}

// MARK: - Geometry helpers (ported from `Renderer.swift`)

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}

private extension CGPoint {
    func vector(to other: CGPoint) -> CGVector {
        CGVector(dx: other.x - x, dy: other.y - y)
    }
}

private extension UIBezierPath {
    @discardableResult
    func moveCenter(to point: CGPoint) -> Self {
        let bounds = cgPath.boundingBox
        let center = bounds.center

        let zeroedTo = CGPoint(x: point.x - bounds.origin.x, y: point.y - bounds.origin.y)
        let vector = center.vector(to: zeroedTo)

        _ = offset(to: CGSize(width: vector.dx, height: vector.dy))
        return self
    }

    @discardableResult
    func offset(to offset: CGSize) -> Self {
        let transform = CGAffineTransform(translationX: offset.width, y: offset.height)
        _ = applyCentered(transform: transform)
        return self
    }

    @discardableResult
    func fit(into rect: CGRect) -> Self {
        let bounds = cgPath.boundingBox

        let sw = rect.size.width / bounds.width
        let sh = rect.size.height / bounds.height
        let factor = min(sw, max(sh, 0.0))

        return scale(x: factor, y: factor)
    }

    @discardableResult
    func scale(x: CGFloat, y: CGFloat) -> Self {
        let scale = CGAffineTransform(scaleX: x, y: y)
        _ = applyCentered(transform: scale)
        return self
    }

    @discardableResult
    func applyCentered(transform: @autoclosure () -> CGAffineTransform) -> Self {
        let bounds = cgPath.boundingBox
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        var xform = CGAffineTransform.identity

        xform = xform.concatenating(CGAffineTransform(translationX: -center.x, y: -center.y))
        xform = xform.concatenating(transform())
        xform = xform.concatenating(CGAffineTransform(translationX: center.x, y: center.y))
        apply(xform)

        return self
    }
}
