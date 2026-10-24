import CoreGraphics
import UIKit
import RoughSwiftUI

/// The v3g crayon duck: one shared fit, crayon outlines, a smooth eye, and scribble shadows.
///
/// The source is `seth-input-v3.svg` (viewBox 195×232). Bitmap `<use>` images are dropped.
/// Parts are drawn in source order. `pad` and `scale` match the rendered PNG.
enum CrayonDuckV3G {
    static let sourceOrder = [
        "left_foot", "body", "belly_shadow", "wing_shadow", "wing", "beak", "crest", "Eye", "right_foot"
    ]

    /// ViewBox padding, in source units, so the 15 pt stroke is not clipped.
    static let pad: CGFloat = 16

    /// Source units to canvas points.
    static let scale: CGFloat = 3

    static let viewBox = CGRect(x: 0, y: 0, width: 195, height: 232)

    static var canvasSize: CGSize {
        let fitted = viewBox.insetBy(dx: -pad, dy: -pad)
        return CGSize(width: fitted.width * scale, height: fitted.height * scale)
    }

    static var canvasTransform: CGAffineTransform {
        let fitted = viewBox.insetBy(dx: -pad, dy: -pad)
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: -fitted.minX * scale, ty: -fitted.minY * scale)
    }

    /// Outline crayon shared by every part except the eye and the shadows.
    static func baseOptions() -> Options {
        var options = Options()
        options.strokeWidth = 15
        options.roughness = 0.6
        options.maxRandomnessOffset = 0.5
        options.bowing = 0.15
        options.strokeOpacity = 1
        options.fillStyle = .solid
        options.fillOpacity = 1
        options.stroke = .black
        options.fill = .clear
        options.brushProfile = .crayon(
            grain: 0.2,
            edgeRoughness: 0.62,
            baseOpacity: 0.9,
            baseSoftness: 0.42,
            grit: 0.96,
            flakeSize: 1.2
        )
        return options
    }

    static func options(for name: String) -> Options {
        var options = baseOptions()
        let gold = color(0xF8CD5F)
        let darkGold = color(0xC7930C)
        switch name {
        case "left_foot":
            options.strokeWidth = 10
            options.fill = darkGold
        case "beak":
            options.strokeWidth = 9
            options.stroke = darkGold
            options.fill = gold
        case "Eye":
            options.fill = .black
            options.roughness = 0
            options.maxRandomnessOffset = 0
            options.bowing = 0
            options.brushProfile = .default
        case "right_foot":
            options.strokeWidth = 10
            options.fill = gold
        case "body", "wing":
            options.fill = color(0xFFFFFF)
        case "belly_shadow", "wing_shadow":
            options.fill = color(0xD7D1D8)
            options.fillStyle = .scribble
            options.scribbleTightness = 40
            options.scribbleOrigin = 100
            options.scribbleCurvature = 0
            options.scribbleUseBrushStroke = true
            options.fillWeight = 2.0
            options.fillOpacity = 0.9
            options.stroke = .clear
            options.strokeOpacity = 0
            options.brushProfile = .crayon(
                grain: 0.18,
                edgeRoughness: 0.85,
                widthVariation: 0.2,
                opacityVariation: 0.12,
                passes: 2,
                baseOpacity: 0.4,
                baseSoftness: 0.5,
                grit: 0.96,
                flakeSize: 1.8,
                seed: 5
            )
        case "crest":
            break
        default:
            preconditionFailure("Unexpected duck path \(name)")
        }
        return options
    }

    static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct CrayonDuckPart {
    var name: String
    var path: String
    var options: Options
}
