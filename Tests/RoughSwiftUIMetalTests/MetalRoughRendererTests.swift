//
//  MetalRoughRendererTests.swift
//  RoughSwiftUIMetalTests
//
//  Behavioral tests for the MetalRoughRenderer wrapper. These do NOT
//  exercise the GPU: they verify the renderer's split between SwiftUI fill
//  commands and Metal stroke draw lists, conformance to RoughRenderer, and
//  RibbonAppearance derivation from Options.
//

import XCTest
import simd
import Metal
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

@MainActor
final class MetalRoughRendererTests: XCTestCase {

    private func makeStrokeDrawing() -> Drawing {
        var options = Options()
        options.stroke = .red
        options.strokeWidth = 2

        let ops: [RoughSwiftUI.Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [50, 50])
        ]
        let set = OperationSet(type: .path, operations: ops, path: nil, size: nil)
        return Drawing(shape: "test", sets: [set], options: options)
    }

    private func makeFillDrawing() -> Drawing {
        var options = Options()
        options.stroke = .clear
        options.fill = .blue
        options.fillStyle = .solid

        let ops: [RoughSwiftUI.Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [50, 0]),
            LineTo(data: [50, 50]),
            LineTo(data: [0, 50]),
            Close()
        ]
        let set = OperationSet(type: .fillPath, operations: ops, path: nil, size: nil)
        return Drawing(shape: "test", sets: [set], options: options)
    }

    // MARK: Protocol conformance

    func testConformsToRoughRendererProtocol() {
        let renderer: any RoughRenderer = MetalRoughRenderer(device: nil)
        XCTAssertNotNil(renderer)
    }

    // MARK: Command list filtering

    func testCommandsExcludesBorderSetsHandledByMetal() {
        // For a stroke-only drawing (one .path set), the Metal renderer
        // returns no SwiftUI commands — the Metal layer handles all of it.
        let renderer = MetalRoughRenderer(device: nil)
        let drawing = makeStrokeDrawing()

        let commands = renderer.commands(
            for: drawing,
            options: drawing.options,
            in: CGSize(width: 100, height: 100)
        )

        XCTAssertTrue(
            commands.isEmpty,
            "A drawing whose only set is a border path must produce no SwiftUI commands"
        )
    }

    func testCommandsIncludesFillsForFillSet() {
        let renderer = MetalRoughRenderer(device: nil)
        let drawing = makeFillDrawing()

        let commands = renderer.commands(
            for: drawing,
            options: drawing.options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertFalse(commands.isEmpty, "Fill commands should pass through the Metal renderer to the SwiftUI fill layer")
    }

    // MARK: Metal draw list

    func testMetalDrawListIsEmptyWithoutDevice() {
        let renderer = MetalRoughRenderer(device: nil)
        let drawing = makeStrokeDrawing()
        let draws = renderer.metalDrawList(
            for: drawing,
            options: drawing.options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertTrue(draws.isEmpty, "No draws should be produced when no Metal device is available")
    }

    func testMetalDrawListIncludesStrokesWhenDeviceAvailable() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available on this host")
        }
        let renderer = MetalRoughRenderer(device: device)
        let drawing = makeStrokeDrawing()
        let draws = renderer.metalDrawList(
            for: drawing,
            options: drawing.options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertFalse(draws.isEmpty, "Stroke ops should produce ribbon draws")
        for d in draws {
            XCTAssertFalse(d.mesh.vertices.isEmpty)
            // Color should be red with full opacity per options.
            XCTAssertEqual(d.appearance.colorStart.x, 1, accuracy: 0.001)
            XCTAssertEqual(d.appearance.colorStart.y, 0, accuracy: 0.001)
            XCTAssertEqual(d.appearance.colorStart.z, 0, accuracy: 0.001)
            XCTAssertEqual(d.appearance.opacityScale, 1, accuracy: 0.001)
        }
    }

    // MARK: Appearance

    func testRibbonAppearanceCarriesStrokeOpacity() {
        var options = Options()
        options.stroke = .green
        options.strokeOpacity = 0.5

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.opacityScale, 0.5, accuracy: 0.001)
        XCTAssertEqual(appearance.colorStart.y, 1.0, accuracy: 0.01) // green
    }

    func testRibbonAppearanceFlatColorWhenNoGradient() {
        var options = Options()
        options.stroke = .black
        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart, appearance.colorEnd, "Default appearance is flat color")
    }
}

