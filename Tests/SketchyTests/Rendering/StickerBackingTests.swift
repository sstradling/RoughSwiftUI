import CoreGraphics
import SwiftUI
import XCTest
@testable import Sketchy

/// Paper backing behind a sketch. Geometry is checked on the render commands
/// so a disabled backing cannot change the existing stroke or fill output.
@MainActor
final class StickerBackingTests: XCTestCase {

    func testDisabledBackingMatchesTheUnbackedCommands() throws {
        let size = CGSize(width: 220, height: 180)
        var options = cleanOptions()
        options.strokeJoin = .curvedBevel(bulge: 0.65)
        options.strokeMiterLimit = 3
        options.fill = .systemRed
        options.fillStyle = .solid
        let drawing = try drawing(Polygon(points: star(cx: 110, cy: 90, outer: 70, inner: 30)), options: options, size: size)

        let plain = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        var backed = options
        backed.stickerBacking = nil
        let again = SwiftUIRenderer().commands(for: drawing, options: backed, in: size)
        XCTAssertEqual(plain.count, again.count)
        for (left, right) in zip(plain, again) {
            XCTAssertEqual(left.path.boundingRect, right.path.boundingRect)
            XCTAssertEqual(left.miterLimit, right.miterLimit)
            XCTAssertEqual(left.join, right.join)
        }
        XCTAssertFalse(plain.isEmpty)
    }

    func testZeroWidthDrawsNoPaper() throws {
        let size = CGSize(width: 200, height: 160)
        var options = cleanOptions()
        let drawing = try drawing(Rectangle(x: 40, y: 30, width: 100, height: 70), options: options, size: size)
        let plain = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        options.stickerBacking = StickerBacking(width: 0, smoothness: 1, edge: .torn())
        let backed = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        XCTAssertEqual(plain.count, backed.count)
    }

    func testBackingDoesNotChangeGeneratedGeometry() throws {
        let size = CGSize(width: 200, height: 160)
        var plain = cleanOptions()
        plain.seed = 19
        plain.roughness = 1.4
        var backed = plain
        backed.stickerBacking = StickerBacking(width: 14, smoothness: 0.7, edge: .torn(StickerTear(depth: 6)))

        let generator = Engine().generator(size: size)
        let shape = Circle(x: 100, y: 80, diameter: 90)
        let left = try XCTUnwrap(generator.generate(drawable: shape, options: plain))
        let right = try XCTUnwrap(generator.generate(drawable: shape, options: backed))
        XCTAssertEqual(left.sets.count, right.sets.count)
        for (a, b) in zip(left.sets, right.sets) {
            XCTAssertEqual(a.type, b.type)
            XCTAssertEqual(a.operations.count, b.operations.count)
        }
    }

    func testClosedRectangleGrowsByTheMarginPastTheStroke() throws {
        let size = CGSize(width: 220, height: 180)
        var options = cleanOptions()
        options.strokeWidth = 4
        options.stickerBacking = StickerBacking(width: 16)
        let drawing = try drawing(Rectangle(x: 40, y: 36, width: 100, height: 60), options: options, size: size)
        let commands = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        let paper = try XCTUnwrap(commands.first)
        guard case .fill = paper.style else {
            return XCTFail("Closed contour should fill a sheet, not only stroke one")
        }
        let bounds = paper.path.boundingRect
        // Centerline is the rectangle. The sheet reaches width + strokeWidth/2 past it.
        XCTAssertEqual(bounds.minX, 22, accuracy: 3)
        XCTAssertEqual(bounds.minY, 18, accuracy: 3)
        XCTAssertEqual(bounds.maxX, 158, accuracy: 3)
        XCTAssertEqual(bounds.maxY, 114, accuracy: 3)

        let plain = SwiftUIRenderer().commands(
            for: drawing,
            options: cleanOptions(strokeWidth: 4),
            in: size
        )
        XCTAssertEqual(commands.count, plain.count + 1)
        for (backed, original) in zip(commands.dropFirst(), plain) {
            XCTAssertEqual(backed.path.boundingRect, original.path.boundingRect)
        }
    }

    func testWiderBackingIsLarger() throws {
        let size = CGSize(width: 220, height: 180)
        let shape = Rectangle(x: 40, y: 36, width: 100, height: 60)
        let narrow = try paperBounds(shape, width: 8, size: size)
        let wide = try paperBounds(shape, width: 22, size: size)
        XCTAssertLessThan(wide.minX, narrow.minX - 8)
        XCTAssertGreaterThan(wide.maxX, narrow.maxX + 8)
        XCTAssertLessThan(wide.minY, narrow.minY - 8)
        XCTAssertGreaterThan(wide.maxY, narrow.maxY + 8)
    }

    func testSmoothnessRemovesWobbleAndKeepsTheStar() throws {
        let size = CGSize(width: 260, height: 240)
        var options = Options()
        options.seed = 11
        options.roughness = 2.4
        options.maxRandomnessOffset = 3.2
        options.bowing = 1
        options.strokeWidth = 2
        options.fill = .clear
        let points = star(cx: 130, cy: 120, outer: 78, inner: 32)
        let ideal = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        let shape = Polygon(points: points)

        options.stickerBacking = StickerBacking(width: 12, smoothness: 0)
        let roughDrawing = try drawing(shape, options: options, size: size)
        let rough = try onlyClosed(StickerBackingBuilder.centerlines(
            for: roughDrawing, options: options, backing: options.stickerBacking!, transform: nil
        ))

        options.stickerBacking = StickerBacking(width: 12, smoothness: 1)
        let smoothDrawing = try drawing(shape, options: options, size: size)
        let smooth = try onlyClosed(StickerBackingBuilder.centerlines(
            for: smoothDrawing, options: options, backing: options.stickerBacking!, transform: nil
        ))

        let roughDistance = meanEdgeDistance(rough, to: ideal)
        let smoothDistance = meanEdgeDistance(smooth, to: ideal)
        XCTAssertGreaterThan(roughDistance, 1)
        XCTAssertLessThan(smoothDistance, roughDistance * 0.45)
        XCTAssertGreaterThan(radiusRatio(smooth), 1.7)
    }

    func testTornEdgeIsSeededAndDiffersFromSmooth() throws {
        let size = CGSize(width: 220, height: 180)
        var options = cleanOptions()
        options.seed = 23
        options.roughness = 1.1
        let shape = Circle(x: 110, y: 90, diameter: 100)
        options.stickerBacking = StickerBacking(width: 14, smoothness: 0.45, edge: .smooth)
        let smooth = try paperPath(shape, options: options, size: size)

        options.stickerBacking = StickerBacking(
            width: 14,
            smoothness: 0.45,
            edge: .torn(StickerTear(depth: 7, length: 14, jaggedness: 0.4))
        )
        let torn = try paperPath(shape, options: options, size: size)
        let again = try paperPath(shape, options: options, size: size)
        XCTAssertEqual(samples(torn), samples(again))
        XCTAssertNotEqual(samples(torn), samples(smooth))

        options.seed = 99
        let otherSeed = try paperPath(shape, options: options, size: size)
        XCTAssertNotEqual(samples(torn), samples(otherSeed))
    }

    func testOpenLineIsARibbonNotAFilledSheet() throws {
        let size = CGSize(width: 220, height: 120)
        var options = cleanOptions()
        options.strokeWidth = 3
        options.fill = .clear
        options.stickerBacking = StickerBacking(width: 10, smoothness: 0.2)
        let drawing = try drawing(Line(from: Point(x: 20, y: 60), to: Point(x: 190, y: 64)), options: options, size: size)
        let backed = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        var plainOptions = options
        plainOptions.stickerBacking = nil
        let plain = SwiftUIRenderer().commands(for: drawing, options: plainOptions, in: size)
        let extra = backed.count - plain.count
        XCTAssertGreaterThan(extra, 0)
        for command in backed.prefix(extra) {
            guard case .stroke(_, let lineWidth) = command.style else {
                return XCTFail("Open contour should be a paper ribbon")
            }
            XCTAssertEqual(lineWidth, 23, accuracy: 0.01)
        }
    }

    func testLegacyClosedShapeStaysARibbon() throws {
        let size = CGSize(width: 200, height: 160)
        var options = cleanOptions()
        options.strokeContinuity = .legacy
        options.fill = .clear
        let drawing = try drawing(Rectangle(x: 30, y: 30, width: 90, height: 70), options: options, size: size)
        let plain = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        options.stickerBacking = StickerBacking(width: 8)
        let backed = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        let extra = backed.count - plain.count
        XCTAssertGreaterThanOrEqual(extra, 4)
        for command in backed.prefix(extra) {
            guard case .stroke = command.style else {
                return XCTFail("Legacy edges are open strokes, so the paper is a ribbon")
            }
        }
    }

    func testCompoundHoleKeepsAnOpeningAndAMargin() throws {
        let size = CGSize(width: 160, height: 160)
        var options = cleanOptions()
        options.strokeWidth = 2
        options.fill = .clear
        options.roughness = 0.4
        options.stickerBacking = StickerBacking(width: 10, smoothness: 0.85)
        let path = "M10 10 H110 V110 H10 Z M40 40 H80 V80 H40 Z"
        let drawing = try drawing(Path(d: path), options: options, size: size)
        let commands = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        let paper = try XCTUnwrap(commands.first)
        guard case .fill = paper.style else {
            return XCTFail("A closed compound path should fill one sheet")
        }
        let outline = paper.path.cgPath
        let bounds = paper.path.boundingRect
        let hole = CGPoint(x: bounds.midX, y: bounds.midY)
        XCTAssertFalse(outline.contains(hole, using: .evenOdd))
        let material = CGPoint(x: bounds.minX + bounds.width * 0.12, y: bounds.midY)
        XCTAssertTrue(outline.contains(material, using: .evenOdd))
        XCTAssertGreaterThan(bounds.width, 100)
    }

    func testConcaveStarOffsetDoesNotExplode() throws {
        let size = CGSize(width: 240, height: 220)
        var options = cleanOptions()
        options.roughness = 1.3
        options.seed = 4
        options.stickerBacking = StickerBacking(width: 14, smoothness: 0.15)
        let drawing = try drawing(
            Polygon(points: star(cx: 120, cy: 110, outer: 80, inner: 28)),
            options: options,
            size: size
        )
        let commands = SwiftUIRenderer().commands(for: drawing, options: options, in: size)
        let paper = try XCTUnwrap(commands.first)
        let bounds = paper.path.boundingRect
        XCTAssertTrue(bounds.width.isFinite && bounds.height.isFinite)
        XCTAssertLessThan(bounds.width, 280)
        XCTAssertGreaterThan(bounds.width, 140)
        let ratio = radiusRatio(samples(paper.path))
        XCTAssertGreaterThan(ratio, 1.35)
    }

    func testSmoothEggPaperIsACurveAndStarKeepsCorners() throws {
        let eggOptions = cleanOptions()
        var eggBacking = eggOptions
        eggBacking.strokeWidth = 2
        eggBacking.stickerBacking = StickerBacking(width: 22, smoothness: 1)
        let eggSize = CGSize(width: 240, height: 280)
        let eggPath = try paperPath(
            EggShape(x: 120, y: 140, width: 90, height: 140, tilt: 0.42),
            options: eggBacking,
            size: eggSize
        )
        let eggKinds = elementKinds(eggPath)
        XCTAssertGreaterThan(eggKinds.curves, 12)
        XCTAssertEqual(eggKinds.lines, 0)
        let eggTurns = turningSamples(eggPath, spacing: 8)
        XCTAssertLessThan(eggTurns.max() ?? 1, 0.7)
        XCTAssertEqual(isolatedFacets(eggTurns), 0)

        var starOptions = cleanOptions()
        starOptions.stickerBacking = StickerBacking(width: 12, smoothness: 1)
        let starPath = try paperPath(
            Polygon(points: star(cx: 110, cy: 100, outer: 70, inner: 28)),
            options: starOptions,
            size: CGSize(width: 220, height: 200)
        )
        let starTurns = turningSamples(starPath, spacing: 6)
        XCTAssertGreaterThan(starTurns.max() ?? 0, 0.85)
        XCTAssertGreaterThan(isolatedFacets(starTurns), 3)

        var tornOptions = eggBacking
        tornOptions.stickerBacking = StickerBacking(
            width: 22,
            smoothness: 1,
            edge: .torn(StickerTear(depth: 8, length: 16, jaggedness: 0.4))
        )
        let tornPath = try paperPath(
            EggShape(x: 120, y: 140, width: 90, height: 140, tilt: 0.42),
            options: tornOptions,
            size: eggSize
        )
        XCTAssertEqual(elementKinds(tornPath).curves, 0)
        XCTAssertGreaterThan(elementKinds(tornPath).lines, 8)
    }

    func testTextureIsSeededClippedAndOptional() throws {
        let size = CGSize(width: 180, height: 160)
        var options = cleanOptions()
        options.strokeWidth = 2
        options.stickerBacking = StickerBacking(width: 12, smoothness: 1, color: .white, texture: nil)
        let plain = try commands(Rectangle(x: 30, y: 28, width: 100, height: 70), options: options, size: size)
        let bare = try commands(Rectangle(x: 30, y: 28, width: 100, height: 70), options: cleanOptions(strokeWidth: 2), size: size)
        XCTAssertEqual(plain.count, bare.count + 1)

        options.stickerBacking = StickerBacking(
            width: 12,
            smoothness: 1,
            color: UIColor(red: 0.95, green: 0.90, blue: 0.75, alpha: 1),
            texture: StickerTexture(amount: 0.5, scale: 10, seed: 5)
        )
        let tinted = try commands(Rectangle(x: 30, y: 28, width: 100, height: 70), options: options, size: size)
        let again = try commands(Rectangle(x: 30, y: 28, width: 100, height: 70), options: options, size: size)
        let fibers = tinted.filter { $0.clipPath != nil }
        XCTAssertFalse(fibers.isEmpty)
        XCTAssertEqual(fibers.count, again.filter { $0.clipPath != nil }.count)
        XCTAssertEqual(samples(fibers[0].path), samples(again.first { $0.clipPath != nil }!.path))
        XCTAssertEqual(fibers[0].clipPath?.boundingRect, tinted[0].path.boundingRect)

        options.stickerBacking = StickerBacking(
            width: 12,
            smoothness: 1,
            texture: StickerTexture(amount: 0.5, scale: 10, seed: 9)
        )
        let other = try commands(Rectangle(x: 30, y: 28, width: 100, height: 70), options: options, size: size)
        XCTAssertNotEqual(
            samples(fibers[0].path),
            samples(other.first { $0.clipPath != nil }!.path)
        )

        let view = RoughView().stickerBacking(
            width: 10,
            color: Color(red: 0.2, green: 0.4, blue: 0.8),
            texture: .paper(seed: 3)
        )
        XCTAssertEqual(view.options.stickerBacking?.texture?.seed, 3)
        XCTAssertEqual(view.options.stickerBacking?.texture?.amount, 0.45)
        var red: CGFloat = 0
        view.options.stickerBacking?.color.getRed(&red, green: nil, blue: nil, alpha: nil)
        XCTAssertEqual(red, 0.2, accuracy: 0.02)
    }

    func testCacheHashIncludesBacking() {
        var options = Options()
        let plain = options.cacheHash
        options.stickerBacking = StickerBacking(width: 8)
        XCTAssertNotEqual(plain, options.cacheHash)
        options.stickerBacking = StickerBacking(width: 8, smoothness: 0.5)
        let smooth = options.cacheHash
        options.stickerBacking = StickerBacking(width: 8, smoothness: 0.5, edge: .torn())
        XCTAssertNotEqual(smooth, options.cacheHash)
    }

    func testModifierStoresBacking() {
        let view = RoughView().stickerBacking(width: 9, smoothness: 0.4, edge: .torn())
        XCTAssertEqual(view.options.stickerBacking?.width, 9)
        XCTAssertEqual(view.options.stickerBacking?.smoothness, 0.4)
        guard case .torn = view.options.stickerBacking?.edge else {
            return XCTFail("Expected a torn edge")
        }
        let cleared = view.stickerBacking(nil)
        XCTAssertNil(cleared.options.stickerBacking)
    }

    func testMarginSitsOutsideTheInkAndFillStaysOnTop() throws {
        let view = RoughView()
            .fill(UIColor.systemRed)
            .fillStyle(.solid)
            .stroke(UIColor.black)
            .strokeWidth(4)
            .roughness(0)
            .bowing(0)
            .maxRandomnessOffset(0)
            .seed(3)
            .stickerBacking(width: 16)
            .draw(Rectangle(x: 40, y: 40, width: 100, height: 60))
            .frame(width: 200, height: 160)
            .background(Color.blue)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 200, height: 160)
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage?.cgImage)
        let center = try pixel(image, x: 90, y: 70)
        let margin = try pixel(image, x: 28, y: 70)
        let outside = try pixel(image, x: 6, y: 6)
        XCTAssertGreaterThan(center.red, 180)
        XCTAssertLessThan(center.blue, 80)
        XCTAssertGreaterThan(margin.red, 220)
        XCTAssertGreaterThan(margin.green, 220)
        XCTAssertGreaterThan(margin.blue, 220)
        XCTAssertGreaterThan(outside.blue, 180)
        XCTAssertLessThan(outside.red, 80)
    }

    // MARK: - Fixtures

    private func cleanOptions(strokeWidth: Float = 2) -> Options {
        var options = Options()
        options.roughness = 0
        options.bowing = 0
        options.maxRandomnessOffset = 0
        options.strokeWidth = strokeWidth
        options.seed = 1
        options.fill = .clear
        return options
    }

    private func drawing(_ shape: Drawable, options: Options, size: CGSize) throws -> Drawing {
        let generator = Engine().generator(size: size)
        return try XCTUnwrap(generator.generate(drawable: shape, options: options))
    }

    private func paperBounds(_ shape: Drawable, width: CGFloat, size: CGSize) throws -> CGRect {
        var options = cleanOptions()
        options.stickerBacking = StickerBacking(width: width)
        let drawing = try drawing(shape, options: options, size: size)
        let command = try XCTUnwrap(
            SwiftUIRenderer().commands(for: drawing, options: options, in: size).first
        )
        return command.path.boundingRect
    }

    private func commands(_ shape: Drawable, options: Options, size: CGSize) throws -> [RoughRenderCommand] {
        let drawing = try drawing(shape, options: options, size: size)
        return SwiftUIRenderer().commands(for: drawing, options: options, in: size)
    }

    private func paperPath(_ shape: Drawable, options: Options, size: CGSize) throws -> SwiftUI.Path {
        let drawing = try drawing(shape, options: options, size: size)
        let command = try XCTUnwrap(
            SwiftUIRenderer().commands(for: drawing, options: options, in: size).first
        )
        return command.path
    }

    private func onlyClosed(_ lines: [StickerBackingBuilder.Centerline]) throws -> [CGPoint] {
        let closed = lines.filter(\.closed)
        XCTAssertEqual(closed.count, 1)
        return try XCTUnwrap(closed.first).points
    }

    private func star(cx: Float, cy: Float, outer: Float, inner: Float) -> [Point] {
        (0..<10).map { index in
            let angle = -Float.pi / 2 + Float(index) * .pi / 5
            let radius = index.isMultiple(of: 2) ? outer : inner
            return Point(x: cx + cos(angle) * radius, y: cy + sin(angle) * radius)
        }
    }

    private func meanEdgeDistance(_ samples: [CGPoint], to polygon: [CGPoint]) -> CGFloat {
        guard !samples.isEmpty, polygon.count >= 3 else { return 0 }
        let total = samples.reduce(CGFloat.zero) { partial, sample in
            var best = CGFloat.greatestFiniteMagnitude
            for index in 0..<polygon.count {
                let start = polygon[index]
                let end = polygon[(index + 1) % polygon.count]
                best = min(best, distance(sample, start, end))
            }
            return partial + best
        }
        return total / CGFloat(samples.count)
    }

    private func distance(_ point: CGPoint, _ start: CGPoint, _ end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 1e-6 else { return hypot(point.x - start.x, point.y - start.y) }
        let t = min(1, max(0, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }

    private func radiusRatio(_ points: [CGPoint]) -> CGFloat {
        guard let first = points.first else { return 1 }
        let center = points.reduce(CGPoint.zero) { partial, point in
            CGPoint(x: partial.x + point.x, y: partial.y + point.y)
        }
        let count = CGFloat(points.count)
        let origin = CGPoint(x: center.x / count, y: center.y / count)
        let radii = points.map { hypot($0.x - origin.x, $0.y - origin.y) }
        let maxRadius = radii.max() ?? 1
        let minRadius = max(radii.min() ?? 1, 0.5)
        _ = first
        return maxRadius / minRadius
    }

    private func elementKinds(_ path: SwiftUI.Path) -> (lines: Int, curves: Int) {
        var lines = 0
        var curves = 0
        path.cgPath.applyWithBlock { element in
            switch element.pointee.type {
            case .addLineToPoint:
                lines += 1
            case .addCurveToPoint, .addQuadCurveToPoint:
                curves += 1
            default:
                break
            }
        }
        return (lines, curves)
    }

    /// A kink with straight neighbors is a polygon vertex. A smooth curve is not.
    private func isolatedFacets(_ turns: [CGFloat]) -> Int {
        guard turns.count >= 5 else { return 0 }
        var count = 0
        for index in 0..<turns.count {
            let previous = turns[(index + turns.count - 2) % turns.count]
            let next = turns[(index + 2) % turns.count]
            if turns[index] > 0.5, previous < 0.12, next < 0.12 {
                count += 1
            }
        }
        return count
    }

    /// Largest direction change along the paper edge, in radians.
    private func turningSamples(_ path: SwiftUI.Path, spacing: CGFloat) -> [CGFloat] {
        let points = resampled(path.cgPath, spacing: spacing)
        guard points.count >= 3 else { return [] }
        return (0..<points.count).map { index in
            let previous = points[(index + points.count - 1) % points.count]
            let next = points[(index + 1) % points.count]
            let point = points[index]
            let ux = point.x - previous.x
            let uy = point.y - previous.y
            let vx = next.x - point.x
            let vy = next.y - point.y
            return abs(atan2(ux * vy - uy * vx, ux * vx + uy * vy))
        }
    }

    private func resampled(_ path: CGPath, spacing: CGFloat) -> [CGPoint] {
        var raw: [CGPoint] = []
        path.applyWithBlock { element in
            let values = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                raw.append(values[0])
            case .addLineToPoint:
                raw.append(values[0])
            case .addQuadCurveToPoint:
                appendCurve(&raw, from: raw.last ?? values[1], controls: [values[0]], to: values[1])
            case .addCurveToPoint:
                appendCurve(&raw, from: raw.last ?? values[2], controls: [values[0], values[1]], to: values[2])
            default:
                break
            }
        }
        guard raw.count >= 2 else { return raw }
        var spaced: [CGPoint] = [raw[0]]
        var carry: CGFloat = 0
        for index in 1..<raw.count {
            var cursor = raw[index - 1]
            let end = raw[index]
            var span = hypot(end.x - cursor.x, end.y - cursor.y)
            var remaining = spacing - carry
            while span + 0.001 >= remaining, span > 0.001 {
                let step = remaining / span
                cursor = CGPoint(x: cursor.x + (end.x - cursor.x) * step, y: cursor.y + (end.y - cursor.y) * step)
                spaced.append(cursor)
                span = hypot(end.x - cursor.x, end.y - cursor.y)
                remaining = spacing
                carry = 0
            }
            carry += span
        }
        return spaced
    }

    private func appendCurve(_ points: inout [CGPoint], from start: CGPoint, controls: [CGPoint], to end: CGPoint) {
        let steps = 8
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps)
            if controls.count == 1 {
                let u = 1 - t
                points.append(CGPoint(
                    x: u * u * start.x + 2 * u * t * controls[0].x + t * t * end.x,
                    y: u * u * start.y + 2 * u * t * controls[0].y + t * t * end.y
                ))
            } else if controls.count == 2 {
                let u = 1 - t
                points.append(CGPoint(
                    x: u * u * u * start.x + 3 * u * u * t * controls[0].x + 3 * u * t * t * controls[1].x + t * t * t * end.x,
                    y: u * u * u * start.y + 3 * u * u * t * controls[0].y + 3 * u * t * t * controls[1].y + t * t * t * end.y
                ))
            }
        }
    }

    private func samples(_ path: SwiftUI.Path) -> [CGPoint] {
        var points: [CGPoint] = []
        path.cgPath.applyWithBlock { element in
            let values = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint, .addLineToPoint:
                points.append(values[0])
            case .addQuadCurveToPoint:
                points.append(values[1])
            case .addCurveToPoint:
                points.append(values[2])
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        return points
    }

    private struct RGBA {
        var red: Int
        var green: Int
        var blue: Int
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) throws -> RGBA {
        let width = image.width
        let height = image.height
        XCTAssertGreaterThan(width, x)
        XCTAssertGreaterThan(height, y)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drew = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drew)
        let flippedY = height - 1 - y
        let offset = flippedY * width * 4 + x * 4
        return RGBA(
            red: Int(pixels[offset]),
            green: Int(pixels[offset + 1]),
            blue: Int(pixels[offset + 2])
        )
    }
}
