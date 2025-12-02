//
//  Drawable.swift
//  RoughSwift
//
//  Created by khoa on 26/03/2022.
//

import Foundation
import UIKit

public protocol Drawable {
    var method: String { get }
    var arguments: [Any] { get }
}

public struct Line: Drawable {
    public var method: String { "line" }

    public var arguments: [Any] {
        [
            from.x, from.y, to.x, to.y
        ]
    }

    public let from: Point
    public let to: Point

    public init(from: Point, to: Point) {
        self.from = from
        self.to = to
    }
}

public struct Rectangle: Drawable {
    public var method: String { "rectangle" }

    public var arguments: [Any] {
        [
            x, y, width, height,
        ]
    }

    let x: Float
    let y: Float
    let width: Float
    let height: Float

    public init(
        x: Float,
        y: Float,
        width: Float,
        height: Float
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct Ellipse: Drawable {
    public var method: String { "ellipse" }

    public var arguments: [Any] {
        [
            x, y, width, height,
        ]
    }

    let x: Float
    let y: Float
    let width: Float
    let height: Float

    public init(
        x: Float,
        y: Float,
        width: Float,
        height: Float
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct Circle: Drawable {
    public var method: String { "circle" }
    
    public var arguments: [Any] {
        [
            x, y, diameter
        ]
    }
    
    let x: Float
    let y: Float
    let diameter: Float

    public init(
        x: Float,
        y: Float,
        diameter: Float
    ) {
        self.x = x
        self.y = y
        self.diameter = diameter
    }
}

public struct LinearPath: Drawable {
    public var method: String { "linearPath" }

    public var arguments: [Any] {
        points.map({ $0.toRoughPoint() })
    }

    let points: [Point]

    public init(
        points: [Point]
    ) {
        self.points = points
    }
}

public struct Arc: Drawable {
    public var method: String { "arc" }
    
    public var arguments: [Any] {
        [
            x, y, width, height,
            start, stop, closed
        ]
    }

    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let start: Float
    let stop: Float
    var closed: Bool

    public init(
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        start: Float,
        stop: Float,
        closed: Bool = false
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.start = start
        self.stop = stop
        self.closed = closed
    }
}

public struct Curve: Drawable {
    public var method: String { "curve" }

    public var arguments: [Any] {
        points.map({ $0.toRoughPoint() })
    }

    let points: [Point]

    public init(
        points: [Point]
    ) {
        self.points = points
    }
}

public struct Polygon: Drawable {
    public var method: String { "polygon" }

    public var arguments: [Any] {
        points.map({ $0.toRoughPoint() })
    }

    let points: [Point]

    public init(
        points: [Point]
    ) {
        self.points = points
    }
}

public struct Path: Drawable {
    public var method: String { "path" }

    public var arguments: [Any] {
        [
            d
        ]
    }

    let d: String

    public init(
        d: String
    ) {
        self.d = d
    }
}

/// A text string rendered as a rough path.
///
/// This drawable converts text into SVG path data using CoreText glyph extraction,
/// then renders it through the rough.js engine for hand-drawn styling.
public struct Text: Drawable {
    public var method: String { "path" }
    
    public var arguments: [Any] {
        [svgPath]
    }
    
    let svgPath: String
    
    /// Create a rough text drawable from a plain string and font.
    ///
    /// - Parameters:
    ///   - string: The text to render.
    ///   - font: The font to use for glyph extraction.
    public init(_ string: String, font: UIFont) {
        let cgPath = TextPathConverter.path(from: string, font: font)
        // Flip Y axis since CoreText uses bottom-up coordinates
        self.svgPath = cgPath.toSVGPathStringFlippingY()
    }
    
    /// Create a rough text drawable from an `NSAttributedString`.
    ///
    /// The attributed string can contain multiple fonts, sizes, and other text attributes.
    /// All styling will be preserved in the glyph extraction.
    ///
    /// - Parameter attributedString: The attributed string to render.
    public init(attributedString: NSAttributedString) {
        let cgPath = TextPathConverter.path(from: attributedString)
        // Flip Y axis since CoreText uses bottom-up coordinates
        self.svgPath = cgPath.toSVGPathStringFlippingY()
    }
    
    /// Create a rough text drawable from an SVG path string directly.
    ///
    /// This is useful if you've already converted text to SVG elsewhere.
    ///
    /// - Parameter svgPath: The SVG path string (d attribute format).
    public init(svgPath: String) {
        self.svgPath = svgPath
    }
}

protocol Fulfillable {
    func arguments(size: Size) -> [Any]
}

struct FullRectangle: Drawable, Fulfillable {
    var method: String { "rectangle"}
    var arguments: [Any] { [] }
    func arguments(size: Size) -> [Any] {
        // Inset slightly so the rough strokes (randomness + stroke width)
        // don't get clipped by the canvas edges.
        let inset: Float = 4
        let w = max(0, size.width - inset * 2)
        let h = max(0, size.height - inset * 2)
        return [
            inset, inset, w, h
        ]
    }
}

struct FullCircle: Drawable, Fulfillable {
    var method: String { "circle" }
    var arguments: [Any] { [] }

    func arguments(size: Size) -> [Any] {
        // Inset slightly so the rough strokes (randomness + stroke width)
        // don't get clipped by the canvas edges.
        let inset: Float = 4
        let diameter = max(0, min(size.width, size.height) - inset * 2)
        return [
            size.width / 2, size.height / 2, diameter
        ]
    }
}
