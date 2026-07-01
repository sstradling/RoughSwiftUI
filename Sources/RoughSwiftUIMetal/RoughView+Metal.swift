//
//  RoughView+Metal.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Opt-in modifier that wraps a `RoughView` in `MetalRoughView` so its
//  strokes are rendered through the Metal pipeline.
//

import SwiftUI
import RoughSwiftUI

public extension RoughText {
    /// Wraps this `RoughText` in a Metal-accelerated host view.
    ///
    /// Equivalent to `RoughView.metalAccelerated()`: stroke ribbons are
    /// rendered through the Metal pipeline while fills (hachure,
    /// scribble, dots, SVG fills) continue through SwiftUI `Canvas`.
    /// Text glyphs are SVG paths under the hood, so Metal stroke
    /// rendering applies to the glyph outlines exactly as it does to
    /// any other SVG path.
    ///
    /// The returned view preserves the text's typographic size, so it
    /// composes with surrounding SwiftUI layout exactly the same as a
    /// default `RoughText`.
    ///
    /// See `RoughView.metalAccelerated()` for the full tradeoff
    /// discussion (loss of SwiftUI compositing on the stroke layer,
    /// `ImageRenderer` snapshot caveats, no-op on devices without Metal).
    ///
    /// - Returns: A view rendering this text via the hybrid SwiftUI +
    ///   Metal pipeline, sized to match the underlying typographic
    ///   bounds.
    func metalAccelerated() -> some View {
        underlyingRoughView
            .metalAccelerated()
            .frame(width: typographicSize.width, height: typographicSize.height)
    }

    /// Wraps this `RoughText` in an animated Metal-accelerated host view.
    /// The returned view preserves this text's typographic size.
    func metalAnimated(config: AnimationConfig = .default) -> some View {
        underlyingRoughView
            .metalAnimated(config: config)
            .frame(width: typographicSize.width, height: typographicSize.height)
    }

    /// Convenience overload for animated Metal text.
    func metalAnimated(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    ) -> some View {
        metalAnimated(config: AnimationConfig(steps: steps, speed: speed, variance: variance))
    }
}

public extension RoughView {
    /// Wraps this `RoughView` in a Metal-accelerated host view.
    ///
    /// The returned view renders fills via SwiftUI `Canvas` (preserving full
    /// fill-style fidelity, including hachure, scribble, dots, and SVG fills)
    /// and renders strokes via a Metal fragment shader. For default
    /// appearances the visible output should match the SwiftUI-only renderer;
    /// the value of opting in comes from future per-pixel along-path effects
    /// (gradient color, opacity envelopes, procedural grain).
    ///
    /// ## Tradeoffs
    ///
    /// - This view hosts an `MTKView` internally, which is opaque to SwiftUI
    ///   compositing. Modifiers like `.opacity`, `.blur`, `.blendMode`, and
    ///   `.mask` applied *outside* this view operate on the rasterized
    ///   contents, not on the underlying paths.
    ///   For full SwiftUI compositing fidelity, omit `.metalAccelerated()`.
    /// - `ImageRenderer`-based snapshotting may miss the hosted Metal stroke
    ///   layer depending on platform version. Use `metalSnapshot(...)` or
    ///   `MetalRoughSnapshotRenderer.image(...)` for exports/share sheets.
    /// - The Metal renderer requires a Metal-capable device; on devices
    ///   without one, the stroke layer is a no-op (fills still render).
    ///
    /// - Returns: A `MetalRoughView` rendering this configuration.
    func metalAccelerated() -> MetalRoughView {
        MetalRoughView(self)
    }

    /// Wraps this `RoughView` in an animated Metal-accelerated host view.
    /// Fills are animated on SwiftUI Canvas; stroke ribbons are animated
    /// through precomputed Metal ribbon meshes.
    func metalAnimated(config: AnimationConfig = .default) -> AnimatedMetalRoughView {
        AnimatedMetalRoughView(config: config, roughView: self)
    }

    /// Convenience overload for animated Metal rendering.
    func metalAnimated(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    ) -> AnimatedMetalRoughView {
        AnimatedMetalRoughView(
            config: AnimationConfig(steps: steps, speed: speed, variance: variance),
            roughView: self
        )
    }
}
