//
//  StickerGuide.swift
//  Sketchy
//
//  The input silhouette, without roughness. Sticker smoothness blends the
//  rough outline toward these rings. Nothing here reads or advances the
//  drawing's random sequence.
//

import CoreGraphics
import UIKit

enum StickerGuide {

    static func rings(method: String, arguments: [Any]) -> [StickerGuideRing] {
        switch method {
        case "line":
            guard let x1 = float(arguments, 0), let y1 = float(arguments, 1),
                  let x2 = float(arguments, 2), let y2 = float(arguments, 3) else { return [] }
            return [StickerGuideRing(points: [point(x1, y1), point(x2, y2)], closed: false)]
        case "rectangle":
            guard let x = float(arguments, 0), let y = float(arguments, 1),
                  let width = float(arguments, 2), let height = float(arguments, 3) else { return [] }
            return [StickerGuideRing(points: [
                point(x, y),
                point(x + width, y),
                point(x + width, y + height),
                point(x, y + height)
            ], closed: true)]
        case "ellipse":
            guard let cx = float(arguments, 0), let cy = float(arguments, 1),
                  let width = float(arguments, 2), let height = float(arguments, 3) else { return [] }
            return [StickerGuideRing(
                points: ellipse(cx: cx, cy: cy, rx: width / 2, ry: height / 2),
                closed: true
            )]
        case "circle":
            guard let cx = float(arguments, 0), let cy = float(arguments, 1),
                  let diameter = float(arguments, 2) else { return [] }
            let radius = diameter / 2
            return [StickerGuideRing(
                points: ellipse(cx: cx, cy: cy, rx: radius, ry: radius),
                closed: true
            )]
        case "polygon":
            let vertices = points(from: arguments)
            guard vertices.count >= 3 else { return [] }
            return [StickerGuideRing(points: vertices, closed: true)]
        case "linearPath":
            let vertices = points(from: arguments)
            guard vertices.count >= 2 else { return [] }
            return [StickerGuideRing(points: vertices, closed: false)]
        case "curve":
            let vertices = points(from: arguments)
            guard vertices.count >= 2 else { return [] }
            return [StickerGuideRing(points: vertices, closed: false)]
        case "roundedRectangle":
            guard let x = float(arguments, 0), let y = float(arguments, 1),
                  let width = float(arguments, 2), let height = float(arguments, 3),
                  let radius = float(arguments, 4) else { return [] }
            let vertices = RoughMath.roundedRectanglePolygonPoints(
                x: x, y: y, width: width, height: height, cornerRadius: radius, arcSteps: 10
            )
            return [StickerGuideRing(points: vertices.map { point($0[0], $0[1]) }, closed: true)]
        case "egg":
            guard let cx = float(arguments, 0), let cy = float(arguments, 1),
                  let width = float(arguments, 2), let height = float(arguments, 3) else { return [] }
            let tilt = float(arguments, 4) ?? 0.3
            let vertices = RoughMath.eggPolygonPoints(
                cx: cx, cy: cy, width: width, height: height, tilt: tilt, stepCount: 48
            )
            return [StickerGuideRing(points: vertices.map { point($0[0], $0[1]) }, closed: true)]
        case "arc":
            guard let cx = float(arguments, 0), let cy = float(arguments, 1),
                  let width = float(arguments, 2), let height = float(arguments, 3),
                  let start = float(arguments, 4), let stop = float(arguments, 5) else { return [] }
            let closed = arguments.count > 6 && (arguments[6] as? Bool) == true
            return [arcRing(cx: cx, cy: cy, rx: width / 2, ry: height / 2, start: start, stop: stop, closed: closed)]
        case "path":
            guard let d = arguments.first as? String else { return [] }
            return svgRings(d)
        default:
            return []
        }
    }

    private static func ellipse(cx: Float, cy: Float, rx: Float, ry: Float) -> [CGPoint] {
        let steps = 64
        return (0..<steps).map { index in
            let angle = Float(index) / Float(steps) * 2 * .pi
            return point(cx + rx * cos(angle), cy + ry * sin(angle))
        }
    }

    private static func arcRing(
        cx: Float, cy: Float, rx: Float, ry: Float,
        start: Float, stop: Float, closed: Bool
    ) -> StickerGuideRing {
        let sweep = stop - start
        let steps = max(12, Int(abs(sweep) / (Float.pi / 18)))
        var samples: [CGPoint] = (0...steps).map { index in
            let angle = start + sweep * Float(index) / Float(steps)
            return point(cx + rx * cos(angle), cy + ry * sin(angle))
        }
        if closed {
            samples.append(point(cx, cy))
        }
        return StickerGuideRing(points: samples, closed: closed)
    }

    private static func svgRings(_ d: String) -> [StickerGuideRing] {
        let walker = GuideWalker()
        UIBezierPath(svgPath: d).cgPath.applyWithBlock { element in
            let values = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                walker.move(values[0])
            case .addLineToPoint:
                walker.line(values[0])
            case .addQuadCurveToPoint:
                walker.quad(control: values[0], end: values[1])
            case .addCurveToPoint:
                walker.cubic(control1: values[0], control2: values[1], end: values[2])
            case .closeSubpath:
                walker.close()
            @unknown default:
                break
            }
        }
        walker.finishOpen()
        return walker.rings
    }

    private static func points(from arguments: [Any]) -> [CGPoint] {
        arguments.compactMap { argument in
            if let pair = argument as? [Float], pair.count >= 2 {
                return point(pair[0], pair[1])
            }
            if let pair = argument as? [NSNumber], pair.count >= 2 {
                return point(pair[0].floatValue, pair[1].floatValue)
            }
            if let dictionary = argument as? [String: Any],
               let x = (dictionary["x"] as? NSNumber)?.floatValue,
               let y = (dictionary["y"] as? NSNumber)?.floatValue {
                return point(x, y)
            }
            return nil
        }
    }

    private static func float(_ arguments: [Any], _ index: Int) -> Float? {
        guard arguments.count > index else { return nil }
        return (arguments[index] as? NSNumber)?.floatValue
    }

    private static func point(_ x: Float, _ y: Float) -> CGPoint {
        CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
}

/// Flattens an unjittered SVG path into open and closed rings.
private final class GuideWalker {
    var rings: [StickerGuideRing] = []
    private var current: [CGPoint] = []

    func move(_ point: CGPoint) {
        finishOpen()
        current = [point]
    }

    func line(_ point: CGPoint) {
        current.append(point)
    }

    func quad(control: CGPoint, end: CGPoint) {
        guard let start = current.last else {
            line(end)
            return
        }
        let c1 = CGPoint(
            x: start.x + (2.0 / 3.0) * (control.x - start.x),
            y: start.y + (2.0 / 3.0) * (control.y - start.y)
        )
        let c2 = CGPoint(
            x: end.x + (2.0 / 3.0) * (control.x - end.x),
            y: end.y + (2.0 / 3.0) * (control.y - end.y)
        )
        cubic(control1: c1, control2: c2, end: end)
    }

    func cubic(control1: CGPoint, control2: CGPoint, end: CGPoint) {
        guard let start = current.last else {
            line(end)
            return
        }
        flatten(start, control1, control2, end, depth: 0)
    }

    func close() {
        guard current.count >= 3 else {
            current = []
            return
        }
        rings.append(StickerGuideRing(points: current, closed: true))
        current = []
    }

    func finishOpen() {
        if current.count >= 2 {
            rings.append(StickerGuideRing(points: current, closed: false))
        }
        current = []
    }

    private func flatten(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, depth: Int) {
        let dx = p3.x - p0.x
        let dy = p3.y - p0.y
        let lengthSquared = dx * dx + dy * dy
        func off(_ point: CGPoint) -> CGFloat {
            guard lengthSquared > 1e-6 else { return hypot(point.x - p0.x, point.y - p0.y) }
            let t = min(1, max(0, ((point.x - p0.x) * dx + (point.y - p0.y) * dy) / lengthSquared))
            return hypot(point.x - (p0.x + t * dx), point.y - (p0.y + t * dy))
        }
        if depth > 8 || (off(p1) <= 0.8 && off(p2) <= 0.8) {
            current.append(p3)
            return
        }
        let a = mid(p0, p1)
        let b = mid(p1, p2)
        let c = mid(p2, p3)
        let d = mid(a, b)
        let e = mid(b, c)
        let split = mid(d, e)
        flatten(p0, a, d, split, depth: depth + 1)
        flatten(split, e, c, p3, depth: depth + 1)
    }

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }
}
