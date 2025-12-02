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
                    if let drawing = generator.generate(drawable: drawable, options: options) {
                        // Pass original options to preserve SVG-specific settings
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

    func hachureGap(_ value: Float) -> Self {
        var v = self
        v.options.hachureGap = value
        return v
    }

    func hachureAngle(_ value: Float) -> Self {
        var v = self
        v.options.hachureAngle = value
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
