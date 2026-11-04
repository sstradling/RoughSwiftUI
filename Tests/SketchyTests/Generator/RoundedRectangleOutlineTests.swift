import Foundation
import XCTest
@testable import Sketchy

/// Rounded-rectangle corners must draw the whole quarter and meet the sides.
/// `bezierFromPoints` only strokes points[1] through points[len-2], so a corner
/// that forgets its padding points leaves a gap at the join.
@MainActor
final class RoundedRectangleOutlineTests: XCTestCase {
    func testRoundedRectangleCornerArcsReachSideEndpointsAndQuarterPoint() {
        for curveStepCount in [Float(4), Options().curveStepCount, 16] {
            assertCornerArcs(
                width: 200,
                height: 160,
                cornerRadius: 36,
                curveStepCount: curveStepCount
            )
        }
    }

    func testClampedRoundedRectangleCornerArcsReachSideEndpointsAndQuarterPoint() {
        // Half the short side is 80. A larger radius has to clamp to that.
        for curveStepCount in [Float(4), Options().curveStepCount, 16] {
            assertCornerArcs(
                width: 200,
                height: 160,
                cornerRadius: 400,
                curveStepCount: curveStepCount
            )
        }
    }

    private func assertCornerArcs(
        width: Float,
        height: Float,
        cornerRadius: Float,
        curveStepCount: Float,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var options = Options()
        options.seed = 27
        options.roughness = 1
        options.maxRandomnessOffset = 2
        options.curveTightness = 0
        options.curveStepCount = curveStepCount

        let x: Float = 0
        let y: Float = 0
        let ops = RoughMath.roundedRectangleOps(
            x: x, y: y, width: width, height: height,
            cornerRadius: cornerRadius, options: options
        )
        let repeated = RoughMath.roundedRectangleOps(
            x: x, y: y, width: width, height: height,
            cornerRadius: cornerRadius, options: options
        )
        XCTAssertEqual(
            coordinates(of: ops),
            coordinates(of: repeated),
            "seed 27 should repeat the outline at curveStepCount \(curveStepCount)",
            file: file,
            line: line
        )

        // Expected joins use the clamped radius. An outline that ignores the
        // clamp draws those points at the unclamped radius and fails below.
        let radius = min(cornerRadius, min(width, height) / 2)
        let pieces = outlinePieces(x: x, y: y, width: width, height: height, radius: radius)
        let subpaths = strokeSubpaths(from: ops)
        XCTAssertEqual(
            subpaths.count,
            pieces.count * 2,
            "each side and corner is a double stroke at curveStepCount \(curveStepCount)",
            file: file,
            line: line
        )
        guard subpaths.count == pieces.count * 2 else { return }

        // Line ends wander by maxRandomnessOffset on each axis. Corner joins
        // use a quarter of that. 2× covers the diagonal and still rejects the
        // old gap (a full sample step, about 14pt at radius 36).
        let endpointTolerance = options.maxRandomnessOffset * options.roughness * 2
        // Interior samples use pass offsets of 1 and 1.5, so a point on the
        // curve stays within about 1.5√2 of the true arc.
        let quarterTolerance = 1.5 * options.roughness * 2
        let fillTolerance = quarterTolerance + 2

        var outlineSamples: [Point] = []
        for (index, piece) in pieces.enumerated() {
            let strokes = [subpaths[index * 2], subpaths[index * 2 + 1]]
            if piece.isCorner {
                XCTAssertNotEqual(
                    coordinates(of: strokes[0]),
                    coordinates(of: strokes[1]),
                    "\(piece.name) double stroke should wobble at curveStepCount \(curveStepCount)",
                    file: file,
                    line: line
                )
            }
            for stroke in strokes {
                XCTAssertFalse(
                    stroke.curves.isEmpty,
                    "\(piece.name) should draw a stroke",
                    file: file,
                    line: line
                )
                XCTAssertLessThan(
                    distance(stroke.start, piece.startX, piece.startY),
                    endpointTolerance,
                    "\(piece.name) should start near the side endpoint at curveStepCount \(curveStepCount)",
                    file: file,
                    line: line
                )
                XCTAssertLessThan(
                    distance(stroke.end, piece.endX, piece.endY),
                    endpointTolerance,
                    "\(piece.name) should end near the side endpoint at curveStepCount \(curveStepCount)",
                    file: file,
                    line: line
                )
                if piece.isCorner {
                    let samples = samples(of: stroke, divisions: 8)
                    XCTAssertLessThan(
                        nearest(samples, x: piece.midX, y: piece.midY),
                        quarterTolerance,
                        "\(piece.name) should pass the 45° point at curveStepCount \(curveStepCount)",
                        file: file,
                        line: line
                    )
                }
                outlineSamples.append(contentsOf: samples(of: stroke, divisions: 8))
            }
        }

        let polygon = RoughMath.roundedRectanglePolygonPoints(
            x: x, y: y, width: width, height: height, cornerRadius: cornerRadius
        )
        for vertex in polygon {
            XCTAssertLessThan(
                nearest(outlineSamples, x: vertex[0], y: vertex[1]),
                fillTolerance,
                "fill polygon should lie on the outline at curveStepCount \(curveStepCount)",
                file: file,
                line: line
            )
        }
    }

    /// Draw order of `roundedRectangleOps`: side, corner, side, corner, around the shape.
    private func outlinePieces(
        x: Float, y: Float,
        width: Float, height: Float,
        radius: Float
    ) -> [OutlinePiece] {
        let topRight = (x + width - radius, y + radius)
        let bottomRight = (x + width - radius, y + height - radius)
        let bottomLeft = (x + radius, y + height - radius)
        let topLeft = (x + radius, y + radius)

        let topRightStart = arcPoint(topRight, radius, -Float.pi / 2)
        let topRightEnd = arcPoint(topRight, radius, 0)
        let bottomRightStart = arcPoint(bottomRight, radius, 0)
        let bottomRightEnd = arcPoint(bottomRight, radius, Float.pi / 2)
        let bottomLeftStart = arcPoint(bottomLeft, radius, Float.pi / 2)
        let bottomLeftEnd = arcPoint(bottomLeft, radius, Float.pi)
        let topLeftStart = arcPoint(topLeft, radius, Float.pi)
        let topLeftEnd = arcPoint(topLeft, radius, 3 * Float.pi / 2)

        return [
            OutlinePiece(
                name: "top",
                startX: topLeftEnd.0, startY: topLeftEnd.1,
                endX: topRightStart.0, endY: topRightStart.1,
                midX: 0, midY: 0, isCorner: false
            ),
            OutlinePiece(
                name: "top-right",
                startX: topRightStart.0, startY: topRightStart.1,
                endX: topRightEnd.0, endY: topRightEnd.1,
                midX: arcPoint(topRight, radius, -Float.pi / 4).0,
                midY: arcPoint(topRight, radius, -Float.pi / 4).1,
                isCorner: true
            ),
            OutlinePiece(
                name: "right",
                startX: topRightEnd.0, startY: topRightEnd.1,
                endX: bottomRightStart.0, endY: bottomRightStart.1,
                midX: 0, midY: 0, isCorner: false
            ),
            OutlinePiece(
                name: "bottom-right",
                startX: bottomRightStart.0, startY: bottomRightStart.1,
                endX: bottomRightEnd.0, endY: bottomRightEnd.1,
                midX: arcPoint(bottomRight, radius, Float.pi / 4).0,
                midY: arcPoint(bottomRight, radius, Float.pi / 4).1,
                isCorner: true
            ),
            OutlinePiece(
                name: "bottom",
                startX: bottomRightEnd.0, startY: bottomRightEnd.1,
                endX: bottomLeftStart.0, endY: bottomLeftStart.1,
                midX: 0, midY: 0, isCorner: false
            ),
            OutlinePiece(
                name: "bottom-left",
                startX: bottomLeftStart.0, startY: bottomLeftStart.1,
                endX: bottomLeftEnd.0, endY: bottomLeftEnd.1,
                midX: arcPoint(bottomLeft, radius, 3 * Float.pi / 4).0,
                midY: arcPoint(bottomLeft, radius, 3 * Float.pi / 4).1,
                isCorner: true
            ),
            OutlinePiece(
                name: "left",
                startX: bottomLeftEnd.0, startY: bottomLeftEnd.1,
                endX: topLeftStart.0, endY: topLeftStart.1,
                midX: 0, midY: 0, isCorner: false
            ),
            OutlinePiece(
                name: "top-left",
                startX: topLeftStart.0, startY: topLeftStart.1,
                endX: topLeftEnd.0, endY: topLeftEnd.1,
                midX: arcPoint(topLeft, radius, 5 * Float.pi / 4).0,
                midY: arcPoint(topLeft, radius, 5 * Float.pi / 4).1,
                isCorner: true
            )
        ]
    }

    private func arcPoint(_ center: (Float, Float), _ radius: Float, _ angle: Float) -> (Float, Float) {
        (center.0 + radius * cos(angle), center.1 + radius * sin(angle))
    }

    private func strokeSubpaths(from ops: [Sketchy.Operation]) -> [StrokeSubpath] {
        var result: [StrokeSubpath] = []
        var current: StrokeSubpath?
        for op in ops {
            if let move = op as? Move {
                if let current {
                    result.append(current)
                }
                current = StrokeSubpath(start: move.point, curves: [])
            } else if let curve = op as? BezierCurveTo {
                current?.curves.append(curve)
            }
        }
        if let current {
            result.append(current)
        }
        return result
    }

    private func samples(of subpath: StrokeSubpath, divisions: Int) -> [Point] {
        var points = [subpath.start]
        var current = subpath.start
        for curve in subpath.curves {
            for step in 1...divisions {
                let t = Float(step) / Float(divisions)
                points.append(cubic(
                    current,
                    curve.controlPoint1,
                    curve.controlPoint2,
                    curve.point,
                    t
                ))
            }
            current = curve.point
        }
        return points
    }

    private func cubic(_ p0: Point, _ p1: Point, _ p2: Point, _ p3: Point, _ t: Float) -> Point {
        let u = 1 - t
        let x = u * u * u * p0.x + 3 * u * u * t * p1.x + 3 * u * t * t * p2.x + t * t * t * p3.x
        let y = u * u * u * p0.y + 3 * u * u * t * p1.y + 3 * u * t * t * p2.y + t * t * t * p3.y
        return Point(x: x, y: y)
    }

    private func distance(_ point: Point, _ x: Float, _ y: Float) -> Float {
        let dx = point.x - x
        let dy = point.y - y
        return (dx * dx + dy * dy).squareRoot()
    }

    private func nearest(_ samples: [Point], x: Float, y: Float) -> Float {
        samples.reduce(Float.greatestFiniteMagnitude) { best, sample in
            min(best, distance(sample, x, y))
        }
    }

    private func coordinates(of ops: [Sketchy.Operation]) -> [Float] {
        var values: [Float] = []
        for op in ops {
            if let move = op as? Move {
                values.append(move.point.x)
                values.append(move.point.y)
            } else if let curve = op as? BezierCurveTo {
                values.append(curve.controlPoint1.x)
                values.append(curve.controlPoint1.y)
                values.append(curve.controlPoint2.x)
                values.append(curve.controlPoint2.y)
                values.append(curve.point.x)
                values.append(curve.point.y)
            }
        }
        return values
    }

    private func coordinates(of subpath: StrokeSubpath) -> [Float] {
        var values = [subpath.start.x, subpath.start.y]
        for curve in subpath.curves {
            values.append(curve.controlPoint1.x)
            values.append(curve.controlPoint1.y)
            values.append(curve.controlPoint2.x)
            values.append(curve.controlPoint2.y)
            values.append(curve.point.x)
            values.append(curve.point.y)
        }
        return values
    }
}

private struct OutlinePiece {
    let name: String
    let startX: Float
    let startY: Float
    let endX: Float
    let endY: Float
    let midX: Float
    let midY: Float
    let isCorner: Bool
}

private struct StrokeSubpath {
    var start: Point
    var curves: [BezierCurveTo]
    var end: Point { curves.last?.point ?? start }
}
