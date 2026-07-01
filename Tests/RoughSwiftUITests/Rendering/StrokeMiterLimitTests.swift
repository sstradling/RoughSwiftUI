import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class StrokeMiterLimitTests: XCTestCase {
    func testOptionsDefaultStrokeMiterLimit() {
        XCTAssertEqual(Options().strokeMiterLimit, 10)
    }

    func testStrokeMiterLimitIncludedInCacheHash() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a.cacheHash, b.cacheHash)

        a.strokeMiterLimit = 2
        XCTAssertNotEqual(a.cacheHash, b.cacheHash)
    }

    func testRoughViewModifierSetsMiterLimit() {
        let view = RoughView().strokeMiterLimit(3)
        XCTAssertEqual(view.options.strokeMiterLimit, 3)
    }

    func testRoughViewModifierClampsMiterLimit() {
        let view = RoughView().strokeMiterLimit(0)
        XCTAssertEqual(view.options.strokeMiterLimit, 1)
    }

    func testSwiftUIRendererPropagatesMiterLimitToCommands() {
        var options = Options()
        options.strokeJoin = .miter
        options.strokeMiterLimit = 2

        let set = OperationSet(
            type: .path,
            operations: [
                Move(data: [0, 0]),
                LineTo(data: [50, 0]),
                LineTo(data: [50, 50])
            ],
            path: nil,
            size: nil
        )
        let drawing = Drawing(shape: "test", sets: [set], options: options)

        let commands = SwiftUIRenderer().commands(
            for: drawing,
            options: options,
            in: CGSize(width: 100, height: 100)
        )

        XCTAssertEqual(commands.first?.miterLimit, 2)
    }

    func testRoughRenderCommandClampsMiterLimit() {
        let command = RoughRenderCommand(
            path: SwiftUI.Path(),
            style: .stroke(.black, lineWidth: 1),
            join: .miter,
            miterLimit: 0
        )

        XCTAssertEqual(command.miterLimit, 1)
    }
}
