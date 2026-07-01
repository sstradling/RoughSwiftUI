import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class NativeStrokeOutlineTests: XCTestCase {
    private func horizontalLinePath() -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 10, y: 10))
        path.addLine(to: CGPoint(x: 90, y: 10))
        return path
    }

    private func sharpCornerPath() -> SwiftUI.Path {
        var path = SwiftUI.Path()
        path.move(to: CGPoint(x: 0, y: 100))
        path.addLine(to: CGPoint(x: 50, y: 0))
        path.addLine(to: CGPoint(x: 100, y: 100))
        return path
    }

    func testZeroWidthProducesEmptyPath() {
        let outline = NativeStrokeOutline.path(
            from: horizontalLinePath(),
            width: 0,
            cap: .round,
            join: .round
        )

        XCTAssertTrue(outline.isEmpty)
    }

    func testRoundCapExtendsPastButtCap() {
        let butt = NativeStrokeOutline.path(
            from: horizontalLinePath(),
            width: 20,
            cap: .butt,
            join: .round
        )
        let round = NativeStrokeOutline.path(
            from: horizontalLinePath(),
            width: 20,
            cap: .round,
            join: .round
        )

        XCTAssertLessThan(round.boundingRect.minX, butt.boundingRect.minX)
        XCTAssertGreaterThan(round.boundingRect.maxX, butt.boundingRect.maxX)
    }

    func testSquareCapExtendsPastButtCap() {
        let butt = NativeStrokeOutline.path(
            from: horizontalLinePath(),
            width: 20,
            cap: .butt,
            join: .round
        )
        let square = NativeStrokeOutline.path(
            from: horizontalLinePath(),
            width: 20,
            cap: .square,
            join: .round
        )

        XCTAssertLessThan(square.boundingRect.minX, butt.boundingRect.minX)
        XCTAssertGreaterThan(square.boundingRect.maxX, butt.boundingRect.maxX)
    }

    func testMiterJoinExtendsFurtherThanBevelForSharpCorner() {
        let bevel = NativeStrokeOutline.path(
            from: sharpCornerPath(),
            width: 10,
            cap: .butt,
            join: .bevel,
            miterLimit: 10
        )
        let miter = NativeStrokeOutline.path(
            from: sharpCornerPath(),
            width: 10,
            cap: .butt,
            join: .miter,
            miterLimit: 10
        )

        XCTAssertLessThan(
            miter.boundingRect.minY,
            bevel.boundingRect.minY,
            "Miter join should extend the sharp corner beyond the bevel outline"
        )
    }

    func testLowMiterLimitClampsSharpMiter() {
        let lowLimit = NativeStrokeOutline.path(
            from: sharpCornerPath(),
            width: 10,
            cap: .butt,
            join: .miter,
            miterLimit: 1
        )
        let highLimit = NativeStrokeOutline.path(
            from: sharpCornerPath(),
            width: 10,
            cap: .butt,
            join: .miter,
            miterLimit: 10
        )

        XCTAssertGreaterThan(
            lowLimit.boundingRect.minY,
            highLimit.boundingRect.minY,
            "Lower miter limit should clamp the spike closer to the bevel"
        )
    }

    func testOperationsConvenienceMatchesPathConvenience() {
        let operations: [RoughSwiftUI.Operation] = [
            Move(data: [10, 10]),
            LineTo(data: [90, 10])
        ]
        let fromOps = NativeStrokeOutline.path(
            operations: operations,
            width: 12,
            cap: .round,
            join: .round
        )
        let fromPath = NativeStrokeOutline.path(
            from: horizontalLinePath(),
            width: 12,
            cap: .round,
            join: .round
        )

        XCTAssertEqual(fromOps.boundingRect, fromPath.boundingRect)
    }
}
