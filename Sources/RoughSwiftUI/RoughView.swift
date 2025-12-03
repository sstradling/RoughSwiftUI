//
//  RoughView.swift
//  RoughSwift
//
//  Created by khoa on 26/03/2022.
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

    /// Set the angle of fill lines in degrees (0-360).
    /// - 0° = horizontal lines
    /// - 45° = diagonal lines (default)
    /// - 90° = vertical lines
    func fillAngle(_ value: Float) -> Self {
        var v = self
        v.options.fillAngle = value
        return v
    }

    func curveTightness(_ value: Float) -> Self {
        var v = self
        v.options.curveTightness = value
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
    
    /// Set the starting angle for scribble fill (0-360 degrees).
    ///
    /// The scribble pattern starts from this position on the shape's edge
    /// and traverses to the opposite point (origin + 180 degrees).
    ///
    /// - Parameter degrees: Starting angle in degrees.
    ///   - 0 = right-center edge
    ///   - 90 = bottom-center
    ///   - 180 = left-center
    ///   - 270 = top-center
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
    
    // MARK: - Text modifiers
    
    /// Add text to be rendered with rough styling.
    ///
    /// The text is converted to vector paths using CoreText and rendered
    /// with the current fill/stroke settings.
    ///
    /// - Parameters:
    ///   - string: The text string to render.
    ///   - font: The font to use for rendering.
    /// - Returns: The view with text added.
    func text(_ string: String, font: UIFont) -> Self {
        draw(Text(string, font: font))
    }
    
    /// Add attributed text to be rendered with rough styling.
    ///
    /// The attributed string can contain multiple fonts, sizes, and other text attributes.
    ///
    /// - Parameter attributedString: The attributed string to render.
    /// - Returns: The view with text added.
    func text(attributedString: NSAttributedString) -> Self {
        draw(Text(attributedString: attributedString))
    }
    
    /// Add text with a named font to be rendered with rough styling.
    ///
    /// - Parameters:
    ///   - string: The text string to render.
    ///   - fontName: The PostScript name of the font (e.g., "Helvetica-Bold").
    ///   - fontSize: The font size in points.
    /// - Returns: The view with text added.
    func text(_ string: String, fontName: String, fontSize: CGFloat) -> Self {
        let font = UIFont(name: fontName, size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
        return text(string, font: font)
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
