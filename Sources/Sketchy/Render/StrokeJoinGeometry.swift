//
//  StrokeJoinGeometry.swift
//  Sketchy
//
//  Created by Seth Stradling on 06/11/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Joins for offset stroke outlines. CoreGraphics draws miter, round, and
//  bevel. Curved bevel, and every join on a variable-width ribbon, is built here.
//

import SwiftUI
import CoreGraphics

/// One step along an offset side of a stroke.
enum StrokeSideStep {
    case line(CGPoint)
    case quad(to: CGPoint, control: CGPoint)
    case arc(
        center: CGPoint,
        radius: CGFloat,
        start: CGFloat,
        end: CGFloat,
        clockwise: Bool,
        endPoint: CGPoint
    )

    var endPoint: CGPoint {
        switch self {
        case .line(let point), .quad(to: let point, control: _), .arc(_, _, _, _, _, let point):
            return point
        }
    }
}

/// Offset-corner joins shared by `StrokeToFillConverter` and `NativeStrokeOutline`.
enum StrokeJoinGeometry {
    /// Turn, in radians, above which a segment joint is a real corner.
    ///
    /// Smooth cubics, including the default continuous outlines, stay under this
    /// at their segment knots. A polygon corner is well above it.
    static let cornerTurnThreshold: CGFloat = 0.18

    /// Points to append on each offset side, from just after the incoming
    /// offset through the outgoing offset. Empty when the turn is too small.
    static func sidePolylines(
        vertex: CGPoint,
        incomingTangent: CGFloat,
        outgoingTangent: CGFloat,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        join: BrushJoin,
        miterLimit: CGFloat
    ) -> (left: [CGPoint], right: [CGPoint]) {
        let incomingLeft = offset(vertex, incomingTangent, max(0, incomingHalf), 1)
        let incomingRight = offset(vertex, incomingTangent, max(0, incomingHalf), -1)
        var left: [StrokeSideStep] = []
        var right: [StrokeSideStep] = []
        appendCorner(
            vertex: vertex,
            incomingTangent: incomingTangent,
            outgoingTangent: outgoingTangent,
            incomingHalf: incomingHalf,
            outgoingHalf: outgoingHalf,
            join: join,
            miterLimit: miterLimit,
            left: &left,
            right: &right
        )
        return (
            [incomingLeft] + flatten(left, start: incomingLeft),
            [incomingRight] + flatten(right, start: incomingRight)
        )
    }

    /// Appends the outer join and the inner connection.
    ///
    /// The contours already end on the incoming offsets. New steps run from
    /// those points to the outgoing offsets at `vertex`.
    static func appendCorner(
        vertex: CGPoint,
        incomingTangent: CGFloat,
        outgoingTangent: CGFloat,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        join: BrushJoin,
        miterLimit: CGFloat,
        left: inout [StrokeSideStep],
        right: inout [StrokeSideStep]
    ) {
        let turn = signedAngleDelta(incomingTangent, outgoingTangent)
        guard abs(turn) >= 0.01 else { return }
        let incomingHalf = max(0, incomingHalf)
        let outgoingHalf = max(0, outgoingHalf)
        guard incomingHalf > 0.05 || outgoingHalf > 0.05 else { return }

        // A positive turn is counterclockwise. The outer side is then the right offset.
        let outerSign: CGFloat = turn > 0 ? -1 : 1
        let incomingOuter = offset(vertex, incomingTangent, incomingHalf, outerSign)
        let outgoingOuter = offset(vertex, outgoingTangent, outgoingHalf, outerSign)
        let incomingInner = offset(vertex, incomingTangent, incomingHalf, -outerSign)
        let outgoingInner = offset(vertex, outgoingTangent, outgoingHalf, -outerSign)

        var outerSteps: [StrokeSideStep] = []
        appendOuter(
            incoming: incomingOuter,
            outgoing: outgoingOuter,
            vertex: vertex,
            incomingTangent: incomingTangent,
            outgoingTangent: outgoingTangent,
            incomingHalf: incomingHalf,
            outgoingHalf: outgoingHalf,
            turn: turn,
            join: join,
            miterLimit: max(1, miterLimit),
            to: &outerSteps
        )
        var innerSteps: [StrokeSideStep] = []
        appendInner(
            incoming: incomingInner,
            outgoing: outgoingInner,
            vertex: vertex,
            incomingTangent: incomingTangent,
            outgoingTangent: outgoingTangent,
            incomingHalf: incomingHalf,
            outgoingHalf: outgoingHalf,
            to: &innerSteps
        )

        if outerSign > 0 {
            left.append(contentsOf: outerSteps)
            right.append(contentsOf: innerSteps)
        } else {
            right.append(contentsOf: outerSteps)
            left.append(contentsOf: innerSteps)
        }
    }

    static func flatten(_ steps: [StrokeSideStep], start: CGPoint) -> [CGPoint] {
        var cursor = start
        var points: [CGPoint] = []
        for step in steps {
            switch step {
            case .line(let point):
                points.append(point)
                cursor = point
            case .quad(let to, let control):
                for index in 1...8 {
                    let t = CGFloat(index) / 8
                    let u = 1 - t
                    points.append(CGPoint(
                        x: u * u * cursor.x + 2 * u * t * control.x + t * t * to.x,
                        y: u * u * cursor.y + 2 * u * t * control.y + t * t * to.y
                    ))
                }
                cursor = to
            case .arc(let center, let radius, let startAngle, let endAngle, let clockwise, let endPoint):
                var sweep = endAngle - startAngle
                if clockwise {
                    if sweep > 0 { sweep -= .pi * 2 }
                } else if sweep < 0 {
                    sweep += .pi * 2
                }
                for index in 1...8 {
                    let angle = startAngle + sweep * CGFloat(index) / 8
                    points.append(CGPoint(
                        x: center.x + cos(angle) * radius,
                        y: center.y + sin(angle) * radius
                    ))
                }
                if let last = points.last, hypot(last.x - endPoint.x, last.y - endPoint.y) > 0.75 {
                    points.append(endPoint)
                }
                cursor = endPoint
            }
        }
        return points
    }

    static func replay(_ steps: ArraySlice<StrokeSideStep>, into path: inout SwiftUI.Path) {
        for step in steps {
            switch step {
            case .line(let point):
                path.addLine(to: point)
            case .quad(let point, let control):
                path.addQuadCurve(to: point, control: control)
            case .arc(let center, let radius, let start, let end, let clockwise, _):
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .radians(start),
                    endAngle: .radians(end),
                    clockwise: clockwise
                )
            }
        }
    }

    /// Walks a contour from its end back to its start. The path is already at the end point.
    static func replayReversed(_ steps: [StrokeSideStep], into path: inout SwiftUI.Path) {
        guard steps.count >= 2 else { return }
        for index in stride(from: steps.count - 1, through: 1, by: -1) {
            let start = steps[index - 1].endPoint
            switch steps[index] {
            case .line:
                path.addLine(to: start)
            case .quad(_, let control):
                path.addQuadCurve(to: start, control: control)
            case .arc(let center, let radius, let startAngle, let endAngle, let clockwise, _):
                path.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .radians(endAngle),
                    endAngle: .radians(startAngle),
                    clockwise: !clockwise
                )
            }
        }
    }

    /// Fills a constructed outline when CoreGraphics cannot draw the join.
    static func drawUniformStroke(
        path: SwiftUI.Path,
        color: Color,
        lineWidth: CGFloat,
        cap: BrushCap,
        join: BrushJoin,
        miterLimit: CGFloat,
        in context: inout GraphicsContext
    ) {
        if join.requiresCustomOutline {
            // Each subpath is filled on its own. A rough stroke is often two
            // passes in one path; even-odd across both would cancel the overlap.
            for subpath in subpaths(of: path) {
                let outline = NativeStrokeOutline.path(
                    from: subpath,
                    width: lineWidth,
                    cap: cap,
                    join: join,
                    miterLimit: miterLimit
                )
                context.fill(
                    outline,
                    with: .color(color),
                    style: SwiftUI.FillStyle(eoFill: false)
                )
            }
            return
        }
        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(
                lineWidth: lineWidth,
                lineCap: cap.cgLineCap,
                lineJoin: join.cgLineJoin,
                miterLimit: miterLimit
            )
        )
    }

    private static func subpaths(of path: SwiftUI.Path) -> [SwiftUI.Path] {
        var result: [SwiftUI.Path] = []
        var current = SwiftUI.Path()
        var hasPoint = false
        path.forEach { element in
            switch element {
            case .move(let point):
                if hasPoint {
                    result.append(current)
                    current = SwiftUI.Path()
                    hasPoint = false
                }
                current.move(to: point)
                hasPoint = true
            case .line(let point):
                current.addLine(to: point)
                hasPoint = true
            case .quadCurve(let point, let control):
                current.addQuadCurve(to: point, control: control)
                hasPoint = true
            case .curve(let point, let control1, let control2):
                current.addCurve(to: point, control1: control1, control2: control2)
                hasPoint = true
            case .closeSubpath:
                current.closeSubpath()
            }
        }
        if hasPoint {
            result.append(current)
        }
        return result
    }

    // MARK: - Outer join

    private static func appendOuter(
        incoming: CGPoint,
        outgoing: CGPoint,
        vertex: CGPoint,
        incomingTangent: CGFloat,
        outgoingTangent: CGFloat,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        turn: CGFloat,
        join: BrushJoin,
        miterLimit: CGFloat,
        to steps: inout [StrokeSideStep]
    ) {
        switch join {
        case .bevel:
            steps.append(.line(outgoing))
        case .miter:
            if let tip = acceptedMiter(
                incoming: incoming,
                outgoing: outgoing,
                vertex: vertex,
                incomingTangent: incomingTangent,
                outgoingTangent: outgoingTangent,
                incomingHalf: incomingHalf,
                outgoingHalf: outgoingHalf,
                turn: turn,
                miterLimit: miterLimit
            ) {
                steps.append(.line(tip))
            }
            steps.append(.line(outgoing))
        case .round:
            appendRound(
                incoming: incoming,
                outgoing: outgoing,
                vertex: vertex,
                incomingHalf: incomingHalf,
                outgoingHalf: outgoingHalf,
                to: &steps
            )
        case .curvedBevel(let bulge):
            appendCurvedBevel(
                incoming: incoming,
                outgoing: outgoing,
                vertex: vertex,
                incomingTangent: incomingTangent,
                outgoingTangent: outgoingTangent,
                incomingHalf: incomingHalf,
                outgoingHalf: outgoingHalf,
                bulge: min(1, max(0, bulge)),
                to: &steps
            )
        }
    }

    private static func appendRound(
        incoming: CGPoint,
        outgoing: CGPoint,
        vertex: CGPoint,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        to steps: inout [StrokeSideStep]
    ) {
        let radiusIn = hypot(incoming.x - vertex.x, incoming.y - vertex.y)
        let radiusOut = hypot(outgoing.x - vertex.x, outgoing.y - vertex.y)
        let average = (radiusIn + radiusOut) / 2
        guard average > 0.05 else {
            steps.append(.line(outgoing))
            return
        }
        if radiusIn > 0.05, abs(radiusIn - radiusOut) / max(radiusIn, 0.001) < 0.15 {
            let start = atan2(incoming.y - vertex.y, incoming.x - vertex.x)
            let end = atan2(outgoing.y - vertex.y, outgoing.x - vertex.x)
            let outward = bisectorPoint(vertex: vertex, incoming: incoming, outgoing: outgoing, radius: radiusIn)
            let clockwise = arcShouldBeClockwise(center: vertex, radius: radiusIn, start: start, end: end, toward: outward)
            let arcEnd = CGPoint(
                x: vertex.x + cos(end) * radiusIn,
                y: vertex.y + sin(end) * radiusIn
            )
            steps.append(.arc(
                center: vertex,
                radius: radiusIn,
                start: start,
                end: end,
                clockwise: clockwise,
                endPoint: arcEnd
            ))
            if hypot(arcEnd.x - outgoing.x, arcEnd.y - outgoing.y) > 0.75 {
                steps.append(.line(outgoing))
            }
            return
        }
        let chordMid = midpoint(incoming, outgoing)
        let aim = bisectorPoint(vertex: vertex, incoming: incoming, outgoing: outgoing, radius: average)
        let control = CGPoint(x: 2 * aim.x - chordMid.x, y: 2 * aim.y - chordMid.y)
        steps.append(.quad(to: outgoing, control: control))
    }

    private static func appendCurvedBevel(
        incoming: CGPoint,
        outgoing: CGPoint,
        vertex: CGPoint,
        incomingTangent: CGFloat,
        outgoingTangent: CGFloat,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        bulge: CGFloat,
        to steps: inout [StrokeSideStep]
    ) {
        guard bulge > 0.001 else {
            steps.append(.line(outgoing))
            return
        }
        let chordMid = midpoint(incoming, outgoing)
        let miter = lineIntersection(
            origin: incoming,
            direction: unit(incomingTangent),
            origin: outgoing,
            direction: unit(outgoingTangent)
        )
        let aim = miter ?? bisectorPoint(
            vertex: vertex,
            incoming: incoming,
            outgoing: outgoing,
            radius: incomingHalf + outgoingHalf
        )
        var delta = CGPoint(x: aim.x - chordMid.x, y: aim.y - chordMid.y)
        let length = hypot(delta.x, delta.y)
        let cap = max(incomingHalf, outgoingHalf) * 4
        if length > cap, length > 0 {
            delta.x *= cap / length
            delta.y *= cap / length
        }
        let control = CGPoint(
            x: chordMid.x + delta.x * bulge,
            y: chordMid.y + delta.y * bulge
        )
        steps.append(.quad(to: outgoing, control: control))
    }

    /// Outer miter tip when it stays inside the limit and on the outer side.
    private static func acceptedMiter(
        incoming: CGPoint,
        outgoing: CGPoint,
        vertex: CGPoint,
        incomingTangent: CGFloat,
        outgoingTangent: CGFloat,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        turn: CGFloat,
        miterLimit: CGFloat
    ) -> CGPoint? {
        let wedge = CGFloat.pi - abs(turn)
        let formula = 1 / max(sin(wedge / 2), 0.001)
        if formula > miterLimit { return nil }
        guard let tip = lineIntersection(
            origin: incoming,
            direction: unit(incomingTangent),
            origin: outgoing,
            direction: unit(outgoingTangent)
        ) else { return nil }
        let toTip = CGPoint(x: tip.x - vertex.x, y: tip.y - vertex.y)
        let toOuter = CGPoint(x: incoming.x - vertex.x, y: incoming.y - vertex.y)
        if toTip.x * toOuter.x + toTip.y * toOuter.y <= 0 { return nil }
        let averageWidth = max(incomingHalf + outgoingHalf, 0.001)
        let inner = lineIntersection(
            origin: offset(vertex, incomingTangent, incomingHalf, turn > 0 ? 1 : -1),
            direction: unit(incomingTangent),
            origin: offset(vertex, outgoingTangent, outgoingHalf, turn > 0 ? 1 : -1),
            direction: unit(outgoingTangent)
        ) ?? vertex
        let miterLength = hypot(tip.x - inner.x, tip.y - inner.y)
        if miterLength / averageWidth > miterLimit { return nil }
        return tip
    }

    // MARK: - Inner corner

    private static func appendInner(
        incoming: CGPoint,
        outgoing: CGPoint,
        vertex: CGPoint,
        incomingTangent: CGFloat,
        outgoingTangent: CGFloat,
        incomingHalf: CGFloat,
        outgoingHalf: CGFloat,
        to steps: inout [StrokeSideStep]
    ) {
        let limit = max(incomingHalf, outgoingHalf) * 4 + 1
        if let hit = lineIntersection(
            origin: incoming,
            direction: unit(incomingTangent),
            origin: outgoing,
            direction: unit(outgoingTangent)
        ), hypot(hit.x - vertex.x, hit.y - vertex.y) <= limit {
            let direction = unit(incomingTangent)
            let forward = (hit.x - incoming.x) * direction.x + (hit.y - incoming.y) * direction.y
            if forward > -0.5 {
                steps.append(.line(hit))
            }
        }
        steps.append(.line(outgoing))
    }

    // MARK: - Math

    static func signedAngleDelta(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
        var delta = to - from
        let turn = CGFloat.pi * 2
        while delta > .pi { delta -= turn }
        while delta <= -.pi { delta += turn }
        return delta
    }

    private static func offset(_ point: CGPoint, _ tangent: CGFloat, _ half: CGFloat, _ sign: CGFloat) -> CGPoint {
        let normal = tangent + .pi / 2
        return CGPoint(
            x: point.x + cos(normal) * half * sign,
            y: point.y + sin(normal) * half * sign
        )
    }

    private static func unit(_ angle: CGFloat) -> CGPoint {
        CGPoint(x: cos(angle), y: sin(angle))
    }

    private static func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    private static func bisectorPoint(
        vertex: CGPoint,
        incoming: CGPoint,
        outgoing: CGPoint,
        radius: CGFloat
    ) -> CGPoint {
        var direction = CGPoint(
            x: (incoming.x - vertex.x) + (outgoing.x - vertex.x),
            y: (incoming.y - vertex.y) + (outgoing.y - vertex.y)
        )
        let length = hypot(direction.x, direction.y)
        if length < 0.001 {
            direction = CGPoint(x: incoming.x - vertex.x, y: incoming.y - vertex.y)
        }
        let scale = hypot(direction.x, direction.y)
        guard scale > 0.001 else { return incoming }
        return CGPoint(
            x: vertex.x + direction.x / scale * radius,
            y: vertex.y + direction.y / scale * radius
        )
    }

    private static func lineIntersection(
        origin a: CGPoint,
        direction da: CGPoint,
        origin b: CGPoint,
        direction db: CGPoint
    ) -> CGPoint? {
        let cross = da.x * db.y - da.y * db.x
        guard abs(cross) > 1e-5 else { return nil }
        let dx = b.x - a.x
        let dy = b.y - a.y
        let t = (dx * db.y - dy * db.x) / cross
        return CGPoint(x: a.x + da.x * t, y: a.y + da.y * t)
    }

    /// Picks the sweep whose midpoint lies closer to `toward`.
    private static func arcShouldBeClockwise(
        center: CGPoint,
        radius: CGFloat,
        start: CGFloat,
        end: CGFloat,
        toward: CGPoint
    ) -> Bool {
        var ccw = end - start
        if ccw < 0 { ccw += .pi * 2 }
        var cw = start - end
        if cw < 0 { cw += .pi * 2 }
        let ccwMid = start + ccw / 2
        let cwMid = start - cw / 2
        let ccwPoint = CGPoint(x: center.x + cos(ccwMid) * radius, y: center.y + sin(ccwMid) * radius)
        let cwPoint = CGPoint(x: center.x + cos(cwMid) * radius, y: center.y + sin(cwMid) * radius)
        let ccwDistance = hypot(ccwPoint.x - toward.x, ccwPoint.y - toward.y)
        let cwDistance = hypot(cwPoint.x - toward.x, cwPoint.y - toward.y)
        return cwDistance < ccwDistance
    }
}

/// Paints one uniform stroke, using a filled outline for joins CoreGraphics cannot draw.
enum UniformStrokePaint {
    static func draw(
        path: SwiftUI.Path,
        color: Color,
        lineWidth: CGFloat,
        cap: BrushCap,
        join: BrushJoin,
        miterLimit: CGFloat,
        in context: inout GraphicsContext
    ) {
        StrokeJoinGeometry.drawUniformStroke(
            path: path,
            color: color,
            lineWidth: lineWidth,
            cap: cap,
            join: join,
            miterLimit: miterLimit,
            in: &context
        )
    }
}
