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
    /// - `ImageRenderer`-based snapshotting captures the SwiftUI fill layer
    ///   but may miss the Metal stroke layer depending on platform version;
    ///   prefer `UIGraphicsImageRenderer` when snapshotting Metal-accelerated
    ///   views.
    /// - The Metal renderer requires a Metal-capable device; on devices
    ///   without one, the stroke layer is a no-op (fills still render).
    ///
    /// - Returns: A `MetalRoughView` rendering this configuration.
    func metalAccelerated() -> MetalRoughView {
        MetalRoughView(self)
    }
}
