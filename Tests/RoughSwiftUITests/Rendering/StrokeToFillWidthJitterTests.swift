//
//  StrokeToFillWidthJitterTests.swift
//  RoughSwiftUITests
//
//  Verifies that StrokeToFillConverter visibly varies the outline width
//  along the stroke when WidthJitter is supplied, and that
//  SwiftUIRenderer routes through the converter when jitter is set even
//  with a default brush profile.
//

import XCTest
import SwiftUI
@testable import RoughSwiftUI

@MainActor
final class StrokeToFillWidthJitterTests: XCTestCase {

    private func longHorizontalLineOps() -> [Operation] {
        // 1000-pt line so the noise has multiple cycles to vary across.
        [Move(data: [0, 50]), LineTo(data: [1000, 50])]
    }

    /// Returns the height of the bounding box of the filled outline,
    /// which corresponds to the maximum stroke width somewhere along the
    /// path. For a horizontal line of width W, the bbox height is ~W.
    private func boundingHeight(_ path: SwiftUI.Path) -> CGFloat {
        path.boundingRect.height
    }

    // MARK: - Stroke-to-fill geometry

    func testNoJitterProducesUniformWidth() {
        let path = StrokeToFillConverter.convert(
            operations: longHorizontalLineOps(),
            baseWidth: 10,
            profile: .default
        )
        // Without jitter, the bbox height should be ~10 (the base width)
        // plus the round-cap radius. We just assert a tight upper bound.
        let h = boundingHeight(path)
        XCTAssertGreaterThan(h, 9)
        XCTAssertLessThan(h, 12,
                          "Uniform-width stroke should have bbox height ~ baseWidth")
    }

    func testJitterAmount30PercentExpandsBoundingHeight() {
        let baseWidth: CGFloat = 10
        let jitter = WidthJitter(amount: 0.3, frequency: 0.2, seed: 0)
        let path = StrokeToFillConverter.convert(
            operations: longHorizontalLineOps(),
            baseWidth: baseWidth,
            profile: .default,
            widthJitter: jitter
        )
        let h = boundingHeight(path)
        // With a 30% jitter, the peak width is up to 1.3 * baseWidth = 13;
        // accounting for round caps the bbox height should comfortably
        // exceed the unjittered ~11 ceiling.
        XCTAssertGreaterThan(h, 11.5,
                             "Jittered stroke should have noticeably larger bbox height (got \(h))")
    }

    func testJitterIsDeterministicAcrossCalls() {
        let jitter = WidthJitter(amount: 0.25, frequency: 0.1, seed: 42)
        let p1 = StrokeToFillConverter.convert(
            operations: longHorizontalLineOps(),
            baseWidth: 8,
            profile: .default,
            widthJitter: jitter
        )
        let p2 = StrokeToFillConverter.convert(
            operations: longHorizontalLineOps(),
            baseWidth: 8,
            profile: .default,
            widthJitter: jitter
        )
        // Two calls with the same jitter must produce paths with
        // identical bounding rects (the underlying noise is deterministic).
        XCTAssertEqual(p1.boundingRect, p2.boundingRect,
                       "Same WidthJitter must produce identical filled outlines")
    }

    // MARK: - SwiftUIRenderer integration

    func testWidthJitterAloneTriggersStrokeToFill() {
        // Without WidthJitter, default brush profile produces a single
        // .stroke command. With WidthJitter set, the renderer should
        // route through StrokeToFillConverter and produce a single
        // .fill command instead.
        var options = Options()
        options.stroke = .black
        options.strokeWidth = 4
        options.strokeWidthJitter = WidthJitter(amount: 0.2)

        let renderer = SwiftUIRenderer()
        let drawing = Drawing(
            shape: "test",
            sets: [
                OperationSet(type: .path,
                             operations: longHorizontalLineOps(),
                             path: nil, size: nil)
            ],
            options: options
        )
        let commands = renderer.commands(
            for: drawing, options: options,
            in: CGSize(width: 1000, height: 200)
        )
        XCTAssertEqual(commands.count, 1)
        if case .fill = commands.first?.style {
            // expected
        } else {
            XCTFail("WidthJitter should route the stroke through StrokeToFillConverter (.fill style)")
        }
    }

    func testNoJitterPreservesSingleStrokeCommand() {
        // Sanity: without WidthJitter, the default-brush-profile path
        // remains a single .stroke command (regression guard against
        // accidentally enabling stroke-to-fill always).
        var options = Options()
        options.stroke = .black
        options.strokeWidth = 4

        let renderer = SwiftUIRenderer()
        let drawing = Drawing(
            shape: "test",
            sets: [
                OperationSet(type: .path,
                             operations: longHorizontalLineOps(),
                             path: nil, size: nil)
            ],
            options: options
        )
        let commands = renderer.commands(
            for: drawing, options: options,
            in: CGSize(width: 1000, height: 200)
        )
        XCTAssertEqual(commands.count, 1)
        if case .stroke = commands.first?.style {
            // expected
        } else {
            XCTFail("Default stroke without jitter must remain a single .stroke command")
        }
    }
}
