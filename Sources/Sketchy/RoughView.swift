//
//  RoughView.swift
//  RoughSwift
//
//  Created by khoa on 26/03/2022.
//
//  Modifications Copyright © 2025 Seth Stradling. All rights reserved.
//
import SwiftUI
import UIKit
import os.signpost

/// Shared renderer instance to avoid allocations on every frame.
private let sharedRenderer = SwiftUIRenderer()

/// A SwiftUI view that renders hand‑drawn Rough.js primitives using `Canvas`.
///
/// Configure it using the builder‑style modifiers (e.g. `.roughness`, `.stroke`)
/// and one or more drawables via `.draw(Rectangle(...))`, `.rectangle()`, etc.
///
/// ## Performance
///
/// RoughView uses internal caching to optimize rendering performance:
/// - **Generator caching**: Generators are cached by canvas size, avoiding
///   repeated JavaScript context calls.
/// - **Drawing caching**: Generated drawings are cached by drawable + options,
///   avoiding repeated rough.js computations.
///
/// The caches are automatically managed and evict old entries when capacity
/// is reached. You can manually clear caches via `Engine.shared.clearCaches()`.
public struct RoughView: View {
    /// Rendering options forwarded to the Rough.js engine.
    public internal(set) var options = Options()

    /// The list of shapes to render.
    public internal(set) var drawables: [Drawable] = []

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            Canvas { context, canvasSize in
                measurePerformance(RenderingSignpost.canvasRender, log: RoughPerformanceLog.rendering, metadata: "drawables=\(drawables.count)") {
                    let renderSize = canvasSize == .zero ? size : canvasSize
                    guard renderSize.width > 0, renderSize.height > 0 else { return }

                    // Use cached generator (avoids JS bridge call if size unchanged)
                    let generator = Engine.shared.generator(size: renderSize)

                    for drawable in drawables {
                        // Check if we have a spacing pattern for gradient effects
                        if let pattern = options.fillSpacingPattern, !pattern.isEmpty {
                            // Render multiple passes with different spacing for gradient effect
                            let baseSpacing = options.fillSpacing
                            let weight = options.effectiveFillWeight
                            
                            for (index, multiplier) in pattern.enumerated() {
                                var patternOptions = options
                                patternOptions.fillSpacing = baseSpacing * multiplier
                                // Offset each layer slightly to create the gradient effect
                                // by adjusting the fill weight slightly for each pass
                                let layerWeight = weight * (1.0 + Float(index) * 0.01)
                                patternOptions.fillWeight = layerWeight
                                
                                // Drawing is cached by drawable + patternOptions
                                if let drawing = generator.generate(drawable: drawable, options: patternOptions) {
                                    sharedRenderer.render(
                                        drawing: drawing,
                                        options: patternOptions,
                                        in: &context,
                                        size: renderSize
                                    )
                                }
                            }
                        } else {
                            // Standard single-pass rendering
                            // Drawing is cached by drawable + options
                            if let drawing = generator.generate(drawable: drawable, options: options) {
                                sharedRenderer.render(
                                    drawing: drawing,
                                    options: options,
                                    in: &context,
                                    size: renderSize
                                    )
                            }
                        }
                    }
                }
            }
        }
    }
}

public extension RoughView {
    func maxRandomnessOffset(_ value: Float) -> Self {
        var v = self
        v.options.maxRandomnessOffset = value
        return v
    }

    func roughness(_ value: Float) -> Self {
        var v = self
        v.options.roughness = value
        return v
    }

    func bowing(_ value: Float) -> Self {
        var v = self
        v.options.bowing = value
        return v
    }

    func strokeWidth(_ value: Float) -> Self {
        var v = self
        v.options.strokeWidth = value
        return v
    }

    /// Set the miter limit used when `strokeJoin(.miter)` is active.
    ///
    /// The miter limit is the maximum ratio of miter length to stroke width
    /// before the renderer falls back to a bevel join. Lower values clamp
    /// sharp corners sooner; higher values allow longer pointed joins.
    ///
    /// - Parameter value: Miter limit. Values below `1` are clamped to `1`.
    ///   Default is `10`.
    /// - Returns: The view with updated miter-limit behavior.
    func strokeMiterLimit(_ value: CGFloat) -> Self {
        var v = self
        v.options.strokeMiterLimit = max(1, value)
        return v
    }

    func fillWeight(_ value: Float) -> Self {
        var v = self
        v.options.fillWeight = value
        return v
    }

    func dashOffset(_ value: Float) -> Self {
        var v = self
        v.options.dashOffset = value
        return v
    }

    func zigzagOffset(_ value: Float) -> Self {
        var v = self
        v.options.zigzagOffset = value
        return v
    }

    func dashGap(_ value: Float) -> Self {
        var v = self
        v.options.dashGap = value
        return v
    }

    /// Set the spacing between fill lines as a factor of fill line weight.
    /// - Parameter value: Spacing factor (0.5 to 100). Default is 4.0.
    ///   - Lower values = denser fill
    ///   - Higher values = sparser fill
    func fillSpacing(_ value: Float) -> Self {
        var v = self
        v.options.fillSpacing = max(0.5, min(100, value))
        return v
    }
    
    /// Set a pattern of spacing factors for gradient effects.
    /// Each value is a multiplier applied to the base fillSpacing.
    /// - Parameter pattern: Array of spacing multipliers.
    ///   Example: `[1, 1, 2, 3, 5, 8]` creates increasingly sparse lines.
    func fillSpacingPattern(_ pattern: [Float]) -> Self {
        var v = self
        v.options.fillSpacingPattern = pattern
        return v
    }

    /// Set the angle of fill lines in degrees.
    ///
    /// Positive angles rotate clockwise from the +x axis (y points down).
    /// - 0° = horizontal lines
    /// - 45° = diagonal lines (default)
    /// - 90° = vertical lines
    func fillAngle(_ value: Float) -> Self {
        var v = self
        v.options.fillAngle = value
        return v
    }

    /// Insets the fill from the outline by `value` points.
    ///
    /// `0` keeps the fill edge on the shape the outline draws. A positive
    /// value shrinks ellipse radii and offsets polygon edges inward. A
    /// negative value grows the fill past the outline. A padding that
    /// collapses the shape draws no fill.
    func fillPadding(_ value: CGFloat) -> Self {
        var v = self
        v.options.fillPadding = value
        return v
    }

    /// Shifts the fill relative to the outline. `.zero` leaves it centered.
    func fillOffset(_ value: CGSize) -> Self {
        var v = self
        v.options.fillOffset = value
        return v
    }

    /// Shifts the fill by `x` and `y` points relative to the outline.
    func fillOffset(x: CGFloat, y: CGFloat) -> Self {
        fillOffset(CGSize(width: x, height: y))
    }

    /// Fixes the random sequence used for roughness, bowing, and fill wobble.
    ///
    /// The same seed redraws the same strokes. `nil` keeps a new random
    /// sequence each time an uncached drawing is built. See `Options.seed`
    /// for how this interacts with `CrayonStyle.seed`.
    func seed(_ value: UInt64?) -> Self {
        var v = self
        v.options.seed = value
        return v
    }

    func curveTightness(_ value: Float) -> Self {
        var v = self
        v.options.curveTightness = value
        return v
    }

    /// Selects between sampled-point (legacy) and continuous-Bezier stroke
    /// generation for native curved shapes.
    ///
    /// - `.continuous` (default): emits a small fixed number of true cubic
    ///   Beziers that match the underlying parametric shape. A circle becomes
    ///   4 cubics per pass; polygon edges share endpoints with their
    ///   neighbors so a closed shape is one continuous subpath.
    /// - `.legacy`: the original rough.js behavior — outlines are sampled
    ///   at `curveStepCount` points and stitched together with Catmull-Rom
    ///   conversion. Increasing `curveStepCount` for smoothness produces
    ///   *more* visible polygon facets, not fewer.
    ///
    /// Affects: line, rectangle, ellipse, circle, linearPath, polygon,
    /// arc, roundedRectangle, egg. Does not affect SVG paths or text
    /// (those already preserve their authored Beziers via
    /// `SVGPathRenderer`).
    ///
    /// - Parameter value: The continuity mode to apply.
    /// - Returns: The view with updated stroke continuity.
    func strokeContinuity(_ value: StrokeContinuity) -> Self {
        var v = self
        v.options.strokeContinuity = value
        return v
    }

    func curveStepCount(_ value: Float) -> Self {
        var v = self
        v.options.curveStepCount = value
        return v
    }

    func stroke(_ value: UIColor) -> Self {
        var v = self
        v.options.stroke = value
        return v
    }

    /// Set the stroke color using a SwiftUI `Color`.
    /// Internally this is bridged to the engine via `UIColor`/`RoughColor`.
    func stroke(_ value: Color) -> Self {
        var v = self
        v.options.stroke = UIColor(value)
        return v
    }

    func fill(_ value: UIColor) -> Self {
        var v = self
        v.options.fill = value
        return v
    }

    /// Set the fill color using a SwiftUI `Color`.
    /// Internally this is bridged to the engine via `UIColor`/`RoughColor`.
    func fill(_ value: Color) -> Self {
        var v = self
        v.options.fill = UIColor(value)
        return v
    }
    
    /// Set the stroke opacity (transparency).
    ///
    /// - Parameter value: Opacity from 0 (fully transparent) to 100 (fully opaque).
    ///   Values are clamped to this range. Default is 100.
    func strokeOpacity(_ value: Float) -> Self {
        var v = self
        v.options.strokeOpacity = max(0, min(100, value)) / 100.0
        return v
    }
    
    /// Set the fill opacity (transparency).
    ///
    /// - Parameter value: Opacity from 0 (fully transparent) to 100 (fully opaque).
    ///   Values are clamped to this range. Default is 100.
    func fillOpacity(_ value: Float) -> Self {
        var v = self
        v.options.fillOpacity = max(0, min(100, value)) / 100.0
        return v
    }

    func fillStyle(_ value: FillStyle) -> Self {
        var v = self
        v.options.fillStyle = value
        return v
    }
    
    // MARK: - Scribble Fill Modifiers
    
    /// Set the direction of the scribble strokes, in degrees.
    ///
    /// Core Graphics y points down. 0 runs to the right, 90 runs straight down,
    /// and positive angles rotate clockwise. Each stroke crosses the shape on
    /// that bearing, and the next stroke comes back parallel to it.
    ///
    /// - Parameter degrees: Stroke bearing in degrees. Wraps at 360.
    /// - Returns: The view with updated scribble origin.
    func scribbleOrigin(_ degrees: Float) -> Self {
        var v = self
        v.options.scribbleOrigin = degrees.truncatingRemainder(dividingBy: 360)
        return v
    }
    
    /// Set the number of zig-zags in the scribble fill.
    ///
    /// Higher values create a denser fill pattern.
    ///
    /// - Parameter count: Number of zig-zags (1-100). Default is 10.
    /// - Returns: The view with updated scribble tightness.
    func scribbleTightness(_ count: Int) -> Self {
        var v = self
        v.options.scribbleTightness = max(1, min(100, count))
        return v
    }
    
    /// Set the curvature of vertices in the scribble zig-zag pattern.
    ///
    /// This controls how rounded the corners of the zig-zag are.
    ///
    /// - Parameter percent: Curvature amount (0-50).
    ///   - 0 = sharp corners (default)
    ///   - 50 = maximum curve (50% of segment length)
    /// - Returns: The view with updated scribble curvature.
    func scribbleCurvature(_ percent: Float) -> Self {
        var v = self
        v.options.scribbleCurvature = max(0, min(50, percent))
        return v
    }
    
    /// Enable or disable brush strokes for scribble fill lines.
    ///
    /// When enabled, the scribble lines will use the current brush profile
    /// for variable-width stroke rendering.
    ///
    /// - Parameter enabled: Whether to use brush strokes. Default is false.
    /// - Returns: The view with updated brush stroke setting.
    func scribbleUseBrushStroke(_ enabled: Bool) -> Self {
        var v = self
        v.options.scribbleUseBrushStroke = enabled
        return v
    }
    
    /// Configure scribble fill with all parameters at once.
    ///
    /// - Parameters:
    ///   - origin: Starting angle in degrees (0-360). Default is 0.
    ///   - tightness: Number of zig-zags (1-100). Default is 10.
    ///   - curvature: Vertex curvature (0-50). Default is 0.
    ///   - useBrushStroke: Whether to use brush strokes. Default is false.
    /// - Returns: The view with updated scribble settings.
    func scribble(
        origin: Float = 0,
        tightness: Int = 10,
        curvature: Float = 0,
        useBrushStroke: Bool = false
    ) -> Self {
        var v = self
        v.options.scribbleOrigin = origin.truncatingRemainder(dividingBy: 360)
        v.options.scribbleTightness = max(1, min(100, tightness))
        v.options.scribbleCurvature = max(0, min(50, curvature))
        v.options.scribbleUseBrushStroke = useBrushStroke
        return v
    }
    
    /// Set a variable tightness pattern for scribble fill.
    ///
    /// The traversal axis is divided into sections corresponding to the array length.
    /// Each section uses its corresponding tightness value from the array.
    /// This creates variable density patterns within a single continuous scribble.
    ///
    /// - Parameter pattern: Array of tightness values (1-100) for each section.
    ///   Example: `[10, 30, 10]` creates a sparse-dense-sparse pattern.
    /// - Returns: The view with updated tightness pattern.
    func scribbleTightnessPattern(_ pattern: [Int]) -> Self {
        var v = self
        v.options.scribbleTightnessPattern = pattern.isEmpty ? nil : pattern
        return v
    }
    
    /// Configure scribble fill with variable tightness pattern.
    ///
    /// - Parameters:
    ///   - origin: Starting angle in degrees (0-360). Default is 0.
    ///   - tightnessPattern: Array of tightness values for variable density sections.
    ///   - curvature: Vertex curvature (0-50). Default is 0.
    ///   - useBrushStroke: Whether to use brush strokes. Default is false.
    /// - Returns: The view with updated scribble settings.
    func scribble(
        origin: Float = 0,
        tightnessPattern: [Int],
        curvature: Float = 0,
        useBrushStroke: Bool = false
    ) -> Self {
        var v = self
        v.options.scribbleOrigin = origin.truncatingRemainder(dividingBy: 360)
        v.options.scribbleTightnessPattern = tightnessPattern.isEmpty ? nil : tightnessPattern
        v.options.scribbleCurvature = max(0, min(50, curvature))
        v.options.scribbleUseBrushStroke = useBrushStroke
        return v
    }

    func draw(_ drawable: Drawable) -> Self {
        var v = self
        v.drawables.append(drawable)
        return v
    }

    func rectangle() -> Self {
        draw(FullRectangle())
    }

    func circle() -> Self {
        draw(FullCircle())
    }
    
    /// Draw a full-size rounded rectangle that fills the available space.
    ///
    /// - Parameter cornerRadius: The radius of the rounded corners. Default is 8.
    /// - Returns: The view with a rounded rectangle added.
    func roundedRectangle(cornerRadius: Float = 8) -> Self {
        draw(FullRoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Draw a full-size egg shape that fills the available space.
    ///
    /// - Parameter tilt: Controls the asymmetry of the egg.
    ///   - Positive values (default 0.3): narrower top, wider bottom (natural egg shape).
    ///   - Negative values: narrower bottom, wider top.
    ///   - Zero: symmetric ellipse.
    /// - Returns: The view with an egg shape added.
    func egg(tilt: Float = 0.3) -> Self {
        draw(FullEgg(tilt: tilt))
    }
    
    // MARK: - Text modifiers
    
    /// Add text to be rendered with rough styling, positioned within the view bounds.
    ///
    /// The text is converted to vector paths using CoreText and positioned
    /// according to the alignment and offset parameters. By default, text is
    /// centered both horizontally and vertically.
    ///
    /// - Parameters:
    ///   - string: The text string to render.
    ///   - font: The font to use for rendering.
    ///   - horizontalAlignment: Horizontal alignment within the view. Default is `.center`.
    ///   - verticalAlignment: Vertical alignment within the view. Default is `.center`.
    ///   - offsetX: Additional horizontal offset in points. Positive moves right. Default is `0`.
    ///   - offsetY: Additional vertical offset in points. Positive moves down. Default is `0`.
    /// - Returns: The view with positioned text added.
    ///
    /// ## Example - Centered (Default)
    /// ```swift
    /// RoughView()
    ///     .fill(.orange)
    ///     .stroke(.black)
    ///     .strokeWidth(2.0)
    ///     .text("SLAP!", font: .systemFont(ofSize: 100, weight: .heavy))
    ///     .frame(width: 300, height: 160)
    /// ```
    ///
    /// ## Example - Leading Top with Offset
    /// ```swift
    /// RoughView()
    ///     .fill(.blue)
    ///     .text("Hello", font: .systemFont(ofSize: 32),
    ///           horizontalAlignment: .leading,
    ///           verticalAlignment: .top,
    ///           offsetX: 8, offsetY: 4)
    ///     .frame(width: 200, height: 100)
    /// ```
    func text(
        _ string: String,
        font: UIFont,
        horizontalAlignment: RoughTextHorizontalAlignment = .center,
        verticalAlignment: RoughTextVerticalAlignment = .center,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) -> Self {
        draw(FullText(
            string,
            font: font,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            offsetX: offsetX,
            offsetY: offsetY
        ))
    }
    
    /// Add attributed text to be rendered with rough styling, positioned within the view bounds.
    ///
    /// The attributed string can contain multiple fonts, sizes, and other text attributes.
    /// The text is positioned according to the alignment and offset parameters.
    ///
    /// - Parameters:
    ///   - attributedString: The attributed string to render.
    ///   - horizontalAlignment: Horizontal alignment within the view. Default is `.center`.
    ///   - verticalAlignment: Vertical alignment within the view. Default is `.center`.
    ///   - offsetX: Additional horizontal offset in points. Default is `0`.
    ///   - offsetY: Additional vertical offset in points. Default is `0`.
    /// - Returns: The view with positioned text added.
    func text(
        attributedString: NSAttributedString,
        horizontalAlignment: RoughTextHorizontalAlignment = .center,
        verticalAlignment: RoughTextVerticalAlignment = .center,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) -> Self {
        draw(FullText(
            attributedString: attributedString,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            offsetX: offsetX,
            offsetY: offsetY
        ))
    }
    
    /// Add text with a named font to be rendered with rough styling, positioned within the view bounds.
    ///
    /// - Parameters:
    ///   - string: The text string to render.
    ///   - fontName: The PostScript name of the font (e.g., "Helvetica-Bold").
    ///   - fontSize: The font size in points.
    ///   - horizontalAlignment: Horizontal alignment within the view. Default is `.center`.
    ///   - verticalAlignment: Vertical alignment within the view. Default is `.center`.
    ///   - offsetX: Additional horizontal offset in points. Default is `0`.
    ///   - offsetY: Additional vertical offset in points. Default is `0`.
    /// - Returns: The view with positioned text added.
    func text(
        _ string: String,
        fontName: String,
        fontSize: CGFloat,
        horizontalAlignment: RoughTextHorizontalAlignment = .center,
        verticalAlignment: RoughTextVerticalAlignment = .center,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) -> Self {
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        return text(
            string,
            font: font,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment,
            offsetX: offsetX,
            offsetY: offsetY
        )
    }
    
    // MARK: - SVG-specific modifiers
    
    /// Set the stroke width specifically for SVG path rendering.
    /// If not set, falls back to `strokeWidth`.
    func svgStrokeWidth(_ value: Float) -> Self {
        var v = self
        v.options.svgStrokeWidth = value
        return v
    }
    
    /// Set the fill weight specifically for SVG path rendering.
    /// If not set, falls back to `fillWeight`.
    func svgFillWeight(_ value: Float) -> Self {
        var v = self
        v.options.svgFillWeight = value
        return v
    }
    
    /// Set the alignment of the SVG fill stroke relative to the path.
    /// - `.center`: Stroke centered on path (default)
    /// - `.inside`: Stroke on inner edge of path
    /// - `.outside`: Stroke on outer edge of path
    func svgFillStrokeAlignment(_ value: SVGFillStrokeAlignment) -> Self {
        var v = self
        v.options.svgFillStrokeAlignment = value
        return v
    }
    
    // MARK: - Brush Profile Modifiers
    
    /// Set the complete brush profile for stroke rendering.
    ///
    /// A brush profile controls the brush tip shape, thickness variation along
    /// the stroke, and stroke cap/join styles.
    ///
    /// - Parameter profile: The brush profile to use.
    /// - Returns: The view with updated brush profile.
    func brushProfile(_ profile: BrushProfile) -> Self {
        var v = self
        v.options.brushProfile = profile
        return v
    }
    
    /// Configure the brush tip shape for calligraphic effects.
    ///
    /// The brush tip determines how stroke width varies based on stroke direction.
    /// A circular tip produces uniform width, while a flat ellipse creates
    /// calligraphic-style strokes with direction-dependent width.
    ///
    /// - Parameters:
    ///   - roundness: Aspect ratio of the ellipse (0.01-1.0). 1.0 = circle.
    ///   - angle: Rotation angle in radians. 0 = horizontal.
    ///   - directionSensitive: Whether width varies with stroke direction.
    /// - Returns: The view with updated brush tip.
    func brushTip(
        roundness: CGFloat = 1.0,
        angle: CGFloat = 0,
        directionSensitive: Bool = true
    ) -> Self {
        var v = self
        v.options.brushTip = BrushTip(
            roundness: roundness,
            angle: angle,
            directionSensitive: directionSensitive
        )
        return v
    }
    
    /// Set a preset brush tip style.
    ///
    /// - Parameter tip: The brush tip preset to use.
    /// - Returns: The view with updated brush tip.
    func brushTip(_ tip: BrushTip) -> Self {
        var v = self
        v.options.brushTip = tip
        return v
    }
    
    /// Set the thickness profile for stroke width variation along the path.
    ///
    /// Thickness profiles create effects like tapered ends, pressure simulation,
    /// or custom artistic variations.
    ///
    /// - Parameter profile: The thickness profile to apply.
    /// - Returns: The view with updated thickness profile.
    func thicknessProfile(_ profile: ThicknessProfile) -> Self {
        var v = self
        v.options.thicknessProfile = profile
        return v
    }

    /// Set how opacity changes along the outline.
    ///
    /// The profile is a multiplier on `strokeOpacity`. `.uniform` leaves the
    /// stroke as it is. A curve that changes along the stroke is drawn into
    /// one mask so overlapping segments do not darken.
    ///
    /// - Parameter profile: Uniform, evenly spaced values, positioned stops, or seeded noise.
    /// - Returns: The view with the updated opacity profile.
    func opacityProfile(_ profile: OpacityProfile) -> Self {
        var v = self
        v.options.opacityProfile = profile
        return v
    }

    /// Set absolute stroke widths at positions along an open stroke.
    ///
    /// Positions run from 0 at the start to 1 at the end and are clamped.
    /// Widths are points. `strokeWidth` does not scale a non-empty list.
    /// With `strokeWidth` 8, `.custom([0.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0.5])`
    /// matches:
    ///
    /// ```swift
    /// .widthStops([(0, 4), (0.1, 8), (0.9, 8), (1, 4)])
    /// ```
    ///
    /// That stroke is 4pt at the start, 8pt from 10% to 90% of its length,
    /// and 4pt at the end. Stops are sorted. The width holds before the first
    /// stop and after the last. An empty list is an even `strokeWidth`.
    ///
    /// This replaces the current thickness profile, including `.variable`
    /// noise, pressure, and taper. The brush tip stays, so a marker's flat
    /// tip still changes width with direction. Closed contours ignore the
    /// stops and keep an even `strokeWidth`. A crayon brush does not use
    /// thickness profiles.
    ///
    /// - Parameter stops: `(position, width)` pairs. Position is 0...1, width is points.
    /// - Returns: The view with `ThicknessProfile.stops`.
    func widthStops(_ stops: [(CGFloat, CGFloat)]) -> Self {
        widthStops(stops.map { WidthStop(position: $0.0, width: $0.1) })
    }

    /// Set absolute stroke widths at positions along an open stroke.
    ///
    /// See `widthStops(_:)` for the tuple form. The same rules apply: point
    /// widths, sorted positions, and no scaling by `strokeWidth`.
    ///
    /// - Parameter stops: Stops along the stroke. An empty list is uniform.
    /// - Returns: The view with `ThicknessProfile.stops`.
    func widthStops(_ stops: [WidthStop]) -> Self {
        var v = self
        v.options.thicknessProfile = .stops(stops)
        return v
    }
    
    /// Set the stroke cap style for line endings.
    ///
    /// - Parameter cap: The cap style (.butt, .round, or .square).
    /// - Returns: The view with updated stroke cap.
    func strokeCap(_ cap: BrushCap) -> Self {
        var v = self
        v.options.strokeCap = cap
        return v
    }
    
    /// Set the stroke join style for corners/vertices.
    ///
    /// - Parameter join: The join style (.miter, .round, or .bevel).
    /// - Returns: The view with updated stroke join.
    func strokeJoin(_ join: BrushJoin) -> Self {
        var v = self
        v.options.strokeJoin = join
        return v
    }

    /// Draws a die-cut sheet or paper ribbon behind the shape.
    ///
    /// Pass `nil` to remove it. A width of `0` also draws nothing. The sketch
    /// itself is unchanged. See `StickerBacking` for closed contours, holes,
    /// and open strokes.
    func stickerBacking(_ backing: StickerBacking?) -> Self {
        var v = self
        v.options.stickerBacking = backing
        return v
    }

    /// Draws paper `width` points past the nominal stroke.
    ///
    /// `smoothness` `0` follows the rough edge. `1` removes fine wobble and
    /// keeps the silhouette. `edge` is `.smooth` or `.torn()`. `color`
    /// defaults to white. `texture` adds paper grain inside the sheet.
    /// Pass `Color.white` or `UIColor.white` when both overloads are visible.
    func stickerBacking(
        width: CGFloat,
        smoothness: CGFloat = 0,
        edge: StickerEdge = .smooth,
        color: Color = .white,
        texture: StickerTexture? = nil
    ) -> Self {
        stickerBacking(StickerBacking(
            width: width,
            smoothness: smoothness,
            edge: edge,
            color: UIColor(color),
            texture: texture
        ))
    }

    /// Draws paper `width` points past the nominal stroke in a `UIColor`.
    ///
    /// `color` has no default here, so a bare `.white` is not ambiguous with
    /// the SwiftUI `Color` overload. `texture` adds paper grain.
    func stickerBacking(
        width: CGFloat,
        smoothness: CGFloat = 0,
        edge: StickerEdge = .smooth,
        color: UIColor,
        texture: StickerTexture? = nil
    ) -> Self {
        stickerBacking(StickerBacking(
            width: width,
            smoothness: smoothness,
            edge: edge,
            color: color,
            texture: texture
        ))
    }
    
    // MARK: - Animation
    
    /// Wraps this RoughView in an AnimatedRoughView with the given configuration.
    ///
    /// The animation applies subtle variations to strokes and fills on a loop,
    /// creating a "breathing" or "sketchy" animation effect.
    ///
    /// - Parameter config: The animation configuration.
    /// - Returns: An AnimatedRoughView wrapping this view.
    func animated(config: AnimationConfig = .default) -> AnimatedRoughView {
        AnimatedRoughView(config: config, roughView: self)
    }
    
    /// Wraps this RoughView in an AnimatedRoughView with custom parameters.
    ///
    /// - Parameters:
    ///   - steps: Number of variation steps before looping (default: 4).
    ///   - speed: Speed of transitions (default: .medium).
    ///   - variance: Amount of variation (default: .medium).
    /// - Returns: An AnimatedRoughView wrapping this view.
    func animated(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    ) -> AnimatedRoughView {
        AnimatedRoughView(
            config: AnimationConfig(steps: steps, speed: speed, variance: variance),
            roughView: self
        )
    }
}
