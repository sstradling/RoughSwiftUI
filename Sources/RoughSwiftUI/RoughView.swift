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
    var options = Options()

    /// The list of shapes to render.
    var drawables: [Drawable] = []

    /// When `true`, final SwiftUI paths are inset slightly so sketchy strokes
    /// are less likely to be clipped by the view bounds.
    var constrainToBounds: Bool = false

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
                        renderer.render(
                            drawing: drawing,
                            in: &context,
                            size: renderSize,
                            constrainToBounds: constrainToBounds
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

    /// Inset and scale shapes so that the sketchy strokes are less likely to
    /// be clipped by the view's bounds.
    ///
    /// - Parameter value: Pass `true` to enable bounds-constrained rendering.
    ///   Defaults to `true` when the modifier is used without arguments.
    func constrainToBounds(_ value: Bool = true) -> Self {
        var v = self
        v.constrainToBounds = value
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
}
