//
//  MetalRoughRendererBrushProfileTests.swift
//  RoughSwiftUIMetalTests
//
//  Verifies the Metal renderer's brush-profile fallback: when
//  Options.brushProfile requires stroke-to-fill conversion, the border
//  is rendered by the SwiftUI fallback rather than the Metal mesh
//  shader (which can't reproduce calligraphic tips or thickness
//  profiles).
//

import XCTest
import Metal
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

@MainActor
final class MetalRoughRendererBrushProfileTests: XCTestCase {

    private func lineDrawing(options: Options) -> Drawing {
        let ops: [RoughSwiftUI.Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [50, 0])
        ]
        let set = OperationSet(type: .path, operations: ops, path: nil, size: nil)
        return Drawing(shape: "test", sets: [set], options: options)
    }

    // MARK: bordersHandledByMetal predicate

    func testDefaultProfileKeepsBordersOnMetal() {
        let renderer = MetalRoughRenderer(device: nil)
        XCTAssertTrue(renderer.bordersHandledByMetal(options: Options()),
                      "Default brush profile should route borders to Metal")
    }

    func testCalligraphicProfileFallsBackToSwiftUI() {
        var options = Options()
        options.brushProfile = .calligraphic

        let renderer = MetalRoughRenderer(device: nil)
        XCTAssertFalse(renderer.bordersHandledByMetal(options: options),
                       "Calligraphic brush profile must route borders to SwiftUI fallback")
    }

    func testTaperedThicknessFallsBackToSwiftUI() {
        var options = Options()
        options.thicknessProfile = .taperBoth(start: 0.2, end: 0.2)

        let renderer = MetalRoughRenderer(device: nil)
        XCTAssertFalse(renderer.bordersHandledByMetal(options: options),
                       "Tapered thickness profile must route borders to SwiftUI fallback")
    }

    // MARK: commands(for:) keeps the border when Metal won't handle it

    func testCommandsKeepsBorderForCalligraphicProfile() {
        var options = Options()
        options.brushProfile = .calligraphic
        options.stroke = .black
        options.strokeWidth = 4

        let renderer = MetalRoughRenderer(device: nil)
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertFalse(commands.isEmpty,
                       "Border command must be retained in SwiftUI list when Metal is opting out")
        // The retained command should be a fill (StrokeToFillConverter
        // output), not a stroke.
        if case .fill = commands.first?.style {
            // expected
        } else {
            XCTFail("Expected .fill command from StrokeToFillConverter")
        }
    }

    func testCommandsExcludesBorderForDefaultProfile() {
        // Regression: default profile, single border set → no SwiftUI commands.
        var options = Options()
        options.stroke = .black
        options.strokeWidth = 2

        let renderer = MetalRoughRenderer(device: nil)
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertTrue(commands.isEmpty,
                      "Default-profile drawing whose only set is a border must produce no SwiftUI commands")
    }

    // MARK: metalDrawList opts out for custom brush profiles

    func testMetalDrawListIsEmptyForCalligraphicProfileWithGPU() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available on this host")
        }
        var options = Options()
        options.brushProfile = .calligraphic
        options.stroke = .black
        options.strokeWidth = 4

        let renderer = MetalRoughRenderer(device: device)
        let draws = renderer.metalDrawList(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertTrue(draws.isEmpty,
                      "Calligraphic brush profile must produce no Metal draws (SwiftUI handles the border)")
    }

    func testMetalDrawListIncludesDefaultProfileBorderWithGPU() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available on this host")
        }
        var options = Options()
        options.stroke = .black
        options.strokeWidth = 2
        // No custom brush profile; border should be routed to Metal.

        let renderer = MetalRoughRenderer(device: device)
        let draws = renderer.metalDrawList(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 100, height: 100)
        )
        XCTAssertFalse(draws.isEmpty,
                       "Default brush profile border must produce a Metal draw")
    }
}
