//
//  SwiftUIRendererVariableStrokeTests.swift
//  RoughSwiftUITests
//
//  Verifies that SwiftUIRenderer emits per-segment stroke commands when
//  Options.strokeColorAlongPath or Options.strokeOpacityAlongPath is
//  set, achieving feature parity with the Metal renderer for variable
//  stroke color and opacity.
//

import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class SwiftUIRendererVariableStrokeTests: XCTestCase {

    // MARK: Helpers

    /// Build a Drawing whose only set is a `.path` border with a single
    /// straight line from (0, 0) to (100, 0).
    private func lineDrawing(options: Options) -> Drawing {
        let ops: [RoughSwiftUI.Operation] = [
            Move(data: [0, 0]),
            LineTo(data: [100, 0])
        ]
        let set = OperationSet(type: .path, operations: ops, path: nil, size: nil)
        return Drawing(shape: "test", sets: [set], options: options)
    }

    // MARK: - Default behavior preserved

    func testNoVariableAppearanceProducesSingleStrokeCommand() {
        var options = Options()
        options.stroke = .black
        options.strokeWidth = 2
        // No strokeColorAlongPath, no strokeOpacityAlongPath.

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(commands.count, 1,
                       "Default stroke must remain a single-command render")
    }

    // MARK: - Color along path

    func testStrokeColorAlongPathProducesSegmentedCommands() {
        var options = Options()
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        options.stroke = .black

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(commands.count, SegmentedStrokeBuilder.defaultSegmentCount,
                       "Setting strokeColorAlongPath must trigger segmented rendering")
    }

    func testGradientSegmentsHaveDistinctColors() {
        var options = Options()
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        options.strokeWidth = 2

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        )
        guard commands.count >= 2,
              case let .stroke(firstColor, _) = commands.first!.style,
              case let .stroke(lastColor, _) = commands.last!.style
        else {
            return XCTFail("Expected at least two stroke commands")
        }
        XCTAssertNotEqual(firstColor, lastColor,
                          "First and last segments of a gradient must use different colors")
    }

    // MARK: - Opacity along path

    func testStrokeOpacityAlongPathTriggersSegmentation() {
        var options = Options()
        options.stroke = .red
        options.strokeOpacityAlongPath = .taper(start: 0, end: 1)

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        )
        XCTAssertEqual(commands.count, SegmentedStrokeBuilder.defaultSegmentCount,
                       "Setting strokeOpacityAlongPath must trigger segmented rendering")
    }

    // MARK: - Brush profile precedence

    func testBrushProfileTakesPrecedenceOverColorAlongPath() {
        // When both a custom brush profile AND strokeColorAlongPath are
        // set, the brush profile wins (single fill command, not
        // segmented strokes). This is documented behavior; a future
        // change can extend StrokeToFillConverter to honor color
        // variation.
        var options = Options()
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        options.brushProfile = BrushProfile(
            tip: BrushTip(roundness: 0.3, angle: 0, directionSensitive: true),
            thicknessProfile: .uniform,
            cap: .round,
            join: .round
        )
        options.strokeWidth = 4

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        )
        // Should be a single fill command (StrokeToFillConverter output),
        // not 16 segmented stroke commands.
        XCTAssertEqual(commands.count, 1,
                       "Custom brush profile must take precedence over color-along-path")
        if case .fill = commands.first?.style {
            // expected
        } else {
            XCTFail("Expected fill style from StrokeToFillConverter")
        }
    }

    // MARK: - Cap and join propagation

    func testSegmentedCommandsInheritStrokeCapAndJoin() {
        var options = Options()
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        options.strokeCap = .square
        options.strokeJoin = .miter

        let renderer = SwiftUIRenderer()
        let commands = renderer.commands(
            for: lineDrawing(options: options),
            options: options,
            in: CGSize(width: 200, height: 200)
        )
        for command in commands {
            XCTAssertEqual(command.cap, .square)
            XCTAssertEqual(command.join, .miter)
        }
    }
}
