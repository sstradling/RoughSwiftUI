//
//  RoughView.swift
//  RoughSwift
//
//  Created by khoa on 26/03/2022.
//
import SwiftUI
import UIKit

/// A SwiftUI view that renders hand‑drawn Rough.js primitives using `Canvas`.
///
/// Configure it using the builder‑style modifiers (e.g. `.roughness`, `.stroke`)
/// and one or more drawables via `.draw(Rectangle(...))`, `.rectangle()`, etc.
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
                let renderSize = canvasSize == .zero ? size : canvasSize
                guard renderSize.width > 0, renderSize.height > 0 else { return }

                let generator = Engine.shared.generator(size: renderSize)
                let renderer = SwiftUIRenderer()

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
                            
                            if let drawing = generator.generate(drawable: drawable, options: patternOptions) {
                                renderer.render(
                                    drawing: drawing,
                                    options: patternOptions,
                                    in: &context,
                                    size: renderSize
                                )
                            }
                        }
                    } else {
                        // Standard single-pass rendering
                        if let drawing = generator.generate(drawable: drawable, options: options) {
                            renderer.render(
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
    
    /// Set the smoothing level for strokes to achieve a more finished appearance.
    ///
    /// Smoothing converts jagged line segments into smooth Catmull-Rom curves,
    /// giving the hand-drawn strokes a more polished look while retaining character.
    ///
    /// - Parameter value: Smoothing factor from 0.0 (no smoothing) to 1.0 (maximum).
    ///   - 0.0 = No smoothing, original hand-drawn appearance (default)
    ///   - 0.3 = Subtle smoothing, retains most rough character
    ///   - 0.5 = Moderate smoothing, balanced appearance
    ///   - 0.7 = Heavy smoothing, polished look
    ///   - 1.0 = Maximum smoothing, very clean curves
    func smoothing(_ value: Float) -> Self {
        var v = self
        v.options.smoothing = max(0, min(1, value))
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

    func fillStyle(_ value: FillStyle) -> Self {
        var v = self
        v.options.fillStyle = value
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
