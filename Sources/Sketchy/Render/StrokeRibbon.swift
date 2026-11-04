//
//  StrokeRibbon.swift
//  Sketchy
//
//  Quads along a centerline. Each quad carries one opacity so a mask can
//  paint the stroke without stacking alpha where segments meet.
//

import CoreGraphics
import SwiftUI

/// One filled piece of a stroke, with the opacity it should contribute.
struct RibbonPiece: Equatable {
    var path: SwiftUI.Path
    var opacity: CGFloat
    var t: CGFloat
    /// Even-odd fill. Watercolor uses this so the rim can cut out its core.
    var evenOdd: Bool = false
}

/// Builds non-overlapping quads (plus end caps) from centerline samples.
///
/// Neighbouring quads share an edge. They are painted as opaque gray in a
/// mask, so that shared edge antialiases into a blend instead of a dark seam.
enum StrokeRibbon {
    /// Geometry at one sample: half the stroke width, a sideways shift, and opacity.
    struct SampleGeometry {
        var halfWidth: CGFloat
        var shift: CGFloat
        var opacity: CGFloat
    }

    /// Quads between consecutive samples, then caps on an open stroke.
    ///
    /// - Parameters:
    ///   - samples: Centerline in destination points. At least two.
    ///   - isClosed: Closed contours skip caps. The samples already include the join.
    ///   - cap: End style used on an open stroke.
    ///   - geometry: Width, shift, and opacity at a sample.
    static func pieces(
        samples: [StrokeCenterSample],
        isClosed: Bool,
        cap: BrushCap,
        geometry: (StrokeCenterSample) -> SampleGeometry
    ) -> [RibbonPiece] {
        guard samples.count >= 2 else { return [] }
        var pieces: [RibbonPiece] = []
        pieces.reserveCapacity(samples.count + 2)

        for index in 0..<(samples.count - 1) {
            let start = samples[index]
            let end = samples[index + 1]
            let startGeo = geometry(start)
            let endGeo = geometry(end)
            if startGeo.halfWidth < 0.04 && endGeo.halfWidth < 0.04 { continue }
            let opacity = min(1, max(0, (startGeo.opacity + endGeo.opacity) * 0.5))
            if opacity <= 0.001 { continue }
            let leftStart = point(start, startGeo, side: 1)
            let rightStart = point(start, startGeo, side: -1)
            let leftEnd = point(end, endGeo, side: 1)
            let rightEnd = point(end, endGeo, side: -1)
            var path = SwiftUI.Path()
            path.move(to: leftStart)
            path.addLine(to: leftEnd)
            path.addLine(to: rightEnd)
            path.addLine(to: rightStart)
            path.closeSubpath()
            pieces.append(RibbonPiece(path: path, opacity: opacity, t: (start.t + end.t) * 0.5))
        }

        if !isClosed {
            pieces.append(contentsOf: caps(samples: samples, cap: cap, geometry: geometry))
        }
        return pieces
    }

    /// A point on one side of the shifted centre. `side` is 1 or -1.
    private static func point(
        _ sample: StrokeCenterSample,
        _ geometry: SampleGeometry,
        side: CGFloat
    ) -> CGPoint {
        let normal = sample.tangent + .pi / 2
        let along = cos(normal)
        let across = sin(normal)
        let centerX = sample.point.x + along * geometry.shift
        let centerY = sample.point.y + across * geometry.shift
        return CGPoint(
            x: centerX + along * geometry.halfWidth * side,
            y: centerY + across * geometry.halfWidth * side
        )
    }

    private static func caps(
        samples: [StrokeCenterSample],
        cap: BrushCap,
        geometry: (StrokeCenterSample) -> SampleGeometry
    ) -> [RibbonPiece] {
        guard cap != .butt, let first = samples.first, let last = samples.last else { return [] }
        return [capPiece(first, outward: first.tangent + .pi, cap: cap, geometry: geometry),
                capPiece(last, outward: last.tangent, cap: cap, geometry: geometry)]
            .compactMap { $0 }
    }

    private static func capPiece(
        _ sample: StrokeCenterSample,
        outward: CGFloat,
        cap: BrushCap,
        geometry: (StrokeCenterSample) -> SampleGeometry
    ) -> RibbonPiece? {
        let geo = geometry(sample)
        guard geo.halfWidth >= 0.04 else { return nil }
        let opacity = min(1, max(0, geo.opacity))
        guard opacity > 0.001 else { return nil }
        let normal = sample.tangent + .pi / 2
        let center = CGPoint(
            x: sample.point.x + cos(normal) * geo.shift,
            y: sample.point.y + sin(normal) * geo.shift
        )
        var path = SwiftUI.Path()
        switch cap {
        case .butt:
            return nil
        case .round:
            path.addEllipse(in: CGRect(
                x: center.x - geo.halfWidth,
                y: center.y - geo.halfWidth,
                width: geo.halfWidth * 2,
                height: geo.halfWidth * 2
            ))
        case .square:
            let left = point(sample, geo, side: 1)
            let right = point(sample, geo, side: -1)
            let extendX = cos(outward) * geo.halfWidth
            let extendY = sin(outward) * geo.halfWidth
            path.move(to: left)
            path.addLine(to: CGPoint(x: left.x + extendX, y: left.y + extendY))
            path.addLine(to: CGPoint(x: right.x + extendX, y: right.y + extendY))
            path.addLine(to: right)
            path.closeSubpath()
        }
        return RibbonPiece(path: path, opacity: opacity, t: sample.t)
    }
}

/// Variable-opacity outline commands for every path set in one drawing.
///
/// The quads share one mask group. They are drawn faintest first, so an
/// overlap keeps the higher opacity instead of adding the two alphas.
enum OpacityRibbon {
    static func commands(
        sets: [[Operation]],
        transform: CGAffineTransform,
        baseWidth: CGFloat,
        brush: BrushProfile,
        opacityProfile: OpacityProfile,
        strokeOpacity: CGFloat,
        color: Color,
        nextGroup: inout Int
    ) -> [RoughRenderCommand] {
        guard baseWidth >= 0.2, strokeOpacity > 0 else { return [] }
        var pieces: [RibbonPiece] = []
        for operations in sets {
            for line in StrokeToFillConverter.centerlines(operations: operations, transform: transform) {
                let widthBrush = line.isClosed ? brush.withUniformThickness() : brush
                let opacityAt = blendedOpacity(
                    closed: line.isClosed,
                    profile: opacityProfile,
                    strokeOpacity: strokeOpacity
                )
                pieces.append(contentsOf: StrokeRibbon.pieces(
                    samples: line.samples,
                    isClosed: line.isClosed,
                    cap: brush.cap,
                    geometry: { sample in
                        let multiplier = widthBrush.thicknessProfile.multiplier(at: sample.t)
                        let width = widthBrush.tip.effectiveWidth(
                            baseWidth: baseWidth * multiplier,
                            strokeAngle: sample.tangent
                        )
                        return StrokeRibbon.SampleGeometry(
                            halfWidth: max(0, width / 2),
                            shift: 0,
                            opacity: opacityAt(sample.t)
                        )
                    }
                ))
            }
        }
        return maskCommands(pieces.sorted { $0.opacity < $1.opacity }, color: color, blur: 0, nextGroup: &nextGroup)
    }

    /// Opacity along one subpath, multiplied by `strokeOpacity`.
    ///
    /// Closed contours blend toward the value at `t = 0` so the join matches.
    private static func blendedOpacity(
        closed: Bool,
        profile: OpacityProfile,
        strokeOpacity: CGFloat
    ) -> (CGFloat) -> CGFloat {
        let join = profile.value(at: 0, periodic: true) * strokeOpacity
        return { t in
            let raw = profile.value(at: t, periodic: closed) * strokeOpacity
            let blended = closed ? seamBlend(value: raw, toward: join, t: t, window: 0.06) : raw
            return min(1, max(0, blended))
        }
    }
}

/// Fills each piece with source-over. Overlaps darken, which is the glaze for watercolor.
///
/// Variable opacity does not use this. It keeps `maskCommands`, so joins stay even.
func glazeCommands(
    _ pieces: [RibbonPiece],
    color: Color,
    clip: SwiftUI.Path? = nil,
    fillRule: RoughFillRule = .winding
) -> [RoughRenderCommand] {
    pieces.compactMap { piece in
        let opacity = min(1, max(0, piece.opacity))
        guard opacity > 0.004 else { return nil }
        return RoughRenderCommand(
            path: piece.path,
            style: .fill(color.opacity(Double(opacity))),
            clipPath: clip,
            fillRule: piece.evenOdd ? .evenOdd : fillRule
        )
    }
}

/// Appends one mask group. Empty and fully clear pieces are dropped.
func maskCommands(
    _ pieces: [RibbonPiece],
    color: Color,
    blur: CGFloat,
    clip: SwiftUI.Path? = nil,
    inverseClip: Bool = false,
    nextGroup: inout Int
) -> [RoughRenderCommand] {
    let visible = pieces.filter { $0.opacity > 0.004 }
    guard !visible.isEmpty else { return [] }
    let group = nextGroup
    nextGroup += 1
    return visible.map { piece in
        RoughRenderCommand(
            path: piece.path,
            style: .fill(color),
            clipPath: clip,
            inverseClip: inverseClip,
            fillRule: .winding,
            opacityMaskGroup: group,
            maskOpacity: min(1, piece.opacity),
            opacityMaskBlur: blur
        )
    }
}
