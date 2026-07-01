//
//  MetalRoughSnapshotRendererTests.swift
//  RoughSwiftUIMetalTests
//
//  Snapshot helper tests. These are written so they pass with or without a
//  Metal device: when no GPU/pipeline is available, the helper falls back to
//  full SwiftUI rendering and still returns a useful image.
//

import XCTest
import UIKit
@testable import RoughSwiftUI
@testable import RoughSwiftUIMetal

@MainActor
final class MetalRoughSnapshotRendererTests: XCTestCase {
    func testResolveScaleUsesExplicitValue() {
        XCTAssertEqual(MetalRoughSnapshotRenderer.resolveScale(3), 3)
    }

    func testResolveScaleDefaultsToPositiveValue() {
        XCTAssertGreaterThan(MetalRoughSnapshotRenderer.resolveScale(0), 0)
    }

    func testInvalidSizeThrows() async {
        let view = RoughView().rectangle()

        do {
            _ = try await MetalRoughSnapshotRenderer.image(
                for: view,
                size: .zero
            )
            XCTFail("Expected invalidSize error")
        } catch let error as MetalRoughSnapshotError {
            XCTAssertEqual(error, .invalidSize)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRendersImageWithRequestedSizeAndScale() async throws {
        let size = CGSize(width: 80, height: 40)
        let image = try await MetalRoughSnapshotRenderer.image(
            for: RoughView()
                .fill(.yellow)
                .stroke(.black)
                .rectangle(),
            size: size,
            scale: 2,
            backgroundColor: .white
        )

        XCTAssertEqual(image.size.width, size.width, accuracy: 0.001)
        XCTAssertEqual(image.size.height, size.height, accuracy: 0.001)
        XCTAssertEqual(image.scale, 2, accuracy: 0.001)
    }

    func testRoughViewConvenienceMatchesRequestedSize() async throws {
        let size = CGSize(width: 60, height: 60)
        let image = try await RoughView()
            .stroke(.black)
            .circle()
            .metalSnapshot(size: size, scale: 1)

        XCTAssertEqual(image.size.width, size.width, accuracy: 0.001)
        XCTAssertEqual(image.size.height, size.height, accuracy: 0.001)
    }

    func testRoughTextConvenienceUsesTypographicSize() async throws {
        let text = RoughText("Hi", font: .systemFont(ofSize: 24))
        let image = try await text.metalSnapshot(scale: 1)

        XCTAssertEqual(image.size.width, text.typographicSize.width, accuracy: 0.001)
        XCTAssertEqual(image.size.height, text.typographicSize.height, accuracy: 0.001)
    }
}
