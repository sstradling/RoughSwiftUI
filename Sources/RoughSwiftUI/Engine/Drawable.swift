//
//  Drawable.swift
//  RoughSwift
//
//  Created by khoa on 26/03/2022.
//
//  Modifications Copyright © 2025 Seth Stradling. All rights reserved.
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

/// A text string rendered as a rough path at a fixed position.
///
/// This drawable converts text into SVG path data using CoreText glyph extraction,
/// then renders it through the rough.js engine for hand-drawn styling.
///
/// By default, text is positioned at the origin (0,0). For auto-centering within
/// the view bounds, use `FullText` instead (via `RoughView.text()`).
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

// MARK: - Text Alignment

/// Horizontal alignment options for text within a view.
public enum RoughTextHorizontalAlignment: Sendable {
    /// Align text to the leading (left) edge.
    case leading
    /// Center text horizontally.
    case center
    /// Align text to the trailing (right) edge.
    case trailing
}

/// Vertical alignment options for text within a view.
public enum RoughTextVerticalAlignment: Sendable {
    /// Align text to the top edge.
    case top
    /// Center text vertically.
    case center
    /// Align text to the bottom edge.
    case bottom
}

/// A text drawable that automatically positions within the available space.
///
/// This implements the `Fulfillable` protocol to receive the canvas size and
/// transform the text path based on alignment and offset settings. By default,
/// text is centered both horizontally and vertically.
///
/// ## Example - Centered Text (Default)
/// ```swift
/// RoughView()
///     .fill(.orange)
///     .stroke(.black)
///     .text("Hello!", font: .systemFont(ofSize: 48, weight: .bold))
///     .frame(width: 300, height: 100)
/// ```
///
/// ## Example - Custom Alignment
/// ```swift
/// RoughView()
///     .fill(.blue)
///     .text("Leading Top", font: .systemFont(ofSize: 24),
///           horizontalAlignment: .leading, verticalAlignment: .top)
///     .frame(width: 300, height: 100)
/// ```
///
/// ## Example - With Offset
/// ```swift
/// RoughView()
///     .fill(.green)
///     .text("Offset", font: .systemFont(ofSize: 32), offsetX: 10, offsetY: -5)
///     .frame(width: 200, height: 80)
/// ```
struct FullText: Drawable, Fulfillable {
    var method: String { "path" }
    var arguments: [Any] { [] }
    
    /// The CGPath containing the text glyph outlines.
    private let cgPath: CGPath
    
    /// Cached bounding box of the text path.
    private let bounds: CGRect
    
    /// Horizontal alignment within the canvas.
    let horizontalAlignment: RoughTextHorizontalAlignment
    
    /// Vertical alignment within the canvas.
    let verticalAlignment: RoughTextVerticalAlignment
    
    /// Additional horizontal offset in points (applied after alignment).
    let offsetX: CGFloat
    
    /// Additional vertical offset in points (applied after alignment).
    let offsetY: CGFloat
    
    /// Creates a positioned text drawable from a plain string and font.
    ///
    /// - Parameters:
    ///   - string: The text to render.
    ///   - font: The font to use for glyph extraction.
    ///   - horizontalAlignment: Horizontal alignment within the view. Default is `.center`.
    ///   - verticalAlignment: Vertical alignment within the view. Default is `.center`.
    ///   - offsetX: Additional horizontal offset in points. Default is `0`.
    ///   - offsetY: Additional vertical offset in points. Default is `0`.
    init(
        _ string: String,
        font: UIFont,
        horizontalAlignment: RoughTextHorizontalAlignment = .center,
        verticalAlignment: RoughTextVerticalAlignment = .center,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) {
        self.cgPath = TextPathConverter.path(from: string, font: font)
        self.bounds = cgPath.boundingBox
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
    
    /// Creates a positioned text drawable from an attributed string.
    ///
    /// The attributed string can contain multiple fonts, sizes, and other
    /// text attributes. All styling will be preserved in the glyph extraction.
    ///
    /// - Parameters:
    ///   - attributedString: The attributed string to render.
    ///   - horizontalAlignment: Horizontal alignment within the view. Default is `.center`.
    ///   - verticalAlignment: Vertical alignment within the view. Default is `.center`.
    ///   - offsetX: Additional horizontal offset in points. Default is `0`.
    ///   - offsetY: Additional vertical offset in points. Default is `0`.
    init(
        attributedString: NSAttributedString,
        horizontalAlignment: RoughTextHorizontalAlignment = .center,
        verticalAlignment: RoughTextVerticalAlignment = .center,
        offsetX: CGFloat = 0,
        offsetY: CGFloat = 0
    ) {
        self.cgPath = TextPathConverter.path(from: attributedString)
        self.bounds = cgPath.boundingBox
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
    
    /// Computes the SVG path string with alignment and offset transform applied.
    ///
    /// This method receives the canvas size and calculates the translation
    /// needed to position the text according to the alignment and offset settings.
    ///
    /// - Parameter size: The canvas/view size to position within.
    /// - Returns: An array containing the transformed SVG path string.
    func arguments(size: Size) -> [Any] {
        // Handle edge cases where bounds are invalid
        guard !bounds.isNull && !bounds.isInfinite && bounds.width > 0 && bounds.height > 0 else {
            return [cgPath.toSVGPathStringFlippingY()]
        }
        
        let canvasWidth = CGFloat(size.width)
        let canvasHeight = CGFloat(size.height)
        let textWidth = bounds.width
        let textHeight = bounds.height
        
        // Small inset to prevent clipping at edges
        let inset: CGFloat = 4
        
        // Calculate target X position based on horizontal alignment
        let targetX: CGFloat
        switch horizontalAlignment {
        case .leading:
            targetX = inset - bounds.minX
        case .center:
            targetX = (canvasWidth - textWidth) / 2 - bounds.minX
        case .trailing:
            targetX = canvasWidth - textWidth - inset - bounds.minX
        }
        
        // Calculate target Y position based on vertical alignment
        // Note: After Y-flip, positive Y is down, so we calculate accordingly
        let targetY: CGFloat
        switch verticalAlignment {
        case .top:
            targetY = inset
        case .center:
            targetY = (canvasHeight - textHeight) / 2
        case .bottom:
            targetY = canvasHeight - textHeight - inset
        }
        
        // Build the transform:
        // 1. Translate to move bounds origin to (0, 0)
        // 2. Flip Y axis (CoreText uses bottom-up, SVG uses top-down)
        // 3. Translate to target position
        // 4. Apply user offset
        var transform = CGAffineTransform.identity
        
        // Final position with offset
        let finalX = targetX + offsetX
        let finalY = targetY + offsetY
        
        // Combined transform: translate to target, flip Y, then translate from bounds
        // Applied in reverse order:
        // - First: translate bounds.minX/minY to origin
        // - Second: flip Y around the text center
        // - Third: translate to final position
        transform = transform.translatedBy(x: finalX + textWidth / 2, y: finalY + textHeight / 2)
        transform = transform.scaledBy(x: 1, y: -1)
        transform = transform.translatedBy(x: -bounds.midX, y: -bounds.midY)
        
        return [cgPath.toSVGPathString(applying: transform)]
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

// MARK: - Rounded Rectangle

/// A rectangle with rounded corners drawn with a rough, hand-drawn style.
///
/// The corner radius is applied uniformly to all four corners. If the radius
/// exceeds half the width or height, it will be clamped to create a valid shape.
public struct RoundedRectangle: Drawable {
    public var method: String { "roundedRectangle" }

    public var arguments: [Any] {
        [
            x, y, width, height, cornerRadius
        ]
    }

    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let cornerRadius: Float

    /// Creates a rounded rectangle drawable.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate of the top-left corner.
    ///   - y: The y-coordinate of the top-left corner.
    ///   - width: The width of the rectangle.
    ///   - height: The height of the rectangle.
    ///   - cornerRadius: The radius of the rounded corners.
    public init(
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        cornerRadius: Float
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }
}

/// A full-size rounded rectangle that fills the available space.
struct FullRoundedRectangle: Drawable, Fulfillable {
    var method: String { "roundedRectangle" }
    var arguments: [Any] { [] }
    
    let cornerRadius: Float
    
    init(cornerRadius: Float = 8) {
        self.cornerRadius = cornerRadius
    }
    
    func arguments(size: Size) -> [Any] {
        // Inset slightly so the rough strokes (randomness + stroke width)
        // don't get clipped by the canvas edges.
        let inset: Float = 4
        let w = max(0, size.width - inset * 2)
        let h = max(0, size.height - inset * 2)
        return [
            inset, inset, w, h, cornerRadius
        ]
    }
}

// MARK: - Egg Shape

/// An egg-shaped (ovoid) drawable with a rough, hand-drawn style.
///
/// The egg shape is asymmetric, with a wider bottom and narrower top (or vice versa
/// depending on the tilt parameter). This creates a natural egg appearance.
public struct EggShape: Drawable {
    public var method: String { "egg" }

    public var arguments: [Any] {
        [
            x, y, width, height, tilt
        ]
    }

    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let tilt: Float

    /// Creates an egg-shaped drawable.
    ///
    /// - Parameters:
    ///   - x: The x-coordinate of the center.
    ///   - y: The y-coordinate of the center.
    ///   - width: The width of the egg at its widest point.
    ///   - height: The total height of the egg.
    ///   - tilt: Controls the asymmetry of the egg. Positive values make the top narrower,
    ///           negative values make the bottom narrower. Default is 0.3 for a natural egg shape.
    public init(
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        tilt: Float = 0.3
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.tilt = tilt
    }
}

/// A full-size egg that fills the available space.
struct FullEgg: Drawable, Fulfillable {
    var method: String { "egg" }
    var arguments: [Any] { [] }
    
    let tilt: Float
    
    init(tilt: Float = 0.3) {
        self.tilt = tilt
    }
    
    func arguments(size: Size) -> [Any] {
        // Inset slightly so the rough strokes (randomness + stroke width)
        // don't get clipped by the canvas edges.
        let inset: Float = 4
        let w = max(0, size.width - inset * 2)
        let h = max(0, size.height - inset * 2)
        return [
            size.width / 2, size.height / 2, w, h, tilt
        ]
    }
}
