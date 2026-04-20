//
//  RoughTextMetalTests.swift
//  RoughSwiftUIMetalTests
//
//  Verifies that RoughText.metalAccelerated() exists and that
//  RoughText exposes the underlying RoughView and typographic size
//  needed by alternate renderers.
//

import XCTest
import SwiftUI
import UIKit
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

@MainActor
final class RoughTextMetalTests: XCTestCase {

    func testRoughTextExposesUnderlyingRoughView() {
        let text = RoughText("Hello", font: .systemFont(ofSize: 24))
        // underlyingRoughView should yield a RoughView with the FullText
        // drawable applied. We check structurally rather than by content.
        XCTAssertFalse(text.underlyingRoughView.drawables.isEmpty,
                       "RoughText should expose its underlying RoughView with drawables")
    }

    func testRoughTextExposesTypographicSize() {
        let text = RoughText("Hi", font: .systemFont(ofSize: 32))
        XCTAssertGreaterThan(text.typographicSize.width, 0,
                             "Typographic size width must be positive for non-empty text")
        XCTAssertGreaterThan(text.typographicSize.height, 0,
                             "Typographic size height must be positive for non-empty text")
    }

    func testMetalAcceleratedReturnsAView() {
        // We can't easily inspect the returned `some View`, but we can
        // assert the call type-checks and produces a non-nil host. This
        // is the smoke test that .metalAccelerated() is wired up on
        // RoughText with the same signature as on RoughView.
        let text = RoughText("Test", font: .systemFont(ofSize: 16))
        let _ = text.metalAccelerated()
    }
}
