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

    /// Miter limit used when `join == .miter`.
    ///
    /// This is the maximum miter length divided by stroke width before
    /// CoreGraphics falls back to a bevel. Values below `1` are clamped to `1`.
    public let miterLimit: CGFloat

    /// Fill rule used when `style` is `.fill`.
    ///
    /// Existing fills stay even-odd so holes in glyphs keep working.
    /// Crayon passes use winding so overlapping wax marks union instead of punching holes.
    public let fillRule: RoughFillRule

    /// Groups commands that share one opacity mask.
    ///
    /// `nil` is a normal stroke or fill. A run of the same id is painted into
    /// one transparency mask so overlapping segment alphas do not darken.
    public let opacityMaskGroup: Int?

    /// Opacity written into the mask, already multiplied by `strokeOpacity` or `fillOpacity`.
    ///
    /// Ignored when `opacityMaskGroup` is nil. The color in `style` stays at full strength.
    public let maskOpacity: CGFloat

    /// Blur radius, in points, applied to this mask before it is tinted. `0` is sharp.
    public let opacityMaskBlur: CGFloat

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
        join: BrushJoin = .round,
        miterLimit: CGFloat = 10,
        fillRule: RoughFillRule = .evenOdd,
        opacityMaskGroup: Int? = nil,
        maskOpacity: CGFloat = 1,
        opacityMaskBlur: CGFloat = 0
    ) {
        self.path = path
        self.style = style
        self.clipPath = clipPath
        self.inverseClip = inverseClip
        self.cap = cap
        self.join = join
        self.miterLimit = max(1, miterLimit)
        self.fillRule = fillRule
        self.opacityMaskGroup = opacityMaskGroup
        self.maskOpacity = maskOpacity
        self.opacityMaskBlur = opacityMaskBlur
    }
}

/// How a filled rough command covers overlapping subpaths.
public enum RoughFillRule: Equatable, Hashable, Sendable {
    /// Subtract overlapping regions. Used for holes such as glyph counters.
    case evenOdd
    /// Add overlapping regions. Used by crayon wax marks.
    case winding
}

/// Convert `Drawing`/`OperationSet` data into SwiftUI `Path` commands and render them.
public struct SwiftUIRenderer {
    /// Open `.variable` and `.stops` strokes use winding so the two rough
    /// passes union into one solid mark. Closed contours stay even-odd so
    /// the inner edge of a ring stays a hole. Tapers, `.custom`, and an even
    /// `.marker` stay even-odd.
    static func brushFillRule(operations: [Operation], profile: BrushProfile) -> RoughFillRule {
        switch profile.thicknessProfile {
        case .variable:
            break
        case .stops(let stops) where !stops.isEmpty:
            break
        default:
            return .evenOdd
        }
        let closed = operations.contains { $0 is Close }
        return closed ? .evenOdd : .winding
    }


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
            // SVG paths need scaling to fit the canvas since they have their own coordinate system.
            // Text uses shape "text": FullText has already placed the glyphs, including alignment.
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
            
            var nextGroup = 1
            let opacityProfile = options.resolvedOpacityProfile()
            let watercolor = options.resolvedWatercolorBrush()
            let outlineWidth = CGFloat(isSVGPath ? options.effectiveSVGStrokeWidth : options.strokeWidth)
            let skipOutline = watercolor != nil || (opacityProfile.variesAlongStroke && options.brushProfile.crayon == nil)
            let outlineTransform = svgTransform ?? .identity
            if let (profile, style) = watercolor {
                let sets = drawing.sets.filter { $0.type == .path }.map(\.operations)
                result.append(contentsOf: WatercolorStroke.commands(
                    sets: sets,
                    transform: outlineTransform,
                    width: outlineWidth,
                    brush: profile,
                    style: style,
                    strokeOpacity: CGFloat(options.strokeOpacity),
                    color: Color(options.stroke),
                    nextGroup: &nextGroup
                ))
            } else if opacityProfile.variesAlongStroke && options.brushProfile.crayon == nil {
                let sets = drawing.sets.filter { $0.type == .path }.map(\.operations)
                result.append(contentsOf: OpacityRibbon.commands(
                    sets: sets,
                    transform: outlineTransform,
                    baseWidth: outlineWidth,
                    brush: options.brushProfile,
                    opacityProfile: opacityProfile,
                    strokeOpacity: CGFloat(options.strokeOpacity),
                    color: Color(options.stroke),
                    nextGroup: &nextGroup
                ))
            }

            // Process standard operation sets. Outline sets are skipped when a
            // wash or a variable-opacity ribbon already painted them.
            for set in drawing.sets {
                result.append(contentsOf: commands(
                    for: set,
                    options: options,
                    in: size,
                    svgTransform: svgTransform,
                    isSVGPath: isSVGPath,
                    svgClipPath: scaledSVGClipPath,
                    skipOutline: skipOutline,
                    nextGroup: &nextGroup
                ))
            }
            
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
        var index = 0
        while index < commands.count {
            let command = commands[index]
            if command.opacityMaskGroup != nil {
                var end = index + 1
                while end < commands.count && commands[end].opacityMaskGroup == command.opacityMaskGroup {
                    end += 1
                }
                renderOpacityMask(commands[index..<end], in: &context)
                index = end
                continue
            }
            // Handle clipping for inside/outside stroke alignment
            if let clipPath = command.clipPath {
                var clippedContext = context
                if command.inverseClip {
                    // Use even-odd rule with inverse for proper handling of paths with holes
                    clippedContext.clip(to: clipPath, style: SwiftUI.FillStyle(eoFill: true), options: .inverse)
                } else {
                    // Use even-odd fill rule for clipping to properly handle paths with holes (like glyph counters)
                    clippedContext.clip(to: clipPath, style: SwiftUI.FillStyle(eoFill: true))
                }
                renderCommand(command, in: &clippedContext)
            } else {
                renderCommand(command, in: &context)
            }
            index += 1
        }
    }

    /// Paints one opacity-mask group.
    ///
    /// Each piece is filled with opaque gray whose luminance is the piece opacity.
    /// Opaque source-over replaces, so shared edges and caps do not add alpha.
    /// Antialiasing blends the two grays. `luminanceToAlpha` turns that gray into
    /// coverage, and `sourceAtop` tints it with the stroke or fill color.
    /// Separate groups stack with normal blending, which is how wet layers build up.
    private func renderOpacityMask(_ commands: ArraySlice<RoughRenderCommand>, in context: inout GraphicsContext) {
        guard let first = commands.first else { return }
        let tint = maskTint(of: first)
        let blur = max(0, first.opacityMaskBlur)
        context.drawLayer { layer in
            if let clipPath = first.clipPath {
                if first.inverseClip {
                    layer.clip(to: clipPath, style: SwiftUI.FillStyle(eoFill: true), options: .inverse)
                } else {
                    layer.clip(to: clipPath, style: SwiftUI.FillStyle(eoFill: true))
                }
            }
            // Opaque gray is composited first, so a later piece replaces an earlier
            // one instead of adding alpha. The filter runs on that finished layer.
            // Applying it per draw would source-over the transparent results and
            // darken every overlap.
            layer.drawLayer { filtered in
                if blur > 0 {
                    filtered.addFilter(.blur(radius: blur))
                }
                filtered.addFilter(.luminanceToAlpha)
                filtered.drawLayer { mask in
                    for command in commands {
                        let gray = Color(white: Double(min(1, max(0, command.maskOpacity))))
                        switch command.style {
                        case .stroke(_, let lineWidth):
                            UniformStrokePaint.draw(
                                path: command.path,
                                color: gray,
                                lineWidth: lineWidth,
                                cap: command.cap,
                                join: command.join,
                                miterLimit: command.miterLimit,
                                in: &mask
                            )
                        case .fill:
                            mask.fill(
                                command.path,
                                with: .color(gray),
                                style: SwiftUI.FillStyle(eoFill: command.fillRule == .evenOdd)
                            )
                        }
                    }
                }
            }
            layer.blendMode = .sourceAtop
            layer.fill(SwiftPath(maskBounds(commands, blur: blur)), with: .color(tint))
        }
    }

    private func maskTint(of command: RoughRenderCommand) -> Color {
        switch command.style {
        case .stroke(let color, _), .fill(let color):
            return color
        }
    }

    /// Bounds of the mask pieces, expanded so a blur is not clipped.
    private func maskBounds(_ commands: ArraySlice<RoughRenderCommand>, blur: CGFloat) -> CGRect {
        var bounds = CGRect.null
        for command in commands {
            var rect = command.path.boundingRect
            if case .stroke(_, let lineWidth) = command.style {
                rect = rect.insetBy(dx: -lineWidth, dy: -lineWidth)
            }
            bounds = bounds.union(rect)
        }
        let pad = blur * 3 + 2
        if bounds.isNull || bounds.isInfinite {
            return commands.first?.path.boundingRect ?? .zero
        }
        return bounds.insetBy(dx: -pad, dy: -pad)
    }
    
    private func renderCommand(_ command: RoughRenderCommand, in context: inout GraphicsContext) {
        switch command.style {
        case let .stroke(color, lineWidth):
            UniformStrokePaint.draw(
                path: command.path,
                color: color,
                lineWidth: lineWidth,
                cap: command.cap,
                join: command.join,
                miterLimit: command.miterLimit,
                in: &context
            )
        case let .fill(color):
            // Even-odd keeps holes in glyphs. Crayon passes opt into winding so wax marks union.
            context.fill(
                command.path,
                with: .color(color),
                style: SwiftUI.FillStyle(eoFill: command.fillRule == .evenOdd)
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
        svgClipPath: SwiftPath? = nil,
        skipOutline: Bool = false,
        nextGroup: inout Int
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
            if skipOutline {
                return []
            }
            let basePath = SwiftPath.from(operationSet: set)
            let path: SwiftPath
            if let transform = svgTransform {
                path = basePath.applying(transform)
            } else {
                path = basePath
            }
            let strokeScale = options.resolvedOpacityProfile().value(at: 0)
            let strokeColor = Color(options.stroke).opacity(Double(options.strokeOpacity) * Double(strokeScale))

            if let crayon = options.resolvedCrayonStyle {
                let crayonCommands = crayonPasses(
                    operations: set.operations,
                    width: CGFloat(strokeWidth),
                    style: crayon,
                    color: strokeColor,
                    transform: svgTransform,
                    clipPath: nil,
                    inverseClip: false
                )
                if !crayonCommands.isEmpty {
                    return crayonCommands
                }
            }
            
            // Check if brush profile requires custom rendering
            if options.brushProfile.requiresCustomRendering {
                // Convert stroke to filled path with variable width
                let filledPath = StrokeToFillConverter.convert(
                    operations: set.operations,
                    baseWidth: CGFloat(strokeWidth),
                    profile: options.brushProfile,
                    miterLimit: options.strokeMiterLimit
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
                        style: .fill(strokeColor),
                        fillRule: Self.brushFillRule(operations: set.operations, profile: options.brushProfile)
                    )
                ]
            } else {
                // Standard stroke rendering with cap and join
                return [
                    RoughRenderCommand(
                        path: path,
                        style: .stroke(strokeColor, lineWidth: CGFloat(strokeWidth)),
                        cap: options.strokeCap,
                        join: options.strokeJoin,
                        miterLimit: options.strokeMiterLimit
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
            if let crayon = options.resolvedCrayonStyle {
                let crayonCommands = crayonPasses(
                    operations: set.operations,
                    width: CGFloat(effectiveFillWeight),
                    style: crayon,
                    color: color,
                    transform: svgTransform,
                    clipPath: clipPath,
                    inverseClip: inverseClip
                )
                if !crayonCommands.isEmpty {
                    return crayonCommands
                }
            }
            return [
                RoughRenderCommand(
                    path: path,
                    style: .stroke(color, lineWidth: CGFloat(effectiveFillWeight)),
                    clipPath: clipPath,
                    inverseClip: inverseClip,
                    cap: options.strokeCap,
                    join: options.strokeJoin,
                    miterLimit: options.strokeMiterLimit
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
            if options.fillStyle == .watercolor {
                return watercolorFill(shape: path, options: options, nextGroup: &nextGroup)
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
            if options.fillStyle == .watercolor {
                return watercolorFill(shape: path, options: options, nextGroup: &nextGroup)
            }
            let color = Color(options.fill).opacity(Double(options.fillOpacity))
            return [
                RoughRenderCommand(
                    path: path,
                    style: .fill(color)
                )
            ]

        case .path2DPattern:
            // Pattern fill: render hachure lines clipped to the shape path
            guard let svgPathString = set.path else { return [] }
            
            // Build the hachure lines path from operations
            let hachureBasePath = SwiftPath.from(operationSet: set)
            
            // Build the clip path from the SVG path string
            let shapeBasePath = SwiftPath(UIBezierPath(svgPath: svgPathString).cgPath)
            
            // Apply transforms if needed
            let hachurePath: SwiftPath
            let shapePath: SwiftPath
            if let transform = svgTransform {
                hachurePath = hachureBasePath.applying(transform)
                shapePath = shapeBasePath.applying(transform)
            } else {
                hachurePath = hachureBasePath
                shapePath = shapeBasePath
            }
            
            let color = Color(options.fill).opacity(Double(options.fillOpacity))
            
            // If there are hachure operations, render them clipped to the shape.
            // A crayon brush stamps those lines as wax instead of a solid stroke.
            // Otherwise fall back to stroking the shape (for stroke alignment behavior).
            if !set.operations.isEmpty {
                if let crayon = options.resolvedCrayonStyle {
                    let crayonCommands = crayonPasses(
                        operations: set.operations,
                        width: CGFloat(effectiveFillWeight),
                        style: crayon,
                        color: color,
                        transform: svgTransform,
                        clipPath: shapePath,
                        inverseClip: false
                    )
                    if !crayonCommands.isEmpty {
                        return crayonCommands
                    }
                }
                return [
                    RoughRenderCommand(
                        path: hachurePath,
                        style: .stroke(color, lineWidth: CGFloat(effectiveFillWeight)),
                        clipPath: shapePath,
                        inverseClip: false,
                        cap: options.strokeCap,
                        join: options.strokeJoin,
                        miterLimit: options.strokeMiterLimit
                    )
                ]
            } else {
                // Fallback: stroke the shape path (used for stroke alignment tests)
                return [
                    RoughRenderCommand(
                        path: shapePath,
                        style: .stroke(color, lineWidth: CGFloat(effectiveFillWeight)),
                        clipPath: clipPath,
                        inverseClip: inverseClip,
                        cap: options.strokeCap,
                        join: options.strokeJoin,
                        miterLimit: options.strokeMiterLimit
                    )
                ]
            }
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
        guard let fillPath = FillGeometry.adjustedPath(
            shapePath, padding: options.fillPadding, offset: options.fillOffset
        ) else {
            return []
        }
        
        // Clip scribble fills for SVG paths and native polygons. Both can be
        // concave (stars, arrows, custom silhouettes), and the zig-zag can
        // bridge notches between ray intersections. The clip is the padded
        // fill region. Rectangles, circles, and ellipses stay unclipped.
        let clipPath = scribbleClipPath(fillPath: fillPath, drawing: drawing, isSVGPath: isSVGPath)
        
        // Generate scribble fill operation sets
        let scribbleSets = ScribbleFillGenerator.generate(for: fillPath, options: options)
        
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

            if let crayon = options.resolvedCrayonStyle {
                let crayonCommands = crayonPasses(
                    operations: set.operations,
                    width: CGFloat(fillWeight),
                    style: crayon,
                    color: color,
                    transform: nil,
                    clipPath: clipPath,
                    inverseClip: false
                )
                if !crayonCommands.isEmpty {
                    return crayonCommands
                }
            }
            
            // Check if brush strokes are enabled and profile needs custom rendering
            let useBrushStroke = options.scribbleUseBrushStroke && 
                (options.brushProfile.requiresCustomRendering || 
                 options.thicknessProfile.variesAlongStroke ||
                 options.brushTip.roundness < 0.99)
            
            if useBrushStroke {
                // Convert to filled path with variable width
                let filledPath = StrokeToFillConverter.convert(
                    operations: set.operations,
                    baseWidth: CGFloat(fillWeight),
                    profile: options.brushProfile,
                    miterLimit: options.strokeMiterLimit
                )
                return [
                    RoughRenderCommand(
                        path: filledPath,
                        style: .fill(color),
                        clipPath: clipPath,
                        inverseClip: false,
                        fillRule: Self.brushFillRule(operations: set.operations, profile: options.brushProfile)
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
                        join: options.strokeJoin,
                        miterLimit: options.strokeMiterLimit
                    )
                ]
            }
        }
    }

    /// Returns whether scribble-fill strokes should be clipped to the shape
    /// path. Clipping is required for potentially concave outlines where a
    /// continuous scribble can cross outside the shape between ray-cast
    /// intersections. Native polygons are the primary non-SVG case; SVG paths
    /// are always clipped because they can encode arbitrary concave geometry
    /// and holes.
    func shouldClipScribbleFill(drawing: Drawing, isSVGPath: Bool) -> Bool {
        isSVGPath || drawing.shape == "polygon"
    }

    /// Clip path for a scribble fill, or nil when the shape stays unclipped.
    ///
    /// SVG paths are one authored contour (plus holes), so the whole path is
    /// the clip. A native polygon's rough outline is two closed passes in
    /// continuous mode. Even-odd clipping both passes cancels the interior
    /// and leaves only the thin ring between them. One pass is the filled
    /// polygon. Legacy outlines are separate edge strokes, so the clip is
    /// rebuilt from one vertex per edge.
    func scribbleClipPath(fillPath: CGPath, drawing: Drawing, isSVGPath: Bool) -> SwiftPath? {
        guard shouldClipScribbleFill(drawing: drawing, isSVGPath: isSVGPath) else {
            return nil
        }
        if isSVGPath {
            return SwiftPath(fillPath)
        }
        if let contour = firstClosedSubpath(of: fillPath),
           contour.boundingBox.width > 1, contour.boundingBox.height > 1 {
            return SwiftPath(contour)
        }
        let rebuilt = polygonClip(fromEdgeMoves: fillPath)
        if rebuilt.boundingBox.width > 1, rebuilt.boundingBox.height > 1 {
            return SwiftPath(rebuilt)
        }
        return SwiftPath(fillPath)
    }

    /// Copies elements through the first `closeSubpath`. Nil when the path
    /// never closes, which is the legacy per-edge outline.
    func firstClosedSubpath(of path: CGPath) -> CGPath? {
        let result = CGMutablePath()
        var closed = false
        path.applyWithBlock { element in
            if closed { return }
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                result.move(to: points[0])
            case .addLineToPoint:
                result.addLine(to: points[0])
            case .addQuadCurveToPoint:
                result.addQuadCurve(to: points[1], control: points[0])
            case .addCurveToPoint:
                result.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closeSubpath:
                result.closeSubpath()
                closed = true
            @unknown default:
                break
            }
        }
        return closed ? result : nil
    }

    /// One vertex per edge for a legacy polygon, whose outline is a pair of
    /// strokes per side rather than a closed contour.
    func polygonClip(fromEdgeMoves path: CGPath) -> CGPath {
        var moves: [CGPoint] = []
        path.applyWithBlock { element in
            if element.pointee.type == .moveToPoint {
                moves.append(element.pointee.points[0])
            }
        }
        var vertices: [CGPoint] = []
        var index = 0
        while index < moves.count {
            let point = moves[index]
            if let first = vertices.first, vertices.count >= 3,
               hypot(point.x - first.x, point.y - first.y) < 4 {
                break
            }
            vertices.append(point)
            if index + 1 < moves.count {
                let next = moves[index + 1]
                if hypot(next.x - point.x, next.y - point.y) < 12 {
                    index += 2
                    continue
                }
            }
            index += 1
        }
        let result = CGMutablePath()
        guard let first = vertices.first, vertices.count >= 3 else { return result }
        result.move(to: first)
        for point in vertices.dropFirst() {
            result.addLine(to: point)
        }
        result.closeSubpath()
        return result
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
    
    /// Clipped watercolor wash for a fill path the generator already padded.
    func watercolorFill(
        shape: SwiftPath,
        options: Options,
        nextGroup: inout Int
    ) -> [RoughRenderCommand] {
        WatercolorFill.commands(
            shape: shape,
            color: Color(options.fill),
            style: options.resolvedWatercolorFillStyle(),
            fillOpacity: CGFloat(options.fillOpacity),
            nextGroup: &nextGroup
        )
    }

    /// Wax passes for a stroke or for fill lines (hachure, zigzag, scribble).
    ///
    /// `width` is the wax width in destination points. `transform` moves the
    /// centerline and does not scale `width`. Each pass is a winding fill so
    /// flecks union; clip them when the lines must stay inside a shape.
    func crayonPasses(
        operations: [Operation],
        width: CGFloat,
        style: CrayonStyle,
        color: Color,
        transform: CGAffineTransform?,
        clipPath: SwiftPath?,
        inverseClip: Bool
    ) -> [RoughRenderCommand] {
        let passes = CrayonStroke.passes(
            operations: operations,
            width: width,
            style: style,
            transform: transform ?? .identity
        )
        return passes.map { pass in
            RoughRenderCommand(
                path: pass.path,
                style: .fill(color.opacity(Double(pass.opacity))),
                clipPath: clipPath,
                inverseClip: inverseClip,
                fillRule: .winding
            )
        }
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
        
        // Calculate the scaled dimensions
        let scaledWidth = bounds.width * scaleFactor
        let scaledHeight = bounds.height * scaleFactor
        
        // Calculate offset to center the scaled path in the frame
        // After scaling, bounds.origin maps to (bounds.minX * scale, bounds.minY * scale)
        // We want it to map to ((frame.width - scaledWidth) / 2, (frame.height - scaledHeight) / 2)
        let offsetX = (frame.width - scaledWidth) / 2 - bounds.minX * scaleFactor
        let offsetY = (frame.height - scaledHeight) / 2 - bounds.minY * scaleFactor
        
        // Build transform: scale then translate
        // For point p: new_p = (p.x * scale + offsetX, p.y * scale + offsetY)
        return CGAffineTransform(a: scaleFactor, b: 0, c: 0, d: scaleFactor, tx: offsetX, ty: offsetY)
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
