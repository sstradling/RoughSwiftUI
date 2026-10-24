//
//  RoughRenderer.swift
//  RoughSwiftUI
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Renderer protocol abstracting the strategy used to turn a `Drawing` into
//  visible pixels. The default (and required) implementation is
//  `SwiftUIRenderer`, which targets `SwiftUI.Canvas`. Optional alternative
//  implementations (e.g. the Metal renderer in the `RoughSwiftUIMetal`
//  module) live outside this base library and conform to this protocol so
//  callers can swap renderers without changing call sites.
//

import SwiftUI
import CoreGraphics

/// A renderer capable of converting a generated `Drawing` into a sequence of
/// SwiftUI render commands or drawing them directly into a graphics context.
///
/// The protocol intentionally mirrors the existing public surface of
/// `SwiftUIRenderer` so that the default implementation conforms with no
/// behavior change. Alternative renderers (Metal, snapshot, debug) can
/// implement either or both methods; the SwiftUI command-based method is
/// required because it is also the unit of composability used by
/// `AnimatedRoughView` and the renderer-agnostic test suite.
///
/// ## Threading
///
/// The protocol does not impose any actor isolation; conforming types are
/// free to choose. `SwiftUIRenderer` is unisolated because it stores no
/// mutable state and is invoked from the main thread by `RoughView`. The
/// optional Metal renderer manages its own internal serialization via a
/// dispatch queue.
public protocol RoughRenderer {
    /// Build the list of `RoughRenderCommand`s representing the given drawing.
    ///
    /// This method is side-effect free and suitable for unit testing,
    /// snapshotting, and pre-computation (e.g. animation frame caching).
    ///
    /// - Parameters:
    ///   - drawing: The engine `Drawing` to render.
    ///   - options: The options that produced this drawing (renderers may need
    ///     access to fields like SVG stroke width that are not duplicated
    ///     inside `Drawing.options`).
    ///   - size: The available canvas size in points.
    /// - Returns: An ordered list of render commands.
    func commands(
        for drawing: Drawing,
        options: Options,
        in size: CGSize
    ) -> [RoughRenderCommand]

    /// Render a `Drawing` directly into a SwiftUI `GraphicsContext`.
    ///
    /// The default implementation builds commands via `commands(for:options:in:)`
    /// and replays them. Renderers backed by something other than SwiftUI's
    /// `Canvas` are not expected to implement this meaningfully and may treat
    /// it as a no-op or a fallback to the SwiftUI renderer.
    ///
    /// - Parameters:
    ///   - drawing: The engine `Drawing` to render.
    ///   - options: The options that produced this drawing.
    ///   - context: The SwiftUI graphics context to draw into (in/out).
    ///   - size: The available canvas size in points.
    func render(
        drawing: Drawing,
        options: Options,
        in context: inout GraphicsContext,
        size: CGSize
    )
}
