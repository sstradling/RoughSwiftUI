//
//  StrokeAppearance.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Types describing how a stroke's color and opacity vary along its length.
//
//  These types live in the base library (no Metal dependency) so that:
//    - The SwiftUI renderer can consume them and emit segmented fill
//      commands for the variable-color path (a future PR).
//    - The Metal renderer can consume them via `RibbonAppearance.from(options:)`
//      and drive the gradient/opacity-envelope fragment shader directly.
//
//  Both renderers see the same source of truth in `Options`, so a user
//  switching between `.metalAccelerated()` and the default renderer with
//  the same modifiers gets equivalent visual output (where supported).
//

import UIKit

// MARK: - Color along path

/// Describes how a stroke's color varies along its length parameter
/// `s ∈ [0, 1]`, where `0` is the start of the stroke and `1` is the end.
///
/// The renderer interprets `s` per stroke, not globally — a single
/// `ColorAlongPath` value applied to a polygon affects each stroke pass
/// independently (consistent with how `Options.stroke` already works).
public struct ColorAlongPath: Equatable, Hashable {

    /// The kind of color variation.
    public enum Kind: Equatable, Hashable, Sendable {
        /// Single solid color for the entire stroke. Equivalent to
        /// `Options.stroke` and provided for API completeness.
        case solid
        /// Linear gradient from start to end along `s ∈ [0, 1]`.
        case gradient
    }

    /// The variation kind.
    public let kind: Kind

    /// Color at `s = 0`. For `.solid`, the only color used.
    public let startColor: UIColor

    /// Color at `s = 1`. For `.solid`, equal to `startColor` and ignored.
    public let endColor: UIColor

    private init(kind: Kind, startColor: UIColor, endColor: UIColor) {
        self.kind = kind
        self.startColor = startColor
        self.endColor = endColor
    }

    /// A single solid color for the entire stroke.
    public static func solid(_ color: UIColor) -> ColorAlongPath {
        ColorAlongPath(kind: .solid, startColor: color, endColor: color)
    }

    /// A linear gradient from `start` (at `s = 0`) to `end` (at `s = 1`).
    public static func gradient(from start: UIColor, to end: UIColor) -> ColorAlongPath {
        ColorAlongPath(kind: .gradient, startColor: start, endColor: end)
    }

    // MARK: Equatable / Hashable

    /// Equality is delegated to `UIColor.isEqual(_:)` via the synthesized
    /// `==`. Two visually identical colors created from different color
    /// spaces may compare unequal; this matches the behavior of the
    /// existing `Options` color storage.
    public static func == (lhs: ColorAlongPath, rhs: ColorAlongPath) -> Bool {
        lhs.kind == rhs.kind
            && lhs.startColor.isEqual(rhs.startColor)
            && lhs.endColor.isEqual(rhs.endColor)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
        hasher.combine(startColor.hash)
        hasher.combine(endColor.hash)
    }
}

// MARK: - Opacity along path

/// Describes how a stroke's alpha multiplier varies along its length
/// parameter `s ∈ [0, 1]`. The result is multiplied by the per-fragment
/// color alpha; values are clamped to `[0, 1]`.
public enum OpacityAlongPath: Equatable, Hashable, Sendable {
    /// Constant opacity multiplier for the entire stroke.
    case constant(Float)

    /// Linear taper from `start` (at `s = 0`) to `end` (at `s = 1`).
    case taper(start: Float, end: Float)
}

// MARK: - Stroke edge softness

/// Controls how the stroke fades out across its width when rendered by
/// renderers that support per-pixel edge falloff (currently the Metal
/// renderer only).
///
/// `0` = hard edges (matches the SwiftUI renderer's default look).
/// `1` = full taper to zero alpha at the boundary, producing an ink-like
/// soft edge.
///
/// On the SwiftUI renderer this value is currently ignored; the SwiftUI
/// `Canvas` API does not expose a comparable per-pixel parameter, and the
/// equivalent effect would require multiple stroke passes at varying
/// opacities (planned as a separate texture mode in a later PR).
public typealias StrokeEdgeSoftness = Float
