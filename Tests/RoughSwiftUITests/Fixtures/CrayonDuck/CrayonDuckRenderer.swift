import CoreGraphics
import UIKit
@testable import RoughSwiftUI

/// Draws the v3g duck with one shared fit. Fill weight is in viewBox units and is scaled here.
enum CrayonDuckRenderer {
    @MainActor
    static func image(parts: [CrayonDuckPart]) -> UIImage {
        let size = CrayonDuckV3G.canvasSize
        let transform = CrayonDuckV3G.canvasTransform
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            context.cgContext.clear(CGRect(origin: .zero, size: size))
            draw(parts: parts, transform: transform, size: size, into: context.cgContext)
        }
    }

    static func composited(_ image: UIImage, on color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            color.setFill()
            UIRectFill(CGRect(origin: .zero, size: image.size))
            image.draw(at: .zero)
        }
    }

    @MainActor
    private static func draw(
        parts: [CrayonDuckPart],
        transform: CGAffineTransform,
        size: CGSize,
        into cg: CGContext
    ) {
        for part in parts {
            guard let drawing = Engine.shared.generate(
                drawable: RoughSwiftUI.Path(d: part.path),
                options: part.options,
                size: size
            ) else {
                continue
            }
            let fill = part.options.fill.withAlphaComponent(CGFloat(part.options.fillOpacity))
            for set in drawing.sets {
                switch set.type {
                case .path2DFill:
                    guard fill.cgColor.alpha > 0.01, let svg = set.path else { continue }
                    var fit = transform
                    guard let fitted = UIBezierPath(svgPath: svg).cgPath.copy(using: &fit) else { continue }
                    cg.addPath(fitted)
                    cg.setFillColor(fill.cgColor)
                    cg.fillPath(using: .winding)
                case .path2DPattern:
                    guard fill.cgColor.alpha > 0.01, let svg = set.path else { continue }
                    cg.saveGState()
                    var clipFit = transform
                    if let clip = UIBezierPath(svgPath: svg).cgPath.copy(using: &clipFit) {
                        cg.addPath(clip)
                        cg.clip(using: .winding)
                    }
                    if part.options.fillStyle == .scribble {
                        drawScribble(svg: svg, options: part.options, fill: fill, transform: transform, into: cg)
                    }
                    cg.restoreGState()
                case .path:
                    guard part.options.strokeOpacity > 0.01 else { break }
                    if let crayon = part.options.brushProfile.crayon {
                        let passes = CrayonStroke.passes(
                            operations: set.operations,
                            width: CGFloat(part.options.strokeWidth),
                            style: crayon,
                            transform: transform
                        )
                        for pass in passes {
                            cg.addPath(pass.path.cgPath)
                            cg.setFillColor(part.options.stroke.withAlphaComponent(CGFloat(part.options.strokeOpacity) * pass.opacity).cgColor)
                            cg.fillPath(using: .winding)
                        }
                    } else {
                        var fit = transform
                        guard let fitted = path(from: set.operations).copy(using: &fit) else { continue }
                        cg.addPath(fitted)
                        cg.setStrokeColor(part.options.stroke.withAlphaComponent(CGFloat(part.options.strokeOpacity)).cgColor)
                        cg.setLineWidth(CGFloat(part.options.strokeWidth))
                        cg.setLineCap(part.options.strokeCap.cgLineCap)
                        cg.setLineJoin(part.options.strokeJoin.cgLineJoin)
                        cg.strokePath()
                    }
                default:
                    break
                }
            }
        }
    }

    /// Scribble is built here. The engine's pattern ops for `.scribble` are hachure and are ignored.
    private static func drawScribble(
        svg: String,
        options: Options,
        fill: UIColor,
        transform: CGAffineTransform,
        into cg: CGContext
    ) {
        let source = UIBezierPath(svgPath: svg).cgPath
        let sets = ScribbleFillGenerator.generate(for: source, options: options)
        guard let crayon = options.brushProfile.crayon else { return }
        let weight = options.fillWeight > 0 ? CGFloat(options.fillWeight) : 1
        for set in sets {
            let passes = CrayonStroke.passes(
                operations: set.operations,
                width: weight * transform.a,
                style: crayon,
                transform: transform
            )
            for pass in passes {
                cg.addPath(pass.path.cgPath)
                cg.setFillColor(fill.withAlphaComponent(fill.cgColor.alpha * pass.opacity).cgColor)
                cg.fillPath(using: .winding)
            }
        }
    }

    private static func path(from operations: [RoughSwiftUI.Operation]) -> CGPath {
        let path = CGMutablePath()
        for operation in operations {
            if let move = operation as? Move {
                let point = move.point.toRoughPoint()
                path.move(to: CGPoint(x: CGFloat(point[0]), y: CGFloat(point[1])))
            } else if let line = operation as? LineTo {
                let point = line.point.toRoughPoint()
                path.addLine(to: CGPoint(x: CGFloat(point[0]), y: CGFloat(point[1])))
            } else if let curve = operation as? BezierCurveTo {
                let end = curve.point.toRoughPoint()
                let control1 = curve.controlPoint1.toRoughPoint()
                let control2 = curve.controlPoint2.toRoughPoint()
                path.addCurve(
                    to: CGPoint(x: CGFloat(end[0]), y: CGFloat(end[1])),
                    control1: CGPoint(x: CGFloat(control1[0]), y: CGFloat(control1[1])),
                    control2: CGPoint(x: CGFloat(control2[0]), y: CGFloat(control2[1]))
                )
            } else if let curve = operation as? QuadraticCurveTo {
                let end = curve.point.toRoughPoint()
                let control = curve.controlPoint.toRoughPoint()
                path.addQuadCurve(
                    to: CGPoint(x: CGFloat(end[0]), y: CGFloat(end[1])),
                    control: CGPoint(x: CGFloat(control[0]), y: CGFloat(control[1]))
                )
            } else if operation is Close {
                path.closeSubpath()
            }
        }
        return path
    }
}
