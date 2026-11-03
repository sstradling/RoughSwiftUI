import CoreGraphics
import XCTest
@testable import Sketchy

/// The fill has to sit in the same shape the outline draws.
///
/// Ellipse and circle fills used to jitter their own radii, and zigzag-line
/// clipped to a third, unjittered circle. These tests measure the catalog
/// drawings and the padding / offset knobs.
@MainActor
final class FillAlignmentTests: XCTestCase {
    private var contentSide: CGFloat {
        DocExampleCatalog.tileSide - DocExampleCatalog.tileInset * 2
    }

    func testCatalogEllipseFillMatchesTheOutline() {
        var options = Options()
        options.fillStyle = .hachure
        options.fillSpacing = 3
        options.strokeWidth = 2
        options.seed = 14
        let drawing = generate(
            Ellipse(x: 92, y: 92, width: 150, height: 108),
            options: options
        )
        assertFillSitsInOutline(drawing, label: "ellipse")
    }

    func testCatalogZigzagLineFillMatchesTheOutline() {
        var options = Options()
        options.fillStyle = .zigzagLine
        options.fillAngle = 0
        options.fillSpacing = 4
        options.zigzagOffset = 14
        options.strokeWidth = 2
        options.seed = 52
        let drawing = generate(FullCircle(), options: options, side: contentSide)
        assertFillSitsInOutline(drawing, label: "zigzag line")
    }

    func testZeroPaddingPutsQuietFillOnTheEllipse() {
        var options = quiet()
        options.fillPadding = 0
        options.fillStyle = .hachure
        options.fillAngle = 0
        let drawing = generate(
            Ellipse(x: 90, y: 80, width: 140, height: 100),
            options: options
        )
        let fill = samples(in: drawing, fill: true)
        XCTAssertFalse(fill.isEmpty)
        let rx: Float = 70
        let ry: Float = 50
        var reached: Float = 0
        for point in fill {
            let value = ellipseValue(point, cx: 90, cy: 80, rx: rx, ry: ry)
            XCTAssertLessThanOrEqual(value, 1.02, "padding 0 point outside the ellipse")
            reached = max(reached, value)
        }
        XCTAssertGreaterThan(reached, 0.9, "padding 0 should reach the outline")
    }

    func testPositivePaddingKeepsFillInsideTheInsetEllipse() {
        let padding: CGFloat = 12
        var options = quiet()
        options.fillPadding = padding
        options.fillStyle = .hachure
        options.fillAngle = 0
        let drawing = generate(Circle(x: 80, y: 80, diameter: 120), options: options)
        let fill = samples(in: drawing, fill: true)
        XCTAssertFalse(fill.isEmpty)
        let radius: Float = 60
        let inset = radius - Float(padding)
        var reachedInset: Float = 0
        for point in fill {
            let original = ellipseValue(point, cx: 80, cy: 80, rx: radius, ry: radius)
            let inner = ellipseValue(point, cx: 80, cy: 80, rx: inset, ry: inset)
            XCTAssertLessThanOrEqual(original, 1, "padded fill left the outline")
            XCTAssertLessThanOrEqual(inner, 1.02, "padded fill left the inset ellipse")
            reachedInset = max(reachedInset, inner)
        }
        XCTAssertGreaterThan(reachedInset, 0.85, "fill should reach the inset edge")
    }

    func testNegativePaddingGrowsTheFillPastTheOutline() {
        var options = quiet()
        options.fillPadding = -8
        options.fillStyle = .hachure
        options.fillAngle = 90
        let drawing = generate(Circle(x: 70, y: 70, diameter: 100), options: options)
        let fill = samples(in: drawing, fill: true)
        let outside = fill.contains { point in
            ellipseValue(point, cx: 70, cy: 70, rx: 50, ry: 50) > 1.05
        }
        XCTAssertTrue(outside, "negative padding should draw fill outside the outline")
        for point in fill {
            let grown = ellipseValue(point, cx: 70, cy: 70, rx: 58, ry: 58)
            XCTAssertLessThanOrEqual(grown, 1.02)
        }
    }

    func testPaddingThatCollapsesTheShapeDrawsNoFill() {
        var options = quiet()
        options.fillPadding = 40
        options.fillStyle = .hachure
        let drawing = generate(Circle(x: 50, y: 50, diameter: 60), options: options)
        XCTAssertFalse(samples(in: drawing, fill: false).isEmpty, "outline remains")
        XCTAssertTrue(samples(in: drawing, fill: true).isEmpty, "collapsed fill is omitted")
    }

    func testFillOffsetSlidesTheFillAndLeavesTheOutline() {
        var options = quiet()
        options.fillOffset = CGSize(width: 14, height: -9)
        options.fillStyle = .hachure
        options.fillAngle = 0
        let shifted = generate(Circle(x: 80, y: 80, diameter: 100), options: options)
        var plain = options
        plain.fillOffset = .zero
        let centered = generate(Circle(x: 80, y: 80, diameter: 100), options: plain)

        let shiftedFill = bounds(samples(in: shifted, fill: true))
        let centeredFill = bounds(samples(in: centered, fill: true))
        let shiftedOutline = bounds(samples(in: shifted, fill: false))
        let centeredOutline = bounds(samples(in: centered, fill: false))
        XCTAssertEqual(shiftedOutline.midX, centeredOutline.midX, accuracy: 0.2)
        XCTAssertEqual(shiftedOutline.midY, centeredOutline.midY, accuracy: 0.2)
        XCTAssertEqual(shiftedFill.midX - centeredFill.midX, 14, accuracy: 1.5)
        XCTAssertEqual(shiftedFill.midY - centeredFill.midY, -9, accuracy: 1.5)
    }

    func testPositivePaddingKeepsRectangleFillInsideTheInset() {
        var options = quiet()
        options.fillPadding = 10
        options.fillStyle = .hachure
        options.fillAngle = 0
        let drawing = generate(
            Rectangle(x: 10, y: 20, width: 120, height: 80),
            options: options
        )
        let fill = samples(in: drawing, fill: true)
        XCTAssertFalse(fill.isEmpty)
        for point in fill {
            XCTAssertGreaterThanOrEqual(point.x, 20 - 0.6)
            XCTAssertLessThanOrEqual(point.x, 120 + 0.6)
            XCTAssertGreaterThanOrEqual(point.y, 30 - 0.6)
            XCTAssertLessThanOrEqual(point.y, 90 + 0.6)
        }
        let box = bounds(fill)
        XCTAssertLessThan(box.minX, 28, "a horizontal chord should reach the inset edge")
        XCTAssertGreaterThan(box.maxX, 112)
    }

    func testNegativePaddingGrowsAPolygonPastItsOutline() {
        var options = quiet()
        options.fillPadding = -6
        options.fillStyle = .solid
        let drawing = generate(
            Polygon(points: [
                Point(x: 30, y: 20),
                Point(x: 90, y: 24),
                Point(x: 80, y: 70),
                Point(x: 20, y: 64)
            ]),
            options: options
        )
        let fill = samples(in: drawing, fill: true)
        let outside = fill.contains { point in
            point.x < 20 || point.y < 20 || point.x > 90 || point.y > 70
        }
        XCTAssertTrue(outside, "negative padding should grow the polygon fill")
    }

    func testPaddingCollapsesAThinRectangle() {
        var options = quiet()
        options.fillPadding = 30
        options.fillStyle = .hachure
        let drawing = generate(
            Rectangle(x: 0, y: 0, width: 40, height: 50),
            options: options
        )
        XCTAssertTrue(samples(in: drawing, fill: true).isEmpty)
    }

    func testSvgPathPaddingKeepsFillInsideTheInsetRect() {
        var options = quiet()
        options.fillPadding = 8
        options.fillStyle = .hachure
        options.fillAngle = 0
        let drawing = generate(
            Path(d: "M 20 16 H 140 V 96 H 20 Z"),
            options: options
        )
        let fill = samples(in: drawing, fill: true)
        XCTAssertFalse(fill.isEmpty)
        for point in fill {
            XCTAssertGreaterThanOrEqual(point.x, 28 - 0.8)
            XCTAssertLessThanOrEqual(point.x, 132 + 0.8)
            XCTAssertGreaterThanOrEqual(point.y, 24 - 0.8)
            XCTAssertLessThanOrEqual(point.y, 88 + 0.8)
        }
    }

    func testModifiersAndDefaultsRoundTrip() {
        let view = RoughView().fillPadding(4.5).fillOffset(x: 2, y: -3)
        XCTAssertEqual(view.options.fillPadding, 4.5)
        XCTAssertEqual(view.options.fillOffset, CGSize(width: 2, height: -3))
        XCTAssertEqual(Options().fillPadding, 0)
        XCTAssertEqual(Options().fillOffset, .zero)

        var options = Options()
        options.fillPadding = -2
        options.fillOffset = CGSize(width: 5, height: 6)
        options.seed = 3
        let decoded = Options(dictionary: options.toRoughDictionary())
        XCTAssertEqual(decoded.fillPadding, -2)
        XCTAssertEqual(decoded.fillOffset, CGSize(width: 5, height: 6))

        let drawable = Rectangle(x: 0, y: 0, width: 30, height: 20)
        let size = CGSize(width: 40, height: 40)
        let plain = DrawingCacheKey(drawable: drawable, size: size, options: Options())
        let padded = DrawingCacheKey(drawable: drawable, size: size, options: options)
        XCTAssertNotEqual(plain, padded)
        XCTAssertNotEqual(Options().cacheHash, options.cacheHash)
    }

    func testRectangleInsetGeometry() {
        let rect: [[Float]] = [[0, 0], [100, 0], [100, 80], [0, 80]]
        let inset = FillGeometry.polygon(rect, padding: 10, offset: .zero)
        XCTAssertEqual(inset?.count, 4)
        assertHasPoint(inset, 10, 10)
        assertHasPoint(inset, 90, 10)
        assertHasPoint(inset, 90, 70)
        assertHasPoint(inset, 10, 70)
        XCTAssertNil(FillGeometry.polygon(rect, padding: 50, offset: .zero))

        let grown = FillGeometry.polygon(rect, padding: -10, offset: CGSize(width: 1, height: 2))
        assertHasPoint(grown, -9, -8)
        assertHasPoint(grown, 111, -8)
    }

    // MARK: - Extent

    private func assertFillSitsInOutline(_ drawing: Drawing?, label: String) {
        let fill = samples(in: drawing, fill: true)
        let outline = samples(in: drawing, fill: false)
        let fillBox = bounds(fill)
        let outlineBox = bounds(outline)
        let overshoot = max(
            outlineBox.minX - fillBox.minX,
            fillBox.maxX - outlineBox.maxX,
            outlineBox.minY - fillBox.minY,
            fillBox.maxY - outlineBox.maxY
        )
        let gapLeft = fillBox.minX - outlineBox.minX
        let gapRight = outlineBox.maxX - fillBox.maxX
        let gapTop = fillBox.minY - outlineBox.minY
        let gapBottom = outlineBox.maxY - fillBox.maxY
        let centerGapX = abs(fillBox.midX - outlineBox.midX)
        let centerGapY = abs(fillBox.midY - outlineBox.midY)
        XCTAssertFalse(fill.isEmpty, "\(label) fill")
        XCTAssertFalse(outline.isEmpty, "\(label) outline")
        XCTAssertLessThanOrEqual(
            overshoot,
            6,
            "\(label) fill extends \(overshoot) past the outline (gaps L \(gapLeft) R \(gapRight) T \(gapTop) B \(gapBottom))"
        )
        XCTAssertLessThanOrEqual(
            abs(gapLeft - gapRight),
            10,
            "\(label) is shifted horizontally (L \(gapLeft) R \(gapRight))"
        )
        XCTAssertLessThanOrEqual(
            abs(gapTop - gapBottom),
            10,
            "\(label) is shifted vertically (T \(gapTop) B \(gapBottom))"
        )
        XCTAssertLessThanOrEqual(centerGapX, 6, "\(label) center x")
        XCTAssertLessThanOrEqual(centerGapY, 6, "\(label) center y")
    }

    private func generate(_ drawable: Drawable, options: Options, side: CGFloat = 200) -> Drawing? {
        NativeGenerator(size: CGSize(width: side, height: side)).generate(
            drawable: drawable,
            options: options
        )
    }

    private func quiet() -> Options {
        var options = Options()
        options.roughness = 0
        options.bowing = 0
        options.maxRandomnessOffset = 0
        options.strokeWidth = 2
        options.fillSpacing = 3
        options.seed = 7
        return options
    }

    /// Points on the rendered centerline. Control points are not included.
    private func samples(in drawing: Drawing?, fill: Bool) -> [(x: Float, y: Float)] {
        guard let drawing else { return [] }
        return drawing.sets
            .filter { isFill($0.type) == fill }
            .flatMap { sample($0.operations) }
    }

    private func isFill(_ type: OperationSetType) -> Bool {
        switch type {
        case .path:
            return false
        case .fillPath, .fillSketch, .path2DFill, .path2DPattern:
            return true
        }
    }

    private func sample(_ operations: [Sketchy.Operation]) -> [(x: Float, y: Float)] {
        var points: [(x: Float, y: Float)] = []
        var cursor: (x: Float, y: Float)?
        for operation in operations {
            switch operation {
            case let move as Sketchy.Move:
                cursor = (move.point.x, move.point.y)
                points.append((move.point.x, move.point.y))
            case let segment as Sketchy.LineTo:
                cursor = (segment.point.x, segment.point.y)
                points.append((segment.point.x, segment.point.y))
            case let curve as Sketchy.BezierCurveTo:
                let start = cursor ?? (curve.point.x, curve.point.y)
                for step in 1...8 {
                    let t = Float(step) / 8
                    points.append(cubic(
                        start,
                        (curve.controlPoint1.x, curve.controlPoint1.y),
                        (curve.controlPoint2.x, curve.controlPoint2.y),
                        (curve.point.x, curve.point.y),
                        t
                    ))
                }
                cursor = (curve.point.x, curve.point.y)
            case let quad as Sketchy.QuadraticCurveTo:
                let start = cursor ?? (quad.point.x, quad.point.y)
                for step in 1...8 {
                    let t = Float(step) / 8
                    let u = 1 - t
                    points.append((
                        u * u * start.x + 2 * u * t * quad.controlPoint.x + t * t * quad.point.x,
                        u * u * start.y + 2 * u * t * quad.controlPoint.y + t * t * quad.point.y
                    ))
                }
                cursor = (quad.point.x, quad.point.y)
            default:
                break
            }
        }
        return points
    }

    private func cubic(
        _ p0: (x: Float, y: Float),
        _ p1: (x: Float, y: Float),
        _ p2: (x: Float, y: Float),
        _ p3: (x: Float, y: Float),
        _ t: Float
    ) -> (x: Float, y: Float) {
        let u = 1 - t
        return (
            u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x,
            u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
        )
    }

    private func ellipseValue(
        _ point: (x: Float, y: Float),
        cx: Float,
        cy: Float,
        rx: Float,
        ry: Float
    ) -> Float {
        let nx = (point.x - cx) / rx
        let ny = (point.y - cy) / ry
        return nx * nx + ny * ny
    }

    private struct Box {
        var minX: Float
        var minY: Float
        var maxX: Float
        var maxY: Float
        var midX: Float { (minX + maxX) / 2 }
        var midY: Float { (minY + maxY) / 2 }
    }

    private func bounds(_ points: [(x: Float, y: Float)]) -> Box {
        var box = Box(
            minX: .greatestFiniteMagnitude,
            minY: .greatestFiniteMagnitude,
            maxX: -.greatestFiniteMagnitude,
            maxY: -.greatestFiniteMagnitude
        )
        for point in points {
            box.minX = min(box.minX, point.x)
            box.minY = min(box.minY, point.y)
            box.maxX = max(box.maxX, point.x)
            box.maxY = max(box.maxY, point.y)
        }
        return box
    }

    private func assertHasPoint(_ points: [[Float]]?, _ x: Float, _ y: Float) {
        let match = points?.contains { hypot($0[0] - x, $0[1] - y) < 0.6 } ?? false
        XCTAssertTrue(match, "missing \(x), \(y) in \(String(describing: points))")
    }
}
