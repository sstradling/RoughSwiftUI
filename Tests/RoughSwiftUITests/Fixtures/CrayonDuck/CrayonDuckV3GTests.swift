import UIKit
import XCTest
@testable import RoughSwiftUI

@MainActor
final class CrayonDuckV3GTests: XCTestCase {

    func testV3GOptions() {
        let eye = CrayonDuckV3G.options(for: "Eye")
        XCTAssertEqual(eye.roughness, 0)
        XCTAssertEqual(eye.maxRandomnessOffset, 0)
        XCTAssertEqual(eye.bowing, 0)
        XCTAssertNil(eye.brushProfile.crayon)
        XCTAssertEqual(eye.strokeWidth, 15)
        XCTAssertEqual(eye.fillStyle, .solid)

        let shadow = CrayonDuckV3G.options(for: "belly_shadow")
        XCTAssertEqual(shadow.fillStyle, .scribble)
        XCTAssertEqual(shadow.scribbleCurvature, 0)
        XCTAssertEqual(shadow.scribbleTightness, 40)
        XCTAssertEqual(shadow.scribbleOrigin, 100)
        XCTAssertEqual(shadow.fillWeight, 2)
        XCTAssertEqual(shadow.fillOpacity, 0.9)
        XCTAssertEqual(shadow.strokeOpacity, 0)
        XCTAssertNotNil(shadow.brushProfile.crayon)

        let wing = CrayonDuckV3G.options(for: "wing_shadow")
        XCTAssertEqual(wing.scribbleOrigin, shadow.scribbleOrigin)
        XCTAssertEqual(wing.scribbleTightness, shadow.scribbleTightness)
        XCTAssertEqual(wing.scribbleCurvature, shadow.scribbleCurvature)

        XCTAssertEqual(CrayonDuckV3G.pad, 16)
        XCTAssertEqual(CrayonDuckV3G.scale, 3)
        XCTAssertEqual(CrayonDuckV3G.options(for: "body").brushProfile.crayon?.baseOpacity, 0.9)
        XCTAssertEqual(CrayonDuckV3G.options(for: "beak").strokeWidth, 9)
        XCTAssertEqual(CrayonDuckV3G.options(for: "left_foot").strokeWidth, 10)
    }

    func testRenderV3GDuck() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "seth-input-v3", withExtension: "svg"))
        let svg = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        let collector = try CrayonDuckSVG.parse(svg)
        XCTAssertEqual(collector.shapes.count, 9)
        XCTAssertEqual(collector.droppedImages.count, 7)
        XCTAssertEqual(collector.droppedUses.count, 7)

        let parts: [CrayonDuckPart] = collector.shapes.map { shape in
            let bezier = UIBezierPath(svgPath: shape.d)
            bezier.apply(shape.ctm)
            return CrayonDuckPart(
                name: shape.name,
                path: bezier.cgPath.toSVGPathString(precision: 3),
                options: CrayonDuckV3G.options(for: shape.name)
            )
        }
        XCTAssertEqual(parts.map(\.name), CrayonDuckV3G.sourceOrder)

        let image = CrayonDuckRenderer.image(parts: parts)
        let onWhite = CrayonDuckRenderer.composited(image, on: .white)
        XCTAssertEqual(onWhite.size, CrayonDuckV3G.canvasSize)

        let corner = pixel(onWhite, x: 0, y: 0)
        XCTAssertEqual(corner.0, 255)
        XCTAssertEqual(corner.1, 255)
        XCTAssertEqual(corner.2, 255)
        XCTAssertEqual(corner.3, 255)
        let clearCorner = pixel(image, x: 0, y: 0)
        XCTAssertEqual(clearCorner.3, 0)

        let counts = colorCounts(onWhite)
        XCTAssertGreaterThan(counts.gold, 400)
        XCTAssertGreaterThan(counts.darkGold, 200)
        XCTAssertGreaterThan(counts.shadow, 80)
    }

    private func pixel(_ image: UIImage, x: Int, y: Int) -> (Int, Int, Int, Int) {
        guard let cgImage = image.cgImage else { return (0, 0, 0, 0) }
        var data = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &data,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.draw(cgImage, in: CGRect(x: -x, y: -y, width: cgImage.width, height: cgImage.height))
        return (Int(data[0]), Int(data[1]), Int(data[2]), Int(data[3]))
    }

    private func colorCounts(_ image: UIImage) -> (gold: Int, darkGold: Int, shadow: Int) {
        guard let cgImage = image.cgImage else { return (0, 0, 0) }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0, 0, 0)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        var gold = 0
        var darkGold = 0
        var shadow = 0
        var index = 0
        while index < pixels.count {
            let red = Int(pixels[index])
            let green = Int(pixels[index + 1])
            let blue = Int(pixels[index + 2])
            let alpha = pixels[index + 3]
            if alpha > 16 && (red < 250 || green < 250 || blue < 250) {
                if near(red, 248, green, 205, blue, 95) { gold += 1 }
                else if near(red, 199, green, 147, blue, 12) { darkGold += 1 }
                else if near(red, 215, green, 209, blue, 216) { shadow += 1 }
            }
            index += 4
        }
        return (gold, darkGold, shadow)
    }

    private func near(_ red: Int, _ targetRed: Int, _ green: Int, _ targetGreen: Int, _ blue: Int, _ targetBlue: Int) -> Bool {
        abs(red - targetRed) <= 12 && abs(green - targetGreen) <= 12 && abs(blue - targetBlue) <= 12
    }
}
