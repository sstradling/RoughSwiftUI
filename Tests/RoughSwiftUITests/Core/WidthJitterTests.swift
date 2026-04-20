//
//  WidthJitterTests.swift
//  RoughSwiftUITests
//
//  Verifies the WidthJitter type itself (parameter clamping, deterministic
//  noise, multiplier bounds) plus the Options field, cacheHash inclusion,
//  equality, and modifier wiring.
//

import XCTest
@testable import RoughSwiftUI

@MainActor
final class WidthJitterTests: XCTestCase {

    // MARK: - Construction and clamping

    func testDefaultsAreSubtleHandDrawnWobble() {
        let j = WidthJitter()
        XCTAssertEqual(j.amount, 0.15, accuracy: 0.001)
        XCTAssertEqual(j.frequency, 0.05, accuracy: 0.001)
        XCTAssertEqual(j.seed, 0)
    }

    func testNegativeAmountClampsToZero() {
        let j = WidthJitter(amount: -1, frequency: 0.05)
        XCTAssertEqual(j.amount, 0)
    }

    func testZeroFrequencyClampsToMin() {
        let j = WidthJitter(amount: 0.2, frequency: 0)
        XCTAssertGreaterThan(j.frequency, 0,
                             "Zero frequency must clamp away from 0 to avoid divide-by-zero")
    }

    // MARK: - Multiplier behavior

    func testMultiplierIsOneWhenAmountIsZero() {
        let j = WidthJitter(amount: 0)
        for length in stride(from: 0.0, through: 1000, by: 50) {
            XCTAssertEqual(j.multiplier(at: CGFloat(length)), 1.0, accuracy: 0.001,
                           "Zero-amount jitter must produce no modulation at length=\(length)")
        }
    }

    func testMultiplierStaysWithinBounds() {
        let j = WidthJitter(amount: 0.3, frequency: 0.1, seed: 42)
        for length in stride(from: 0.0, through: 1000, by: 7.5) {
            let m = j.multiplier(at: CGFloat(length))
            XCTAssertGreaterThanOrEqual(m, 0.7 - 0.001,
                                        "Multiplier out of bounds at length=\(length): \(m)")
            XCTAssertLessThanOrEqual(m, 1.3 + 0.001,
                                     "Multiplier out of bounds at length=\(length): \(m)")
        }
    }

    func testMultiplierIsDeterministic() {
        let a = WidthJitter(amount: 0.2, frequency: 0.05, seed: 7)
        let b = WidthJitter(amount: 0.2, frequency: 0.05, seed: 7)
        for length in stride(from: 0.0, through: 500, by: 13.7) {
            XCTAssertEqual(a.multiplier(at: CGFloat(length)),
                           b.multiplier(at: CGFloat(length)),
                           "Same seed must produce identical results")
        }
    }

    func testDifferentSeedsProduceDifferentSequences() {
        let a = WidthJitter(amount: 0.2, frequency: 0.05, seed: 1)
        let b = WidthJitter(amount: 0.2, frequency: 0.05, seed: 2)
        // Probabilistically: at least one sample in the range should differ.
        var anyDifferent = false
        for length in stride(from: 0.0, through: 500, by: 5) {
            if a.multiplier(at: CGFloat(length)) != b.multiplier(at: CGFloat(length)) {
                anyDifferent = true
                break
            }
        }
        XCTAssertTrue(anyDifferent,
                      "Different seeds should produce different noise sequences")
    }

    func testMultiplierVariesAcrossArcLength() {
        // For any non-zero-amount jitter, sampling at sufficiently
        // different arc lengths must produce a range of multiplier
        // values. The noise is smooth, so we sample at intervals larger
        // than one cycle to see real variation.
        let j = WidthJitter(amount: 0.25, frequency: 0.1, seed: 0)
        var samples: [CGFloat] = []
        // frequency=0.1 means one cycle per 1000 points; sample at 200 pt
        // intervals so we cover roughly 2 cycles in 10 samples.
        for length in stride(from: 0.0, through: 2000, by: 200) {
            samples.append(j.multiplier(at: CGFloat(length)))
        }
        let minMult = samples.min() ?? 1
        let maxMult = samples.max() ?? 1
        XCTAssertGreaterThan(maxMult - minMult, 0.05,
                             "Jittered multiplier must vary by at least 5% across 2 cycles; got [\(minMult), \(maxMult)]")
    }

    // MARK: - Options integration

    func testStrokeWidthJitterDefaultsToNil() {
        XCTAssertNil(Options().strokeWidthJitter)
    }

    func testStrokeWidthJitterIsPartOfCacheHash() {
        var a = Options()
        var b = Options()
        XCTAssertEqual(a.cacheHash, b.cacheHash)

        a.strokeWidthJitter = WidthJitter(amount: 0.2)
        XCTAssertNotEqual(a.cacheHash, b.cacheHash,
                          "cacheHash must include strokeWidthJitter")
    }

    func testWidthJitterEqualityRequiresAllFieldsMatch() {
        XCTAssertEqual(
            WidthJitter(amount: 0.2, frequency: 0.05, seed: 1),
            WidthJitter(amount: 0.2, frequency: 0.05, seed: 1)
        )
        XCTAssertNotEqual(
            WidthJitter(amount: 0.2, frequency: 0.05, seed: 1),
            WidthJitter(amount: 0.3, frequency: 0.05, seed: 1)
        )
        XCTAssertNotEqual(
            WidthJitter(amount: 0.2, frequency: 0.05, seed: 1),
            WidthJitter(amount: 0.2, frequency: 0.10, seed: 1)
        )
        XCTAssertNotEqual(
            WidthJitter(amount: 0.2, frequency: 0.05, seed: 1),
            WidthJitter(amount: 0.2, frequency: 0.05, seed: 2)
        )
    }

    // MARK: - Modifier wiring

    func testStrokeWidthJitterModifierSetsOption() {
        let view = RoughView().strokeWidthJitter(WidthJitter(amount: 0.3, frequency: 0.1, seed: 5))
        let j = view.options.strokeWidthJitter
        XCTAssertNotNil(j)
        XCTAssertEqual(j?.amount, 0.3, accuracy: 0.001)
        XCTAssertEqual(j?.frequency, 0.1, accuracy: 0.001)
        XCTAssertEqual(j?.seed, 5)
    }

    func testStrokeWidthJitterConvenienceConstructsValue() {
        let view = RoughView().strokeWidthJitter(amount: 0.2, frequency: 0.05, seed: 3)
        XCTAssertEqual(view.options.strokeWidthJitter,
                       WidthJitter(amount: 0.2, frequency: 0.05, seed: 3))
    }

    func testStrokeWidthJitterAcceptsNilToReset() {
        let view = RoughView()
            .strokeWidthJitter(amount: 0.2)
            .strokeWidthJitter(nil)
        XCTAssertNil(view.options.strokeWidthJitter)
    }
}
