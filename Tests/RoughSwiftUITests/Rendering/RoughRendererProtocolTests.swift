//
//  RoughRendererProtocolTests.swift
//  RoughSwiftUITests
//
//  Verifies that `SwiftUIRenderer` conforms to `RoughRenderer` and that
//  the protocol surface remains stable for downstream renderer modules.
//

import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class RoughRendererProtocolTests: XCTestCase {

    func testSwiftUIRendererConformsToRoughRenderer() {
        // Static-typed binding via protocol existential; would fail to compile
        // if conformance were missing.
        let renderer: any RoughRenderer = SwiftUIRenderer()

        var options = Options()
        options.stroke = .black
        options.strokeWidth = 2

        let move = Move(data: [0, 0])
        let line = LineTo(data: [50, 50])
        let set = OperationSet(type: .path, operations: [move, line], path: nil, size: nil)
        let drawing = Drawing(shape: "test", sets: [set], options: options)

        let commands = renderer.commands(
            for: drawing,
            options: options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertFalse(commands.isEmpty, "SwiftUIRenderer should produce at least one command for a basic line")
    }

    func testRendererProtocolDispatchesToImplementation() {
        // Confirm protocol dispatch returns the same shape as direct calls.
        let direct = SwiftUIRenderer()
        let viaProtocol: any RoughRenderer = direct

        var options = Options()
        options.stroke = .blue
        options.strokeWidth = 3

        let drawing = Drawing(
            shape: "test",
            sets: [
                OperationSet(
                    type: .path,
                    operations: [Move(data: [0, 0]), LineTo(data: [10, 10])],
                    path: nil,
                    size: nil
                )
            ],
            options: options
        )
        let size = CGSize(width: 100, height: 100)

        let directCommands = direct.commands(for: drawing, options: options, in: size)
        let protocolCommands = viaProtocol.commands(for: drawing, options: options, in: size)

        XCTAssertEqual(directCommands.count, protocolCommands.count)
    }
}
