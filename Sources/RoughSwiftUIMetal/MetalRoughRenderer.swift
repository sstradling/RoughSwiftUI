//
//  MetalRoughRenderer.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Optional Metal-backed renderer for RoughSwiftUI. This proof-of-concept
//  implementation focuses on rendering stroke ribbons with along-path color
//  gradients — the workload that benefits most from a fragment-shader
//  approach. All other operation-set types (fill paths, hachure patterns,
//  SVG fills, scribble fills) are forwarded to the SwiftUI renderer's
//  command list and drawn via the standard CGContext path inside
//  `MetalRoughView`. This keeps feature parity at the cost of one CG layer
//  underneath the Metal layer for non-stroke geometry.
//

import Foundation
import CoreGraphics
import Metal
import MetalKit
import UIKit
import RoughSwiftUI

// MARK: - Public renderer

/// A Metal-backed implementation of `RoughRenderer`.
///
/// Conformance is provided so callers can substitute this renderer wherever
/// the SwiftUI renderer is accepted. The `commands(for:options:in:)` method
/// returns the *fallback* command list (everything that isn't a Metal-rendered
/// stroke), and `metalDrawList(for:options:in:)` returns a parallel list of
/// strokes that the Metal layer should rasterize. `MetalRoughView` invokes
/// both so that fills compose underneath strokes as expected.
public final class MetalRoughRenderer: RoughRenderer {

    /// The underlying GPU device. Supplied by the host view; rendering is a
    /// no-op when `nil` (e.g. on simulators without a Metal device).
    public let device: MTLDevice?

    /// Lazy pipeline factory. Pipelines are expensive to build, so they are
    /// memoized on the renderer instance.
    private let pipelineCache: PipelineCache?

    /// Renderer used to produce non-stroke commands (fills, hachure, etc.).
    private let fallback: SwiftUIRenderer

    /// Creates a renderer bound to the given device. Pass `MTLCreateSystemDefaultDevice()`
    /// from the host view; this initializer does not create a device itself
    /// so that callers retain control over device lifetime and can share one
    /// device across multiple renderers.
    public init(device: MTLDevice?) {
        self.device = device
        self.fallback = SwiftUIRenderer()
        if let d = device {
            self.pipelineCache = PipelineCache(device: d)
        } else {
            self.pipelineCache = nil
        }
    }

    // MARK: RoughRenderer

    /// Returns the SwiftUI commands for the *non-border* parts of the drawing.
    ///
    /// Border (`OperationSet.type == .path`) sets are intentionally omitted:
    /// those are rendered by the Metal pipeline via
    /// `metalDrawList(for:options:in:)`. Fill sketches, fill paths, SVG fills,
    /// and scribble fills all stay on the SwiftUI layer because they share
    /// the existing fill-pattern code (hachure, scribble, dots, …) which is
    /// not yet ported to Metal.
    ///
    /// Implementation: ask the fallback renderer for the commands of the
    /// full drawing and the commands of the border-only subset, then return
    /// the difference (preserving order). This delegates all SVG transform,
    /// stroke-alignment, and scribble-fill bookkeeping to `SwiftUIRenderer`
    /// without re-implementing it here.
    public func commands(
        for drawing: Drawing,
        options: Options,
        in size: CGSize
    ) -> [RoughRenderCommand] {
        let allCommands = fallback.commands(for: drawing, options: options, in: size)

        let borderSets = drawing.sets.filter { $0.type == .path }
        guard !borderSets.isEmpty else { return allCommands }

        // Ask the fallback how many commands the border sets alone produce.
        // The standard renderer emits border commands as the *last* sets in
        // its result (after scribble fill and after fill sketches), so we
        // can drop that many from the tail.
        let borderOnly = Drawing(shape: drawing.shape, sets: borderSets, options: options)
        let borderCount = fallback.commands(for: borderOnly, options: options, in: size).count
        guard borderCount > 0, borderCount <= allCommands.count else { return allCommands }
        return Array(allCommands.prefix(allCommands.count - borderCount))
    }

    /// Render via the SwiftUI fallback renderer. Provided for protocol
    /// conformance and for cases where a caller has a `GraphicsContext` but
    /// no `MTKView`. For full Metal-accelerated rendering use `MetalRoughView`.
    public func render(
        drawing: Drawing,
        options: Options,
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        fallback.render(drawing: drawing, options: options, in: &context, size: size)
    }

    // MARK: Metal draw list

    /// A single Metal-rendered stroke ribbon paired with its appearance.
    public struct RibbonDraw {
        public let mesh: RibbonMesh
        public let appearance: RibbonAppearance
    }

    /// Returns the list of stroke ribbons to be rendered by the Metal pipeline.
    public func metalDrawList(
        for drawing: Drawing,
        options: Options,
        in size: CGSize
    ) -> [RibbonDraw] {
        guard pipelineCache != nil else { return [] }

        var draws: [RibbonDraw] = []
        draws.reserveCapacity(drawing.sets.count)

        let strokeWidth = CGFloat(
            drawing.shape == "path" ? options.effectiveSVGStrokeWidth : options.strokeWidth
        )
        let baseAppearance = RibbonAppearance.from(options: options)

        for set in drawing.sets where set.type == .path {
            guard let mesh = RibbonMeshBuilder.build(
                operations: set.operations,
                baseWidth: strokeWidth
            ), !mesh.isEmpty else { continue }

            // SVG paths require an additional canvas-fitting transform that the
            // SwiftUI renderer applies to every command. For strokes coming
            // from non-SVG shapes the operations are already in canvas
            // coordinates and need no transform. Bake the SVG transform into
            // the mesh vertices so the Metal pass renders pixel-aligned with
            // the SwiftUI fill underneath.
            let transformed: RibbonMesh
            if drawing.shape == "path", let svg = set.path {
                let t = computeSVGTransform(svg, in: size)
                transformed = mesh.applying(t)
            } else {
                transformed = mesh
            }

            draws.append(RibbonDraw(mesh: transformed, appearance: baseAppearance))
        }

        return draws
    }

    // MARK: Pipeline access

    /// Returns the gradient-ribbon render pipeline state, building it on first
    /// access. Returns `nil` if no Metal device is available.
    public func gradientPipelineState(
        colorPixelFormat: MTLPixelFormat
    ) throws -> MTLRenderPipelineState? {
        try pipelineCache?.gradientPipeline(colorPixelFormat: colorPixelFormat)
    }

    // MARK: SVG transform (mirrors SwiftUIRenderer)

    private func computeSVGTransform(_ svg: String, in size: CGSize) -> CGAffineTransform {
        let bezier = UIBezierPath(svgPath: svg)
        let bounds = bezier.cgPath.boundingBox
        guard bounds.width > 0, bounds.height > 0 else { return .identity }

        let frame = CGRect(
            origin: .zero,
            size: CGSize(width: max(size.width, 1), height: max(size.height, 1))
        )
        let sw = frame.width / bounds.width
        let sh = frame.height / bounds.height
        let scale = min(sw, sh)
        let scaledWidth = bounds.width * scale
        let scaledHeight = bounds.height * scale
        let offsetX = (frame.width - scaledWidth) / 2 - bounds.minX * scale
        let offsetY = (frame.height - scaledHeight) / 2 - bounds.minY * scale
        return CGAffineTransform(a: scale, b: 0, c: 0, d: scale, tx: offsetX, ty: offsetY)
    }
}

// MARK: - Mesh transform

extension RibbonMesh {
    /// Returns a mesh with `transform` applied to every vertex position.
    /// Parametric coordinates are unaffected.
    func applying(_ transform: CGAffineTransform) -> RibbonMesh {
        var new = vertices
        for i in 0..<new.count {
            let p = CGPoint(x: CGFloat(new[i].position.x), y: CGFloat(new[i].position.y))
            let q = p.applying(transform)
            new[i].position = SIMD2<Float>(Float(q.x), Float(q.y))
        }
        return RibbonMesh(vertices: new, isClosed: isClosed, totalLength: totalLength)
    }
}

// MARK: - Pipeline cache

/// Caches `MTLRenderPipelineState` instances keyed by color pixel format.
///
/// Pipeline construction is one of the more expensive Metal operations; we
/// build one per pixel format and reuse it across draw calls.
final class PipelineCache {
    let device: MTLDevice
    let library: MTLLibrary?
    private var gradientByFormat: [Int: MTLRenderPipelineState] = [:]
    private let lock = NSLock()

    init(device: MTLDevice) {
        self.device = device
        // The package's `process` resource step compiles `RibbonShaders.metal`
        // into a `default.metallib` inside the bundle's resources directory.
        do {
            self.library = try device.makeDefaultLibrary(bundle: Bundle.module)
        } catch {
            // If shader compilation failed, fall back to nil; renderer will
            // simply produce no GPU output and callers can detect via the
            // pipeline factory returning nil.
            self.library = nil
        }
    }

    func gradientPipeline(colorPixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState? {
        lock.lock(); defer { lock.unlock() }

        let key = Int(colorPixelFormat.rawValue)
        if let cached = gradientByFormat[key] { return cached }

        guard let library = library else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "RoughSwiftUI.GradientRibbon"
        descriptor.vertexFunction = library.makeFunction(name: "ribbon_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "ribbon_fragment")

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<RibbonVertex>.stride
        descriptor.vertexDescriptor = vertexDescriptor

        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = colorPixelFormat
        attachment.isBlendingEnabled = true
        // Pre-multiplied source-over blending. The fragment shader pre-
        // multiplies its output, so source factor is `.one`.
        attachment.rgbBlendOperation = .add
        attachment.alphaBlendOperation = .add
        attachment.sourceRGBBlendFactor = .one
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha

        let state = try device.makeRenderPipelineState(descriptor: descriptor)
        gradientByFormat[key] = state
        return state
    }
}

// (UIBezierPath(svgPath:) is provided by the public surface of RoughSwiftUI.)
