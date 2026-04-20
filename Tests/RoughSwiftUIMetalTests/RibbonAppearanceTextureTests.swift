//
//  RibbonAppearanceTextureTests.swift
//  RoughSwiftUIMetalTests
//
//  Verifies the BrushTexture -> RibbonAppearance translation in
//  `RibbonAppearance.from(options:)`. Pure CPU; no Metal device required.
//

import XCTest
import simd
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

final class RibbonAppearanceTextureTests: XCTestCase {

    // MARK: Smooth

    func testSmoothTextureHasSmoothMode() {
        var options = Options()
        options.brushTexture = .smooth

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.smooth.rawValue)
        XCTAssertEqual(appearance.textureParams, .zero)
    }

    func testDefaultOptionsProduceSmoothMode() {
        let appearance = RibbonAppearance.from(options: Options())
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.smooth.rawValue)
    }

    // MARK: Pencil

    func testPencilTextureMapsModeAndParams() {
        var options = Options()
        options.brushTexture = .pencil(grain: 2.0, density: 0.4)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.pencil.rawValue)
        XCTAssertEqual(appearance.textureParams.x, 2.0, accuracy: 0.001)
        XCTAssertEqual(appearance.textureParams.y, 0.4, accuracy: 0.001)
        XCTAssertEqual(appearance.textureParams.z, 0)
        XCTAssertEqual(appearance.textureParams.w, 0)
    }

    // MARK: Chalk

    func testChalkTextureMapsModeAndParams() {
        var options = Options()
        options.brushTexture = .chalk(grain: 1.2, density: 0.3)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.chalk.rawValue)
        XCTAssertEqual(appearance.textureParams.x, 1.2, accuracy: 0.001)
        XCTAssertEqual(appearance.textureParams.y, 0.3, accuracy: 0.001)
    }

    // MARK: Ink

    func testInkTextureMapsModeAndBleed() {
        var options = Options()
        options.brushTexture = .ink(bleed: 0.8)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.ink.rawValue)
        XCTAssertEqual(appearance.textureParams.x, 0.8, accuracy: 0.001,
                       "Ink stores bleed in component .x")
        XCTAssertEqual(appearance.textureParams.y, 0)
    }

    // MARK: Watercolor

    func testWatercolorTextureMapsModeAndParams() {
        var options = Options()
        options.brushTexture = .watercolor(edgeDarkness: 0.6, bleed: 0.5)

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.watercolor.rawValue)
        XCTAssertEqual(appearance.textureParams.x, 0.6, accuracy: 0.001,
                       "Watercolor stores edgeDarkness in .x")
        XCTAssertEqual(appearance.textureParams.y, 0.5, accuracy: 0.001,
                       "Watercolor stores bleed in .y")
    }

    // MARK: Texture is independent of color/opacity

    func testTextureModeDoesNotAffectColorResolution() {
        // Setting a texture should not perturb the color-along-path
        // resolution: the color/opacity uniforms come from
        // strokeColorAlongPath / strokeOpacityAlongPath as before.
        var options = Options()
        options.strokeColorAlongPath = .gradient(from: .red, to: .blue)
        options.brushTexture = .pencil()

        let appearance = RibbonAppearance.from(options: options)
        XCTAssertEqual(appearance.colorStart.x, 1, accuracy: 0.001) // red
        XCTAssertEqual(appearance.colorEnd.z,   1, accuracy: 0.001) // blue
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.pencil.rawValue)
    }

    // MARK: Default initializer params

    func testRibbonAppearanceDefaultsToSmoothWhenInitialized() {
        // Direct initialization without specifying texture should default
        // to smooth + zero params.
        let appearance = RibbonAppearance(
            colorStart: SIMD4<Float>(1, 1, 1, 1),
            colorEnd: SIMD4<Float>(1, 1, 1, 1),
            opacityScale: 1.0,
            edgeSoftness: 0
        )
        XCTAssertEqual(appearance.textureMode, RibbonTextureMode.smooth.rawValue)
        XCTAssertEqual(appearance.textureParams, .zero)
    }
}
