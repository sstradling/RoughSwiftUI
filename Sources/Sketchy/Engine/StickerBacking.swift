//
//  StickerBacking.swift
//  Sketchy
//
//  Opt-in paper behind a drawing, like a die-cut sticker or a paper cutout.
//

import UIKit

/// How the paper edge is cut.
public enum StickerEdge: Equatable, Hashable, Sendable {
    /// A simplified offset of the contour. Corners keep a clamped miter so a
    /// star point stays a point; a miter longer than about 3.2 times the
    /// margin becomes a bevel.
    case smooth

    /// Chopped facets. `depth` of `0` uses 55% of the backing width, at least
    /// 3 points. The same `Options.seed` repeats the chops.
    case torn(StickerTear = StickerTear())
}

/// Facets along a torn or chopped paper edge.
///
/// `depth` is how far a facet may sit inside or outside the smooth contour,
/// in points. `0` asks the renderer to use `max(3, width * 0.55)`.
/// `length` is the nominal facet length in points. `jaggedness` (`0...1`)
/// adds smaller nicks on each facet.
public struct StickerTear: Equatable, Hashable, Sendable {
    /// Peak chip size in points. `0` selects an automatic depth from the width.
    public var depth: CGFloat

    /// Nominal length of one chopped facet, in points. Minimum 4.
    public var length: CGFloat

    /// Extra nicks along a facet, from 0 (flat chops) to 1.
    public var jaggedness: CGFloat

    public init(depth: CGFloat = 0, length: CGFloat = 16, jaggedness: CGFloat = 0.35) {
        self.depth = max(0, depth)
        self.length = max(4, length)
        self.jaggedness = min(1, max(0, jaggedness))
    }

    /// Depth in points. A stored `depth` of `0` follows the backing width.
    func resolvedDepth(width: CGFloat) -> CGFloat {
        if depth > 0 {
            return depth
        }
        return max(3, width * 0.55)
    }
}

/// Solid paper drawn behind a shape's fill and stroke.
///
/// Leave `Options.stickerBacking` nil to draw nothing extra. A value does not
/// change the generated outline or fill, and it does not consume `Options.seed`
/// for the sketch. Torn edges read that seed on their own.
///
/// `width` is the white (or `color`) margin past the nominal stroke, in
/// points. The sheet extends `width + strokeWidth / 2` from the outline
/// centerline, so the ink sits on the paper and the margin shows beyond it.
/// `smoothness` blends that contour from the rough outline (`0`) toward the
/// input silhouette (`1`): fine sketch wobble leaves, and a star stays a
/// star. `1` does not replace the shape with a blob. A shape with no
/// silhouette guide is simplified by the same amount instead.
///
/// Closed contours, including SVG subpaths and glyph outlines, become a filled
/// sheet. Holes stay holes (even-odd), with the same margin inside the cutout.
/// The second rough pass over the same contour is not a second sheet. Open
/// contours (lines, curves, open arcs, and legacy per-edge strokes) become a
/// paper ribbon of `strokeWidth + 2 * width` instead of a filled cutout.
/// `.strokeContinuity(.legacy)` is that open-edge case for rectangles and
/// polygons. Use `.continuous` (the default) for a die-cut sheet.
///
/// A notch tighter than the margin, or a torn edge that would cross itself,
/// does not emit a self-intersecting fill. The torn depth is reduced first.
/// If the outward offset still crosses, that closed contour is a round
/// dilation (filled centerline plus a round stroke) rather than a mitered ring.
public struct StickerBacking: Equatable, Hashable {
    /// Margin past the nominal stroke, in points. `0` draws no paper.
    public var width: CGFloat

    /// `0` follows the rough outline. `1` removes fine wobble and keeps the
    /// silhouette. Values outside `0...1` are clamped.
    public var smoothness: CGFloat

    /// Smooth die-cut edge, or chopped paper.
    public var edge: StickerEdge

    private var paperColor: RoughColor

    /// Paper color. Default is white. Alpha is honored.
    public var color: UIColor {
        get { paperColor.asUIColor }
        set { paperColor = RoughColor(uiColor: newValue) }
    }

    public init(
        width: CGFloat,
        smoothness: CGFloat = 0,
        edge: StickerEdge = .smooth,
        color: UIColor = .white
    ) {
        self.width = max(0, width)
        self.smoothness = min(1, max(0, smoothness))
        self.edge = Self.clamped(edge)
        self.paperColor = RoughColor(uiColor: color)
    }

    private static func clamped(_ edge: StickerEdge) -> StickerEdge {
        switch edge {
        case .smooth:
            return .smooth
        case .torn(let tear):
            return .torn(StickerTear(
                depth: tear.depth,
                length: tear.length,
                jaggedness: tear.jaggedness
            ))
        }
    }
}
