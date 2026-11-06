//
//  StickerBackingBuilder.swift
//  Sketchy
//
//  Builds the solid paper sheet drawn behind a sketch.
//
//  Route: SwiftUIRenderer.commands(for:options:in:) calls
//  StickerBackingBuilder.commands when Options.stickerBacking is set.
//  The outline operations are flattened, the duplicate rough pass is dropped,
//  the contour is smoothed, then closed rings are offset outward. Torn edges
//  chop that offset. The resulting fill is inserted ahead of the existing
//  stroke and fill commands.
//

import CoreGraphics
import SwiftUI
import UIKit

/// Paper geometry and render commands for `StickerBacking`.
enum StickerBackingBuilder {

    /// One contour after smoothing, before or after the outward offset.
    struct Centerline {
        var points: [CGPoint]
        var closed: Bool
        /// Outline before smoothness moves it toward the silhouette.
        var source: [CGPoint] = []
    }

    /// Smoothed outline centerlines. Width does not move these points.
    /// Torn chops are applied later, on the offset edge.
    static func centerlines(
        for drawing: Drawing,
        options: Options,
        backing: StickerBacking,
        transform: CGAffineTransform?
    ) -> [Centerline] {
        guard backing.width > 0 else { return [] }
        let unique = dropDuplicatePasses(flatten(drawing: drawing, transform: transform))
        let guides = transformedGuides(drawing.stickerGuide, transform: transform)
        let amplitude = noiseAmplitude(options)
        return unique.map { piece in
            let aimed = aim(
                piece.points,
                closed: piece.closed,
                guides: guides,
                smoothness: backing.smoothness,
                amplitude: amplitude
            )
            let spaced = resample(aimed, closed: piece.closed, spacing: 2.5)
            return Centerline(points: spaced, closed: piece.closed, source: piece.points)
        }
    }

    /// Commands painted before the sketch. Empty when the backing is off.
    static func commands(
        for drawing: Drawing,
        options: Options,
        backing: StickerBacking,
        transform: CGAffineTransform?
    ) -> [RoughRenderCommand] {
        let lines = centerlines(
            for: drawing,
            options: options,
            backing: backing,
            transform: transform
        )
        guard !lines.isEmpty else { return [] }

        let strokeWidth = drawing.shape == "path"
            ? CGFloat(options.effectiveSVGStrokeWidth)
            : CGFloat(options.strokeWidth)
        let outward = backing.width + max(0, strokeWidth) / 2
        guard outward > 0 else { return [] }

        let paper = Color(backing.color)
        let finish = paperFinish(backing, seed: options.seed ?? 0xA11C_E571_C4E0)
        var commands: [RoughRenderCommand] = []

        let closed = lines.filter(\.closed)
        let open = lines.filter { !$0.closed }

        if !closed.isEmpty {
            commands.append(contentsOf: closedCommands(
                closed,
                outward: outward,
                finish: finish,
                texture: backing.texture,
                seed: options.seed,
                color: paper,
                uiColor: backing.color
            ))
        }

        let ribbon = max(0, strokeWidth) + backing.width * 2
        if ribbon > 0 {
            for (index, line) in open.enumerated() where line.points.count >= 2 {
                var points = line.points
                if case .torn(let tear) = finish {
                    points = chop(
                        points,
                        closed: false,
                        depth: tear.depth,
                        length: tear.length,
                        jaggedness: tear.jaggedness,
                        seed: tear.seed &+ UInt64(index) &+ 0x0F1E
                    )
                } else if case .continuous(let radius) = finish {
                    points = continuousOutline(points, closed: false, radius: radius)
                }
                let torn = if case .torn = finish { true } else { false }
                let continuous = if case .continuous = finish { true } else { false }
                let center = contourPath(
                    points,
                    closed: false,
                    curved: !torn,
                    continuous: continuous
                )
                commands.append(RoughRenderCommand(
                    path: center,
                    style: .stroke(paper, lineWidth: ribbon),
                    cap: .round,
                    join: torn ? .bevel : .round,
                    miterLimit: 4
                ))
                if let texture = backing.texture, texture.amount > 0.01 {
                    let clip = NativeStrokeOutline.path(
                        from: center,
                        width: ribbon,
                        cap: .round,
                        join: torn ? .bevel : .round,
                        miterLimit: 4
                    )
                    commands.append(contentsOf: textureCommands(
                        clip: clip,
                        texture: texture,
                        seed: options.seed,
                        base: backing.color
                    ))
                }
            }
        }

        return commands
    }

    // MARK: - Closed sheet

    private struct TearSettings {
        var depth: CGFloat
        var length: CGFloat
        var jaggedness: CGFloat
        var seed: UInt64
    }

    /// How the paper edge is finished after the offset.
    private enum PaperFinish {
        case corners
        case continuous(CGFloat)
        case torn(TearSettings)
    }

    private static func paperFinish(_ backing: StickerBacking, seed: UInt64) -> PaperFinish {
        switch backing.edge {
        case .smooth:
            return .corners
        case .fullySmooth(let radius):
            return .continuous(max(0, radius))
        case .torn(let tear):
            return .torn(TearSettings(
                depth: tear.resolvedDepth(width: backing.width),
                length: max(4, tear.length),
                jaggedness: min(1, max(0, tear.jaggedness)),
                seed: seed ^ 0x571C_4E5E_ED00
            ))
        }
    }

    /// Fills the offset rings. A ring that cannot be offset without crossing
    /// itself falls back, together with the other closed rings, to a round
    /// dilation so a hole and its outline stay one sheet.
    private static func closedCommands(
        _ lines: [Centerline],
        outward: CGFloat,
        finish: PaperFinish,
        texture: StickerTexture?,
        seed: UInt64?,
        color: Color,
        uiColor: UIColor
    ) -> [RoughRenderCommand] {
        let rings = lines.filter { $0.points.count >= 3 }
        guard !rings.isEmpty else { return [] }
        var offsets: [[CGPoint]] = []
        offsets.reserveCapacity(rings.count)
        var failed = false
        let continuous = if case .continuous = finish { true } else { false }
        let torn = if case .torn = finish { true } else { false }
        for (index, line) in rings.enumerated() {
            // Even nesting (outer shape, or an island in a hole) grows.
            // Odd nesting is a hole, so the ring shrinks and the cutout keeps a margin.
            let signed = nestingDepth(index, in: rings).isMultiple(of: 2) ? outward : -outward
            let coverageBase = line.source.count >= 3 ? line.source : line.points
            let coverage = offsetClosed(coverageBase, by: signed)
            var source = line.points
            if case .continuous(let radius) = finish {
                source = continuousOutline(source, closed: true, radius: radius)
            }
            guard var ring = offsetClosed(source, by: signed) else {
                failed = true
                break
            }
            switch finish {
            case .torn(let tear):
                ring = choppedOffset(
                    ring,
                    depth: tear.depth,
                    length: tear.length,
                    jaggedness: tear.jaggedness,
                    seed: tear.seed &+ UInt64(index)
                )
            case .continuous(let radius):
                // A short pass removes the offset's miter nubs without
                // pulling the margin back onto the ink.
                let polish = radius > 0 ? min(10, max(5, radius * 0.3)) : 7
                ring = continuousOutline(ring, closed: true, radius: polish)
                if let coverage {
                    ring = expandToCover(coverage, ring)
                }
            case .corners:
                break
            }
            offsets.append(ring)
        }

        if !failed, offsets.count == rings.count, !offsets.isEmpty {
            let paper = compoundPath(offsets, closed: true, curved: !torn, continuous: continuous)
            return sheetCommands(paper, color: color, uiColor: uiColor, texture: texture, seed: seed)
        }

        let sources = lines.map { line -> [CGPoint] in
            if case .continuous(let radius) = finish {
                return continuousOutline(line.points, closed: line.closed, radius: radius)
            }
            return line.points
        }
        let center = compoundPath(
            sources,
            closed: true,
            curved: !torn,
            continuous: continuous
        )
        let dilation = max(outward * 2, 0.5)
        var commands = [
            RoughRenderCommand(path: center, style: .fill(color), fillRule: .evenOdd),
            RoughRenderCommand(
                path: center,
                style: .stroke(color, lineWidth: dilation),
                cap: .round,
                join: .round,
                miterLimit: 1
            )
        ]
        // The round stroke supplies the margin. Grain clips to the interior
        // sheet; the margin stroke stays a flat color when offset failed.
        if let texture, texture.amount > 0.01 {
            commands.append(contentsOf: textureCommands(
                clip: center,
                texture: texture,
                seed: seed,
                base: uiColor
            ))
        }
        return commands
    }

    /// Flat color, then optional fibers clipped to the sheet.
    private static func sheetCommands(
        _ paper: SwiftUI.Path,
        color: Color,
        uiColor: UIColor,
        texture: StickerTexture?,
        seed: UInt64?
    ) -> [RoughRenderCommand] {
        var commands = [
            RoughRenderCommand(path: paper, style: .fill(color), fillRule: .evenOdd)
        ]
        if let texture, texture.amount > 0.01 {
            commands.append(contentsOf: textureCommands(
                clip: paper,
                texture: texture,
                seed: seed,
                base: uiColor
            ))
        }
        return commands
    }

    /// Chops `ring`, halving the depth until the ring stays simple.
    private static func choppedOffset(
        _ ring: [CGPoint],
        depth: CGFloat,
        length: CGFloat,
        jaggedness: CGFloat,
        seed: UInt64
    ) -> [CGPoint] {
        var attempt = depth
        var best = ring
        for _ in 0..<5 {
            let chopped = chop(
                ring,
                closed: true,
                depth: attempt,
                length: length,
                jaggedness: jaggedness,
                seed: seed
            )
            if !segmentsIntersect(chopped), signedArea(chopped) * signedArea(ring) > 0 {
                return chopped
            }
            best = chopped
            attempt *= 0.5
            if attempt < 0.75 {
                return ring
            }
        }
        return segmentsIntersect(best) ? ring : best
    }

    /// Short fibers inside `clip`. Even-odd clip keeps holes empty.
    private static func textureCommands(
        clip: SwiftUI.Path,
        texture: StickerTexture,
        seed: UInt64?,
        base: UIColor
    ) -> [RoughRenderCommand] {
        let bounds = clip.boundingRect
        guard bounds.width > 2, bounds.height > 2, texture.amount > 0.01 else { return [] }
        var spacing = texture.scale
        let budget: CGFloat = 1600
        while (bounds.width / spacing) * (bounds.height / spacing) > budget {
            spacing *= 1.2
        }
        let columns = max(1, Int(ceil(bounds.width / spacing)))
        let rows = max(1, Int(ceil(bounds.height / spacing)))
        let grainSeed = (texture.seed ?? seed ?? 0xB0A9_E5E1) ^ 0x9A9E_2
        var fibers = SwiftUI.Path()
        var specks = SwiftUI.Path()
        for row in 0..<rows {
            for column in 0..<columns {
                var rng = SplitMix64(seed: grainSeed &+ UInt64(row) &* 0x9E37_79B9 &+ UInt64(column) &* 0xBF58_476D)
                let chance = CGFloat.random(in: 0...1, using: &rng)
                guard chance < 0.35 + 0.65 * texture.amount else { continue }
                let origin = CGPoint(
                    x: bounds.minX + (CGFloat(column) + CGFloat.random(in: 0...1, using: &rng)) * spacing,
                    y: bounds.minY + (CGFloat(row) + CGFloat.random(in: 0...1, using: &rng)) * spacing
                )
                let along = CGFloat.random(in: -0.55...0.55, using: &rng)
                let cross = (row + column).isMultiple(of: 5)
                let angle = (cross ? CGFloat.pi / 2 : 0) + along
                let length = spacing * CGFloat.random(in: 0.55...1.35, using: &rng)
                let end = CGPoint(
                    x: origin.x + cos(angle) * length,
                    y: origin.y + sin(angle) * length
                )
                if cross {
                    specks.move(to: origin)
                    specks.addLine(to: end)
                } else {
                    fibers.move(to: origin)
                    fibers.addLine(to: end)
                }
            }
        }
        let ink = fiberColor(base, amount: texture.amount)
        let width = 0.55 + texture.amount * 0.7
        var commands: [RoughRenderCommand] = []
        if !fibers.isEmpty {
            commands.append(RoughRenderCommand(
                path: fibers,
                style: .stroke(ink, lineWidth: width),
                clipPath: clip,
                cap: .round,
                join: .round
            ))
        }
        if !specks.isEmpty {
            commands.append(RoughRenderCommand(
                path: specks,
                style: .stroke(ink.opacity(0.7), lineWidth: max(0.4, width * 0.65)),
                clipPath: clip,
                cap: .round,
                join: .round
            ))
        }
        return commands
    }

    /// A darker shade of the sheet so grain reads on white and on a tint.
    private static func fiberColor(_ base: UIColor, amount: CGFloat) -> Color {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        let resolved = base.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return Color(white: 0.45).opacity(0.7)
        }
        let contrast = 0.28 + 0.4 * amount
        func shade(_ channel: CGFloat) -> Double {
            Double(min(1, max(0, channel * (1 - contrast))))
        }
        return Color(red: shade(red), green: shade(green), blue: shade(blue))
            .opacity(Double(min(1, max(0.35, alpha))))
    }

    // MARK: - Outline extraction

    private static func flatten(drawing: Drawing, transform: CGAffineTransform?) -> [Centerline] {
        var source = SwiftUI.Path()
        for set in drawing.sets where set.type == .path {
            for operation in set.operations {
                source.add(operation: operation)
            }
        }
        guard !source.isEmpty else { return [] }
        let outline: CGPath
        if let transform {
            var affine = transform
            outline = source.cgPath.copy(using: &affine) ?? source.cgPath
        } else {
            outline = source.cgPath
        }
        return pieces(from: outline)
    }

    private static func pieces(from path: CGPath) -> [Centerline] {
        let walker = PathWalker()
        path.applyWithBlock { element in
            let points = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                walker.move(points[0])
            case .addLineToPoint:
                walker.line(points[0])
            case .addQuadCurveToPoint:
                walker.quad(control: points[0], end: points[1])
            case .addCurveToPoint:
                walker.cubic(control1: points[0], control2: points[1], end: points[2])
            case .closeSubpath:
                walker.close()
            @unknown default:
                break
            }
        }
        walker.finishOpen()
        return walker.pieces
    }

    /// Drops a later contour that retraces one already kept.
    ///
    /// Continuous shapes and SVG paths draw every contour twice. The second
    /// pass sits a few points off the first, so the mean nearest-point
    /// distance is small. A hole is farther away than that, and a second
    /// shape with a different center is not a match, so both stay.
    private static func dropDuplicatePasses(_ pieces: [Centerline]) -> [Centerline] {
        var kept: [Centerline] = []
        for piece in pieces {
            if kept.contains(where: { matches(piece, $0) }) {
                continue
            }
            kept.append(piece)
        }
        return kept
    }

    private static func matches(_ a: Centerline, _ b: Centerline) -> Bool {
        guard a.closed == b.closed, a.points.count >= 2, b.points.count >= 2 else { return false }
        let left = bounds(a.points)
        let right = bounds(b.points)
        let diagonal = max(
            hypot(left.width, left.height),
            hypot(right.width, right.height),
            1
        )
        let centerGap = hypot(left.midX - right.midX, left.midY - right.midY)
        guard centerGap < max(16, diagonal * 0.18) else { return false }
        return meanNearest(a.points, b.points) < max(10, diagonal * 0.07)
    }

    /// Average distance from each sample of `from` to the nearest point of `to`.
    private static func meanNearest(_ from: [CGPoint], _ to: [CGPoint]) -> CGFloat {
        guard !from.isEmpty, !to.isEmpty else { return .greatestFiniteMagnitude }
        let stride = max(1, from.count / 48)
        var total: CGFloat = 0
        var count: CGFloat = 0
        var index = 0
        while index < from.count {
            var best = CGFloat.greatestFiniteMagnitude
            for point in to {
                best = min(best, distance(from[index], point))
            }
            total += best
            count += 1
            index += stride
        }
        return count > 0 ? total / count : .greatestFiniteMagnitude
    }

    // MARK: - Smoothing

    private static func noiseAmplitude(_ options: Options) -> CGFloat {
        CGFloat(max(0, options.maxRandomnessOffset) * max(options.roughness, 0) * 1.5)
    }

    /// Blends each rough sample toward the nearest point on the input
    /// silhouette. `0` leaves the sketch. `1` sits on that silhouette.
    /// A shape with no guide is simplified instead, so fine wobble still recedes.
    private static func aim(
        _ points: [CGPoint],
        closed: Bool,
        guides: [StickerGuideRing],
        smoothness: CGFloat,
        amplitude: CGFloat
    ) -> [CGPoint] {
        let amount = min(1, max(0, smoothness))
        guard amount > 0.001 else { return points }
        if let guide = matchingGuide(for: points, in: guides) {
            return points.map { point in
                mix(point, closest(point, on: guide.points, closed: guide.closed), t: amount)
            }
        }
        return smooth(points, closed: closed, smoothness: amount, amplitude: amplitude)
    }

    private static func transformedGuides(
        _ guides: [StickerGuideRing]?,
        transform: CGAffineTransform?
    ) -> [StickerGuideRing] {
        guard let guides else { return [] }
        guard let transform else { return guides }
        return guides.map { guide in
            StickerGuideRing(
                points: guide.points.map { $0.applying(transform) },
                closed: guide.closed
            )
        }
    }

    private static func matchingGuide(
        for points: [CGPoint],
        in guides: [StickerGuideRing]
    ) -> StickerGuideRing? {
        let box = bounds(points)
        let diagonal = max(hypot(box.width, box.height), 1)
        var best: StickerGuideRing?
        var bestScore = CGFloat.greatestFiniteMagnitude
        for guide in guides where guide.points.count >= 2 {
            let score = meanNearest(points, guide.points)
            if score < bestScore {
                bestScore = score
                best = guide
            }
        }
        guard bestScore < max(28, diagonal * 0.22) else { return nil }
        return best
    }

    private static func closest(_ point: CGPoint, on ring: [CGPoint], closed: Bool) -> CGPoint {
        guard let first = ring.first else { return point }
        guard ring.count >= 2 else { return first }
        var best = first
        var bestDistance = CGFloat.greatestFiniteMagnitude
        let segments = closed ? ring.count : ring.count - 1
        for index in 0..<segments {
            let start = ring[index]
            let end = ring[(index + 1) % ring.count]
            let projected = projection(point, start, end)
            let span = distance(point, projected)
            if span < bestDistance {
                bestDistance = span
                best = projected
            }
        }
        return best
    }

    private static func projection(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-8 else { return start }
        let t = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return CGPoint(x: start.x + t * dx, y: start.y + t * dy)
    }

    private static func mix(_ a: CGPoint, _ b: CGPoint, t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// Removes wobble smaller than the sketch amplitude and keeps corners
    /// that stand farther off the chord than that. Used when a shape has no
    /// input silhouette to blend toward.
    private static func smooth(
        _ points: [CGPoint],
        closed: Bool,
        smoothness: CGFloat,
        amplitude: CGFloat
    ) -> [CGPoint] {
        let amount = min(1, max(0, smoothness))
        guard amount > 0.001, points.count >= 4 else { return points }
        let perimeter = length(of: points, closed: closed)
        guard perimeter > 8 else { return points }
        let epsilon = min(max(2.2, amplitude * 0.85) * amount, max(perimeter * 0.035, 2.2))
        guard epsilon > 0.6 else { return points }
        let simplified = simplify(points, closed: closed, epsilon: epsilon)
        let spaced = resample(simplified, closed: closed, spacing: 2.5)
        let sigma = min(1.2 + amount * 1.4, max(perimeter * 0.012, 1.2))
        guard spaced.count >= 4, sigma > 0.8 else { return simplified }
        return gaussian(spaced, closed: closed, sigma: sigma)
    }

    /// Douglas–Peucker. A closed ring is split at the point farthest from
    /// its centroid so the seam is a corner rather than the middle of an edge.
    private static func simplify(_ points: [CGPoint], closed: Bool, epsilon: CGFloat) -> [CGPoint] {
        var ring = clean(points, dropClosingDuplicate: true)
        guard ring.count >= 4 else { return points }
        if !closed {
            let open = rdp(ring, epsilon: epsilon)
            return open.count >= 2 ? open : points
        }
        let center = centroid(ring)
        let anchor = ring.indices.max { lhs, rhs in
            distance(ring[lhs], center) < distance(ring[rhs], center)
        } ?? 0
        ring = Array(ring[anchor...] + ring[..<anchor])
        var chain = ring
        chain.append(ring[0])
        var simplified = rdp(chain, epsilon: epsilon)
        if simplified.count >= 2, distance(simplified[0], simplified[simplified.count - 1]) <= epsilon {
            simplified.removeLast()
        }
        return simplified.count >= 3 ? simplified : points
    }

    private static func rdp(_ points: [CGPoint], epsilon: CGFloat) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        var keep = [Bool](repeating: false, count: points.count)
        keep[0] = true
        keep[points.count - 1] = true
        var stack = [(0, points.count - 1)]
        while let range = stack.popLast() {
            let start = range.0
            let end = range.1
            guard end > start + 1 else { continue }
            var maxDistance: CGFloat = 0
            var farthest = start
            for index in (start + 1)..<end {
                let span = distance(points[index], toSegment: points[start], points[end])
                if span > maxDistance {
                    maxDistance = span
                    farthest = index
                }
            }
            if maxDistance > epsilon, farthest != start, farthest != end {
                keep[farthest] = true
                stack.append((start, farthest))
                stack.append((farthest, end))
            }
        }
        return points.indices.compactMap { keep[$0] ? points[$0] : nil }
    }

    /// Removes polygon flats by blurring along the outline. The result is
    /// scaled back to the original average radius so the margin stays put.
    /// A self-crossing blur is retried with a shorter radius.
    private static func continuousOutline(
        _ points: [CGPoint],
        closed: Bool,
        radius: CGFloat
    ) -> [CGPoint] {
        let spacing: CGFloat = 1.6
        let sampled = resample(points, closed: closed, spacing: spacing)
        let ring = clean(sampled, dropClosingDuplicate: closed)
        guard ring.count >= 8 else { return points }
        let perimeter = length(of: ring, closed: closed)
        let automatic = max(16, perimeter * 0.055)
        var sigma = radius > 0 ? radius : automatic
        let originalArea = signedArea(ring)
        var best = ring
        for _ in 0..<4 {
            let blurred = gaussian(ring, closed: closed, sigma: max(4, sigma))
            let restored = restoreMeanRadius(blurred, matching: ring)
            let area = signedArea(restored)
            let simple = closed
                ? !segmentsIntersect(restored) && area * originalArea > 0
                : true
            if simple {
                return restored
            }
            best = restored
            sigma *= 0.55
            if sigma < 4 { break }
        }
        return best
    }

    /// Scales `shape` about its centroid until it contains `cover`.
    /// A uniform scale keeps the continuous tangent.
    private static func expandToCover(_ cover: [CGPoint], _ shape: [CGPoint]) -> [CGPoint] {
        let origin = centroid(shape)
        func scaled(_ factor: CGFloat) -> [CGPoint] {
            shape.map { point in
                CGPoint(
                    x: origin.x + (point.x - origin.x) * factor,
                    y: origin.y + (point.y - origin.y) * factor
                )
            }
        }
        func covers(_ ring: [CGPoint]) -> Bool {
            cover.allSatisfy { contains($0, polygon: ring) }
        }
        if covers(shape) { return shape }
        var low: CGFloat = 1
        var high: CGFloat = 1.06
        var guardScale: CGFloat = 1
        while high < 1.8 && !covers(scaled(high)) {
            low = high
            high += 0.06
            guardScale += 0.06
            if guardScale > 1.8 { break }
        }
        if !covers(scaled(high)) { return scaled(high) }
        for _ in 0..<8 {
            let mid = (low + high) * 0.5
            if covers(scaled(mid)) {
                high = mid
            } else {
                low = mid
            }
        }
        return scaled(high * 1.02)
    }

    /// Puts the blurred ring back at the source ring's average size.
    private static func restoreMeanRadius(_ points: [CGPoint], matching target: [CGPoint]) -> [CGPoint] {
        let origin = centroid(points)
        let before = meanRadius(target, around: centroid(target))
        let after = meanRadius(points, around: origin)
        guard after > 0.5, before > 0.5 else { return points }
        let scale = min(1.25, max(0.8, before / after))
        return points.map { point in
            CGPoint(
                x: origin.x + (point.x - origin.x) * scale,
                y: origin.y + (point.y - origin.y) * scale
            )
        }
    }

    private static func meanRadius(_ points: [CGPoint], around origin: CGPoint) -> CGFloat {
        guard !points.isEmpty else { return 0 }
        let total = points.reduce(CGFloat.zero) { partial, point in
            partial + hypot(point.x - origin.x, point.y - origin.y)
        }
        return total / CGFloat(points.count)
    }

    private static func gaussian(_ points: [CGPoint], closed: Bool, sigma: CGFloat) -> [CGPoint] {
        let radius = sigma * 3
        let count = points.count
        return (0..<count).map { index in
            var sum = CGPoint.zero
            var weight = 0.0
            func add(_ pointIndex: Int, _ distance: CGFloat) {
                let scale = exp(-0.5 * Double((distance / sigma) * (distance / sigma)))
                sum.x += points[pointIndex].x * scale
                sum.y += points[pointIndex].y * scale
                weight += scale
            }
            add(index, 0)
            accumulate(points, from: index, closed: closed, radius: radius, step: 1, add: add)
            accumulate(points, from: index, closed: closed, radius: radius, step: -1, add: add)
            guard weight > 0 else { return points[index] }
            return CGPoint(x: sum.x / weight, y: sum.y / weight)
        }
    }

    private static func accumulate(
        _ points: [CGPoint],
        from index: Int,
        closed: Bool,
        radius: CGFloat,
        step: Int,
        add: (Int, CGFloat) -> Void
    ) {
        let count = points.count
        var cursor = index
        var traveled: CGFloat = 0
        for _ in 0..<count {
            let next = cursor + step
            let wrapped: Int
            if closed {
                wrapped = (next % count + count) % count
                if wrapped == index { break }
            } else if next < 0 || next >= count {
                break
            } else {
                wrapped = next
            }
            let hop = distance(points[cursor], points[wrapped])
            if hop < 1e-4 { break }
            traveled += hop
            if traveled > radius { break }
            add(wrapped, traveled)
            cursor = wrapped
        }
    }

    // MARK: - Tear

    private static func chop(
        _ points: [CGPoint],
        closed: Bool,
        depth: CGFloat,
        length: CGFloat,
        jaggedness: CGFloat,
        seed: UInt64
    ) -> [CGPoint] {
        guard points.count >= 2, depth > 0 else { return points }
        let normals = outwardNormals(points, closed: closed)
        let facetLength = max(4, length)
        var traveled: CGFloat = 0
        return points.enumerated().map { index, point in
            if index > 0 {
                traveled += distance(points[index - 1], point)
            }
            let facet = Int(traveled / facetLength)
            var facetRNG = SplitMix64(seed: seed &+ UInt64(facet) &* 0x9E37_79B9_7F4A_7C15)
            let facetShift = CGFloat.random(in: -1...1, using: &facetRNG) * depth
            var nick: CGFloat = 0
            if jaggedness > 0 {
                var nickRNG = SplitMix64(seed: seed &+ UInt64(index) &* 0xBF58_476D_1CE4_E5B9)
                nick = CGFloat.random(in: -1...1, using: &nickRNG) * jaggedness * depth * 0.35
            }
            let normal = normals[index]
            return CGPoint(
                x: point.x + normal.x * (facetShift + nick),
                y: point.y + normal.y * (facetShift + nick)
            )
        }
    }

    /// Outward unit normals. Closed rings use the winding so the paper grows
    /// away from the material. Open ribbons use the left perpendicular.
    private static func outwardNormals(_ points: [CGPoint], closed: Bool) -> [CGPoint] {
        let count = points.count
        let area = signedArea(points)
        let winding: CGFloat = area >= 0 ? 1 : -1
        return (0..<count).map { index in
            let previous = closed ? (index + count - 1) % count : max(0, index - 1)
            let next = closed ? (index + 1) % count : min(count - 1, index + 1)
            let dx = points[next].x - points[previous].x
            let dy = points[next].y - points[previous].y
            let span = hypot(dx, dy)
            guard span > 1e-4 else { return CGPoint(x: 0, y: -1) }
            if closed {
                return CGPoint(x: dy / span * winding, y: -dx / span * winding)
            }
            return CGPoint(x: -dy / span, y: dx / span)
        }
    }

    // MARK: - Offset

    /// Moves a closed ring along its outward normal by `distance`.
    ///
    /// Positive `distance` grows the ring. Negative `distance` shrinks it,
    /// which is how a hole keeps a paper margin. Miters longer than about
    /// 3.2 times the travel are beveled. Returns nil when the offset flips
    /// winding or crosses itself.
    static func offsetClosed(_ points: [CGPoint], by distance: CGFloat) -> [CGPoint]? {
        let ring = clean(points, dropClosingDuplicate: true)
        guard ring.count >= 3, abs(distance) > 0.2 else { return nil }
        let area = signedArea(ring)
        guard abs(area) > 1 else { return nil }

        let sign: CGFloat = area > 0 ? 1 : -1
        var edges: [(start: CGPoint, end: CGPoint)] = []
        edges.reserveCapacity(ring.count)
        for index in 0..<ring.count {
            let start = ring[index]
            let end = ring[(index + 1) % ring.count]
            let dx = end.x - start.x
            let dy = end.y - start.y
            let span = hypot(dx, dy)
            guard span > 0.05 else { continue }
            let inwardX = (-dy / span) * sign
            let inwardY = (dx / span) * sign
            let shift = CGPoint(x: -inwardX * distance, y: -inwardY * distance)
            edges.append((
                CGPoint(x: start.x + shift.x, y: start.y + shift.y),
                CGPoint(x: end.x + shift.x, y: end.y + shift.y)
            ))
        }
        guard edges.count >= 3 else { return nil }

        let maxMiter = max(4, abs(distance) * 3.2)
        var result: [CGPoint] = []
        result.reserveCapacity(edges.count * 2)
        for index in 0..<edges.count {
            let previous = edges[(index + edges.count - 1) % edges.count]
            let current = edges[index]
            if let hit = intersection(previous.start, previous.end, current.start, current.end),
               Self.distance(hit, previous.end) <= maxMiter,
               Self.distance(hit, current.start) <= maxMiter {
                result.append(hit)
            } else {
                result.append(previous.end)
                result.append(current.start)
            }
        }

        let cleaned = clean(result, dropClosingDuplicate: true)
        guard cleaned.count >= 3 else { return nil }
        let grown = signedArea(cleaned)
        guard grown * area > 0, abs(grown) > 4 else { return nil }
        guard !segmentsIntersect(cleaned) else { return nil }
        return cleaned
    }

    // MARK: - Sampling

    private static func resample(_ points: [CGPoint], closed: Bool, spacing: CGFloat) -> [CGPoint] {
        guard points.count >= 2, spacing > 0.25 else { return points }
        let source = clean(points, dropClosingDuplicate: closed)
        guard source.count >= 2 else { return points }
        var result: [CGPoint] = [source[0]]
        var cursor = source[0]
        var remaining = spacing
        let segments = closed ? source.count : source.count - 1
        let perimeter = length(of: source, closed: closed)
        let stepLimit = Int(perimeter / spacing) + source.count + 8
        var guardSteps = 0
        var index = 0
        while index < segments && guardSteps < stepLimit {
            guardSteps += 1
            let end = source[(index + 1) % source.count]
            let span = distance(cursor, end)
            if span < 1e-4 {
                index += 1
                cursor = end
                continue
            }
            if span + 1e-4 < remaining {
                remaining -= span
                index += 1
                cursor = end
                continue
            }
            let step = remaining / span
            cursor = CGPoint(
                x: cursor.x + (end.x - cursor.x) * step,
                y: cursor.y + (end.y - cursor.y) * step
            )
            result.append(cursor)
            remaining = spacing
        }
        if !closed, let last = source.last, distance(result[result.count - 1], last) > spacing * 0.35 {
            result.append(last)
        }
        return result.count >= 2 ? result : points
    }

    private static func length(of points: [CGPoint], closed: Bool) -> CGFloat {
        guard points.count >= 2 else { return 0 }
        var total: CGFloat = 0
        for index in 1..<points.count {
            total += distance(points[index - 1], points[index])
        }
        if closed {
            total += distance(points[points.count - 1], points[0])
        }
        return total
    }

    // MARK: - Paths

    /// A turning angle at least this large, in radians, is a real corner.
    /// Egg and circle samples stay under it. Star tips and rectangle corners do not.
    /// About 52°. Egg samples and circle steps stay under this. A rectangle
    /// corner is 90°, and a star tip is sharper still.
    private static let cornerTurn: CGFloat = 0.90

    private static func compoundPath(
        _ rings: [[CGPoint]],
        closed: Bool,
        curved: Bool,
        continuous: Bool = false
    ) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        for ring in rings where ring.count >= 2 {
            path.addPath(contourPath(
                ring,
                closed: closed && ring.count >= 3,
                curved: curved,
                continuous: continuous
            ))
        }
        return path
    }

    /// Smooth paper between corners. Torn paper and short runs stay lines.
    /// `continuous` ignores corners so the tangent does not break.
    static func contourPath(
        _ points: [CGPoint],
        closed: Bool,
        curved: Bool,
        continuous: Bool = false
    ) -> SwiftUI.Path {
        let ring = clean(points, dropClosingDuplicate: closed)
        if continuous, ring.count >= 4 {
            return closed ? closedSpline(ring) : openSpline(ring)
        }
        guard curved, ring.count >= 4 else {
            return polyline(ring.isEmpty ? points : ring, closed: closed && ring.count >= 3)
        }
        var corners = ring.indices.filter { isCorner(ring, index: $0, closed: closed) }
        if !closed {
            if corners.first != 0 { corners.insert(0, at: 0) }
            if corners.last != ring.count - 1 { corners.append(ring.count - 1) }
        }
        if closed && corners.isEmpty {
            return closedSpline(ring)
        }
        guard !corners.isEmpty else {
            return openSpline(ring)
        }
        var path = SwiftUI.Path()
        let chainCount = closed ? corners.count : corners.count - 1
        for index in 0..<chainCount {
            let start = corners[index]
            let end = closed ? corners[(index + 1) % corners.count] : corners[index + 1]
            let chain = slice(ring, from: start, to: end)
            appendSpline(&path, chain, needsMove: path.isEmpty)
        }
        if closed {
            path.closeSubpath()
        }
        return path
    }

    private static func isCorner(_ points: [CGPoint], index: Int, closed: Bool) -> Bool {
        let count = points.count
        let previous = closed ? (index + count - 1) % count : index - 1
        let next = closed ? (index + 1) % count : index + 1
        guard previous >= 0, next < count, previous != index, next != index else { return false }
        let spanIn = distance(points[previous], points[index])
        let spanOut = distance(points[index], points[next])
        guard spanIn > 0.4, spanOut > 0.4 else { return false }
        return abs(turning(points[previous], points[index], points[next])) >= cornerTurn
    }

    private static func turning(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        let ux = b.x - a.x
        let uy = b.y - a.y
        let vx = c.x - b.x
        let vy = c.y - b.y
        return atan2(ux * vy - uy * vx, ux * vx + uy * vy)
    }

    private static func slice(_ points: [CGPoint], from start: Int, to end: Int) -> [CGPoint] {
        if end >= start {
            return Array(points[start...end])
        }
        return Array(points[start...]) + Array(points[...end])
    }

    private static func closedSpline(_ points: [CGPoint]) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        guard let first = points.first, points.count >= 2 else { return path }
        path.move(to: first)
        let count = points.count
        for index in 0..<count {
            let p0 = points[(index - 1 + count) % count]
            let p1 = points[index]
            let p2 = points[(index + 1) % count]
            let p3 = points[(index + 2) % count]
            let controls = splineControls(p0, p1, p2, p3)
            path.addCurve(to: p2, control1: controls.0, control2: controls.1)
        }
        path.closeSubpath()
        return path
    }

    private static func openSpline(_ points: [CGPoint]) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        appendSpline(&path, points, needsMove: true)
        return path
    }

    private static func appendSpline(_ path: inout SwiftUI.Path, _ chain: [CGPoint], needsMove: Bool) {
        guard let first = chain.first else { return }
        if needsMove || path.isEmpty {
            path.move(to: first)
        }
        guard chain.count >= 2 else { return }
        if chain.count == 2 {
            path.addLine(to: chain[1])
            return
        }
        for index in 0..<(chain.count - 1) {
            let p1 = chain[index]
            let p2 = chain[index + 1]
            let p0 = index == 0
                ? CGPoint(x: 2 * p1.x - p2.x, y: 2 * p1.y - p2.y)
                : chain[index - 1]
            let p3 = index + 2 < chain.count
                ? chain[index + 2]
                : CGPoint(x: 2 * p2.x - p1.x, y: 2 * p2.y - p1.y)
            let controls = splineControls(p0, p1, p2, p3)
            path.addCurve(to: p2, control1: controls.0, control2: controls.1)
        }
    }

    /// Uniform Catmull-Rom segment from `p1` to `p2`.
    private static func splineControls(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint
    ) -> (CGPoint, CGPoint) {
        let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
        let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
        return (c1, c2)
    }

    private static func polyline(_ points: [CGPoint], closed: Bool) -> SwiftUI.Path {
        var path = SwiftUI.Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        if closed {
            path.closeSubpath()
        }
        return path
    }

    // MARK: - Geometry

    private static func clean(_ points: [CGPoint], dropClosingDuplicate: Bool) -> [CGPoint] {
        var ring: [CGPoint] = []
        ring.reserveCapacity(points.count)
        for point in points where point.x.isFinite && point.y.isFinite {
            if let last = ring.last, distance(last, point) < 0.3 {
                continue
            }
            ring.append(point)
        }
        if dropClosingDuplicate, ring.count >= 2, distance(ring[0], ring[ring.count - 1]) < 0.3 {
            ring.removeLast()
        }
        return ring
    }

    /// How many larger rings contain this one. Odd means a hole.
    private static func nestingDepth(_ index: Int, in lines: [Centerline]) -> Int {
        let sample = centroid(lines[index].points)
        let area = abs(signedArea(lines[index].points))
        var depth = 0
        for other in lines.indices where other != index {
            guard abs(signedArea(lines[other].points)) > area * 1.02 else { continue }
            if contains(sample, polygon: lines[other].points) {
                depth += 1
            }
        }
        return depth
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint {
        let sum = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        let count = CGFloat(max(points.count, 1))
        return CGPoint(x: sum.x / count, y: sum.y / count)
    }

    private static func contains(_ point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var previous = polygon.count - 1
        for index in 0..<polygon.count {
            let currentY = polygon[index].y
            let previousY = polygon[previous].y
            let crosses = (currentY > point.y) != (previousY > point.y)
            if crosses {
                let x = (polygon[previous].x - polygon[index].x) * (point.y - currentY)
                    / (previousY - currentY) + polygon[index].x
                if point.x < x {
                    inside.toggle()
                }
            }
            previous = index
        }
        return inside
    }

    private static func bounds(_ points: [CGPoint]) -> CGRect {
        var rect = CGRect.null
        for point in points {
            rect = rect.union(CGRect(origin: point, size: .zero))
        }
        return rect.isNull ? .zero : rect
    }

    private static func signedArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count >= 3 else { return 0 }
        var sum: CGFloat = 0
        for index in 0..<points.count {
            let next = points[(index + 1) % points.count]
            sum += points[index].x * next.y - next.x * points[index].y
        }
        return sum / 2
    }

    private static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private static func distance(_ point: CGPoint, toSegment start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-8 else { return distance(point, start) }
        let t = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return distance(point, CGPoint(x: start.x + t * dx, y: start.y + t * dy))
    }

    private static func intersection(
        _ a0: CGPoint, _ a1: CGPoint,
        _ b0: CGPoint, _ b1: CGPoint
    ) -> CGPoint? {
        let dax = a1.x - a0.x
        let day = a1.y - a0.y
        let dbx = b1.x - b0.x
        let dby = b1.y - b0.y
        let denom = dax * dby - day * dbx
        guard abs(denom) > 1e-5 else { return nil }
        let t = ((b0.x - a0.x) * dby - (b0.y - a0.y) * dbx) / denom
        return CGPoint(x: a0.x + t * dax, y: a0.y + t * day)
    }

    private static func segmentsIntersect(_ points: [CGPoint]) -> Bool {
        let count = points.count
        guard count >= 4 else { return false }
        for i in 0..<count {
            for j in (i + 1)..<count {
                let gap = min(abs(i - j), count - abs(i - j))
                if gap <= 1 { continue }
                if segmentsCross(
                    points[i], points[(i + 1) % count],
                    points[j], points[(j + 1) % count]
                ) {
                    return true
                }
            }
        }
        return false
    }

    private static func segmentsCross(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> Bool {
        func side(_ p: CGPoint, _ q: CGPoint, _ r: CGPoint) -> CGFloat {
            (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x)
        }
        let ab = side(a, b, c) * side(a, b, d)
        let cd = side(c, d, a) * side(c, d, b)
        return ab < -1e-4 && cd < -1e-4
    }
}

/// Flattens one CGPath into open and closed polylines.
private final class PathWalker {
    var pieces: [StickerBackingBuilder.Centerline] = []
    private var current: [CGPoint] = []

    func move(_ point: CGPoint) {
        finishOpen()
        current = [point]
    }

    func line(_ point: CGPoint) {
        guard !current.isEmpty else {
            current = [point]
            return
        }
        append(flattenLine: point)
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
        flattenCubic(start, control1, control2, end, depth: 0)
    }

    func close() {
        guard current.count >= 3 else {
            current = []
            return
        }
        pieces.append(.init(points: current, closed: true))
        current = []
    }

    func finishOpen() {
        if current.count >= 2 {
            pieces.append(.init(points: current, closed: false))
        }
        current = []
    }

    private func append(flattenLine point: CGPoint) {
        current.append(point)
    }

    private func flattenCubic(
        _ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint,
        depth: Int
    ) {
        let flat = depth > 8
            || (segmentDistance(p1, p0, p3) <= 0.8 && segmentDistance(p2, p0, p3) <= 0.8)
        if flat {
            current.append(p3)
            return
        }
        let p01 = mid(p0, p1)
        let p12 = mid(p1, p2)
        let p23 = mid(p2, p3)
        let p012 = mid(p01, p12)
        let p123 = mid(p12, p23)
        let split = mid(p012, p123)
        flattenCubic(p0, p01, p012, split, depth: depth + 1)
        flattenCubic(split, p123, p23, p3, depth: depth + 1)
    }

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
    }

    private func segmentDistance(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-8 else { return hypot(point.x - start.x, point.y - start.y) }
        let t = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let x = start.x + t * dx
        let y = start.y + t * dy
        return hypot(point.x - x, point.y - y)
    }
}
