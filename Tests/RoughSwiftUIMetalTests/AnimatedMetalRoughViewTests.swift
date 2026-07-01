//
//  AnimatedMetalRoughViewTests.swift
//  RoughSwiftUIMetalTests
//
//  CPU-safe tests for Metal animation support. The frame cache path works
//  with or without a GPU; without Metal it still precomputes fallback frames.
//

import XCTest
import SwiftUI
import UIKit
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

@MainActor
final class AnimatedMetalRoughViewTests: XCTestCase {
    func testMetalPathVarianceGeneratorDeterministicWithSameSeed() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .medium)
        let a = MetalPathVarianceGenerator(config: config, baseSeed: 123)
        let b = MetalPathVarianceGenerator(config: config, baseSeed: 123)

        let point = CGPoint(x: 50, y: 75)
        XCTAssertEqual(
            a.computeOffset(for: point, step: 0, index: 0),
            b.computeOffset(for: point, step: 0, index: 0)
        )
    }

    func testMetalPathVarianceGeneratorDifferentStepsDiffer() {
        let config = AnimationConfig(steps: 4, speed: .medium, variance: .high)
        let generator = MetalPathVarianceGenerator(config: config, baseSeed: 123)
        let point = CGPoint(x: 50, y: 75)

        XCTAssertNotEqual(
            generator.computeOffset(for: point, step: 0, index: 0),
            generator.computeOffset(for: point, step: 1, index: 0)
        )
    }

    func testFrameCachePrecomputesConfiguredStepCount() {
        let roughView = RoughView()
            .fill(UIColor.yellow)
            .rectangle()
        let config = AnimationConfig(steps: 5, speed: .medium, variance: .low)
        let size = CGSize(width: 120, height: 80)

        let cache = MetalAnimationFrameCache.precompute(
            roughView: roughView,
            config: config,
            size: size
        )

        XCTAssertEqual(cache.stepCount, 5)
        XCTAssertEqual(cache.size, size)
        XCTAssertFalse(cache.isEmpty)
    }

    func testFrameCacheSubscriptWrapsSteps() {
        let roughView = RoughView()
            .fill(UIColor.yellow)
            .rectangle()
        let config = AnimationConfig(steps: 3, speed: .medium, variance: .low)
        let cache = MetalAnimationFrameCache.precompute(
            roughView: roughView,
            config: config,
            size: CGSize(width: 120, height: 80)
        )

        XCTAssertEqual(cache[0].fallbackCommands.count, cache[3].fallbackCommands.count)
        XCTAssertEqual(cache[1].fallbackCommands.count, cache[4].fallbackCommands.count)
    }

    func testRoughViewMetalAnimatedModifierReturnsView() {
        let view = RoughView()
            .circle()
            .metalAnimated(steps: 6, speed: .slow, variance: .low)

        XCTAssertNotNil(view)
    }

    func testRoughTextMetalAnimatedModifierReturnsView() {
        let view = RoughText("Hi", font: .systemFont(ofSize: 24))
            .metalAnimated(steps: 6, speed: .slow, variance: .low)

        XCTAssertNotNil(view)
    }
}
