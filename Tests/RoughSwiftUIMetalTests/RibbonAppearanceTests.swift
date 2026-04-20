//
//  RibbonAppearanceTests.swift
//  RoughSwiftUIMetalTests
//
//  Verifies that `RibbonAppearance.from(options:)` correctly translates
//  the new variable-stroke-appearance fields on `Options` into shader
//  uniforms. These tests are pure-CPU and do not require a Metal device.
//

import XCTest
import simd
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

final class RibbonAppearanceTests: XCTestCase {

    // MARK: - Color resolution

    func testFlatColorWhenNoStrokeColorAlongPath() {
        var options = Options()
        options.stroke = .red

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart, appearance.colorEnd,
                       "With no along-path color, start and end must match")
        XCTAssertEqual(appearance.colorStart.x, 1, accuracy: 0.001)
        XCTAssertEqual(appearance.colorStart.y, 0, accuracy: 0.001)
        XCTAssertEqual(appearance.colorStart.z, 0, accuracy: 0.001)
    }

    func testGradientPopulatesStartAndEndColors() {
        var options = Options()
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)

        let appearance = RibbonAppearance.from(options: options)
        // Start should be red.
        XCTAssertEqual(appearance.colorStart.x, 1, accuracy: 0.001)
        XCTAssertEqual(appearance.colorStart.y, 0, accuracy: 0.001)
        XCTAssertEqual(appearance.colorStart.z, 0, accuracy: 0.001)
        // End should be blue.
        XCTAssertEqual(appearance.colorEnd.x, 0, accuracy: 0.001)
        XCTAssertEqual(appearance.colorEnd.y, 0, accuracy: 0.001)
        XCTAssertEqual(appearance.colorEnd.z, 1, accuracy: 0.001)
    }

    func testStrokeColorAlongPathOverridesPlainStroke() {
        // `strokeColorAlongPath` takes precedence over `stroke`. When both
        // are set, the gradient wins.
        var options = Options()
        options.stroke = .green
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)

        let appearance = RibbonAppearance.from(options: options)
        // Start should be red, not green.
        XCTAssertEqual(appearance.colorStart.x, 1, accuracy: 0.001)
        XCTAssertEqual(appearance.colorStart.y, 0, accuracy: 0.001)
    }

    func testSolidColorAlongPathProducesFlatStartAndEnd() {
        var options = Options()
        options.strokeColorAlongPath = .solid(.green)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart, appearance.colorEnd)
        XCTAssertEqual(appearance.colorStart.y, 1, accuracy: 0.001)
    }

    // MARK: - Opacity envelope

    func testOpacityTaperBakesIntoEndpointAlphas() {
        var options = Options()
        options.stroke = .red
        options.strokeOpacityAlongPath = .taper(start: 0, end: 1)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart.w, 0, accuracy: 0.001,
                       "Start alpha should be tapered to 0")
        XCTAssertEqual(appearance.colorEnd.w, 1, accuracy: 0.001,
                       "End alpha should be 1")
    }

    func testOpacityConstantAppliesToBothEndpoints() {
        var options = Options()
        options.stroke = .red
        options.strokeOpacityAlongPath = .constant(0.5)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart.w, 0.5, accuracy: 0.001)
        XCTAssertEqual(appearance.colorEnd.w, 0.5, accuracy: 0.001)
    }

    func testOpacityAlongPathMultipliesWithBaseColorAlpha() {
        // A semi-transparent stroke color combined with an opacity taper
        // should multiply the two factors.
        var options = Options()
        options.stroke = UIColor.red.withAlphaComponent(0.5)
        options.strokeOpacityAlongPath = .taper(start: 0, end: 1)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart.w, 0.0, accuracy: 0.001,
                       "0.5 * 0 = 0")
        XCTAssertEqual(appearance.colorEnd.w, 0.5, accuracy: 0.001,
                       "0.5 * 1 = 0.5")
    }

    // MARK: - Global opacity

    func testStrokeOpacityMapsToOpacityScale() {
        var options = Options()
        options.strokeOpacity = 0.3

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.opacityScale, 0.3, accuracy: 0.001)
    }

    // MARK: - Edge softness

    func testStrokeEdgeSoftnessPropagates() {
        var options = Options()
        options.strokeEdgeSoftness = 0.7

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.edgeSoftness, 0.7, accuracy: 0.001)
    }

    func testStrokeEdgeSoftnessDefaultsToZero() {
        let appearance = RibbonAppearance.from(options: Options())
        XCTAssertEqual(appearance.edgeSoftness, 0)
    }
}
