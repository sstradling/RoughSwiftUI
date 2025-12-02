//
//  SwiftUIRenderer.swift
//  RoughSwift
//
//  Created by Cursor on 30/11/2025.
//
//  Native SwiftUI renderer for RoughSwift drawings.
//

import SwiftUI
import UIKit

/// Internal alias to disambiguate SwiftUI's `Path` from the engine's `Path` drawable.
private typealias SwiftPath = SwiftUI.Path

/// High‑level description of how a path should be drawn in SwiftUI.
public struct RoughRenderCommand {
    /// The path to render.
    public let path: SwiftUI.Path

    /// The style used when rendering the path.
    public let style: Style

    /// Description of stroke or fill styling.
    public enum Style {
        /// Stroke path with a color and line width.
        case stroke(Color, lineWidth: CGFloat)
        /// Fill path with a solid color.
        case fill(Color)
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
    ///   - size: The available canvas size.
    /// - Parameters:
    ///   - drawing: The engine `Drawing` to render.
    ///   - size: The available canvas size.
    ///   - constrainToBounds: When `true`, all generated paths are inset/
    ///     scaled slightly so that sketchy strokes are less likely to be
    ///     clipped by the canvas edges.
    /// - Returns: A collection of `RoughRenderCommand` describing how to render the drawing.
    public func commands(
        for drawing: Drawing,
        in size: CGSize,
        constrainToBounds: Bool = false
    ) -> [RoughRenderCommand] {
        drawing.sets.flatMap { set in
            commands(
                for: set,
                options: drawing.options,
                in: size,
                constrainToBounds: constrainToBounds
            )
        }
    }

    /// Render a `Drawing` directly into a SwiftUI `GraphicsContext`.
    ///
    /// - Parameters:
    ///   - drawing: The engine `Drawing` to render.
    ///   - context: The SwiftUI graphics context to draw into.
    ///   - size: The available canvas size.
    ///   - constrainToBounds: When `true`, all generated paths are inset/
    ///     scaled slightly so that sketchy strokes are less likely to be
    ///     clipped by the canvas edges.
    public func render(
        drawing: Drawing,
        in context: inout GraphicsContext,
        size: CGSize,
        constrainToBounds: Bool = false
    ) {
        let commands = commands(
            for: drawing,
            in: size,
            constrainToBounds: constrainToBounds
        )
        for command in commands {
            switch command.style {
            case let .stroke(color, lineWidth):
                context.stroke(
                    command.path,
                    with: .color(color),
                    lineWidth: lineWidth
                )
            case let .fill(color):
                context.fill(
                    command.path,
                    with: .color(color)
                )
            }
        }
    }
}

// MARK: - Internal helpers

private extension SwiftUIRenderer {
    func commands(
        for set: OperationSet,
        options: Options,
        in size: CGSize,
        constrainToBounds: Bool
    ) -> [RoughRenderCommand] {
        let margin: CGFloat = constrainToBounds ? 4.0 : 0.0

        switch set.type {
        case .path:
            var path = SwiftPath.from(operationSet: set)
            if margin > 0 {
                path = inset(path, in: size, by: margin)
            }
            let strokeColor = Color(options.stroke)
            return [
                RoughRenderCommand(
                    path: path,
                    style: .stroke(strokeColor, lineWidth: CGFloat(options.strokeWidth))
                )
            ]

        case .fillSketch:
            var path = SwiftPath.from(operationSet: set)
            if margin > 0 {
                path = inset(path, in: size, by: margin)
            }
            var fillWeight = options.fillWeight
            if fillWeight < 0 {
                fillWeight = options.strokeWidth / 2
            }
            let color = Color(options.fill)
            return [
                RoughRenderCommand(
                    path: path,
                    style: .stroke(color, lineWidth: CGFloat(fillWeight))
                )
            ]

        case .fillPath:
            var path = SwiftPath.from(operationSet: set)
            if margin > 0 {
                path = inset(path, in: size, by: margin)
            }
            let color = Color(options.fill)
            return [
                RoughRenderCommand(
                    path: path,
                    style: .fill(color)
                )
            ]

        case .path2DFill:
            guard let svgPath = set.path else { return [] }
            var path = scaledSVGPath(svgPath, in: size)
            if margin > 0 {
                path = inset(path, in: size, by: margin)
            }
            let color = Color(options.fill)
            return [
                RoughRenderCommand(
                    path: path,
                    style: .fill(color)
                )
            ]

        case .path2DPattern:
            // Approximate the pattern fill by stroking the SVG path with fill color.
            guard let svgPath = set.path else { return [] }
            var path = scaledSVGPath(svgPath, in: size)
            if margin > 0 {
                path = inset(path, in: size, by: margin)
            }
            var fillWeight = options.fillWeight
            if fillWeight < 0 {
                fillWeight = options.strokeWidth / 2
            }
            let color = Color(options.fill)
            return [
                RoughRenderCommand(
                    path: path,
                    style: .stroke(color, lineWidth: CGFloat(fillWeight))
                )
            ]
        }
    }

    /// Build a SwiftUI `Path` from an SVG path string, scaled into the canvas.
    func scaledSVGPath(_ svg: String, in size: CGSize) -> SwiftPath {
        let bezier = UIBezierPath(svgPath: svg)

        let frame = CGRect(
            origin: .zero,
            size: CGSize(
                width: max(size.width, 1),
                height: max(size.height, 1)
            )
        )

        _ = bezier.fit(into: frame).moveCenter(to: frame.center)
        return SwiftPath(bezier.cgPath)
    }

    /// Inset and scale a path so that it stays within the canvas bounds with
    /// a given margin on all sides.
    func inset(_ path: SwiftPath, in size: CGSize, by margin: CGFloat) -> SwiftPath {
        guard margin > 0 else { return path }

        let rect = CGRect(origin: .zero, size: size)
        guard rect.width > 0, rect.height > 0 else { return path }

        let availableWidth = max(rect.width - 2 * margin, 1)
        let availableHeight = max(rect.height - 2 * margin, 1)

        let scaleX = availableWidth / rect.width
        let scaleY = availableHeight / rect.height
        let factor = min(scaleX, scaleY)

        let center = CGPoint(x: rect.midX, y: rect.midY)
        var transform = CGAffineTransform.identity
        transform = transform
            .translatedBy(x: -center.x, y: -center.y)
            .scaledBy(x: factor, y: factor)
            .translatedBy(x: center.x, y: center.y)

        return path.applying(transform)
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


