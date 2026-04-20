//
//  MetalRoughView.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 04/20/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  SwiftUI host for the Metal-accelerated renderer.
//
//  Composition order (back to front):
//    1. SwiftUI `Canvas` for fills (hachure, scribble, solid SVG fill, etc.)
//    2. `MetalRibbonLayer` (UIViewRepresentable wrapping MTKView) for strokes
//
//  This preserves all existing fill behavior while routing stroke rendering
//  through Metal. Callers opt in by writing `myRoughView.metalAccelerated()`.
//

import SwiftUI
import UIKit
import MetalKit
import RoughSwiftUI

/// A SwiftUI view that renders a `RoughView`'s drawables using a hybrid
/// pipeline: SwiftUI `Canvas` for fills, Metal for stroke ribbons.
///
/// Use the `RoughView.metalAccelerated()` modifier to wrap a configured
/// `RoughView` in a `MetalRoughView`. The rendered output should be
/// visually equivalent to the SwiftUI-only renderer for default appearances
/// while opening the door to per-pixel along-path effects in future
/// shader-based work.
public struct MetalRoughView: View {

    /// The wrapped rough view holding the rendering options and drawables.
    public let roughView: RoughView

    public init(_ roughView: RoughView) {
        self.roughView = roughView
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                FillCanvas(roughView: roughView, size: size)
                MetalRibbonLayer(roughView: roughView, size: size)
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - SwiftUI fill layer

/// Shared device-less `MetalRoughRenderer` used by the SwiftUI fill
/// canvas. The fill canvas only needs the renderer's command-splitting
/// logic — it never invokes any Metal API — so we can use a single
/// global instance rather than allocating one per draw. Constructing a
/// renderer with `device: nil` is cheap (no pipeline cache); reusing
/// one avoids the per-frame allocation in tight redraw loops.
private let sharedFillRenderer = MetalRoughRenderer(device: nil)

/// SwiftUI canvas that draws only the *fill* commands of each drawable,
/// leaving strokes for the Metal layer above.
private struct FillCanvas: View {
    let roughView: RoughView
    let size: CGSize

    var body: some View {
        Canvas { context, canvasSize in
            let renderSize = canvasSize == .zero ? size : canvasSize
            guard renderSize.width > 0, renderSize.height > 0 else { return }

            let generator = Engine.shared.generator(size: renderSize)
            for drawable in roughView.drawables {
                guard let drawing = generator.generate(
                    drawable: drawable,
                    options: roughView.options
                ) else { continue }

                let commands = sharedFillRenderer.commands(
                    for: drawing,
                    options: roughView.options,
                    in: renderSize
                )
                for command in commands {
                    Self.draw(command: command, in: &context)
                }
            }
        }
    }

    /// Replays a single render command into the SwiftUI context. Mirrors the
    /// private `renderCommand` helper inside `SwiftUIRenderer`.
    private static func draw(command: RoughRenderCommand, in context: inout GraphicsContext) {
        if let clipPath = command.clipPath {
            var clipped = context
            if command.inverseClip {
                clipped.clip(to: clipPath, style: SwiftUI.FillStyle(eoFill: true), options: .inverse)
            } else {
                clipped.clip(to: clipPath, style: SwiftUI.FillStyle(eoFill: true))
            }
            apply(command, into: &clipped)
        } else {
            apply(command, into: &context)
        }
    }

    private static func apply(_ command: RoughRenderCommand, into context: inout GraphicsContext) {
        switch command.style {
        case let .stroke(color, lineWidth):
            let style = StrokeStyle(
                lineWidth: lineWidth,
                lineCap: command.cap.cgLineCap,
                lineJoin: command.join.cgLineJoin
            )
            context.stroke(command.path, with: .color(color), style: style)
        case let .fill(color):
            context.fill(command.path, with: .color(color), style: SwiftUI.FillStyle(eoFill: true))
        }
    }
}

// MARK: - Metal ribbon layer

/// `UIViewRepresentable` wrapping an `MTKView` that renders stroke ribbons
/// for the parent `RoughView`. Re-renders whenever the bound options or
/// drawables change.
private struct MetalRibbonLayer: UIViewRepresentable {

    let roughView: RoughView
    let size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator(roughView: roughView)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.framebufferOnly = false
        view.colorPixelFormat = .bgra8Unorm
        view.isOpaque = false
        view.backgroundColor = .clear
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.delegate = context.coordinator
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.roughView = roughView
        context.coordinator.lastSize = size
        uiView.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var roughView: RoughView
        weak var view: MTKView?
        var lastSize: CGSize = .zero
        private let renderer: MetalRoughRenderer
        private let commandQueue: MTLCommandQueue?

        init(roughView: RoughView) {
            self.roughView = roughView
            let device = MTLCreateSystemDefaultDevice()
            self.renderer = MetalRoughRenderer(device: device)
            self.commandQueue = device?.makeCommandQueue()
        }

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // `setNeedsDisplay()` is main-thread-safe because MTKView is a UIView.
            DispatchQueue.main.async {
                view.setNeedsDisplay()
            }
        }

        // `draw(in:)` is invoked on the main run loop because the MTKView
        // is paused and we trigger redraws via `setNeedsDisplay()`, which
        // schedules a draw on the next display tick on the main thread.
        // The body touches main-actor-isolated state (`Engine.shared`,
        // `roughView`), so we assert main-thread before assuming isolation —
        // this turns a silent corruption (if MetalKit ever calls us off-main)
        // into a loud crash with a useful stack trace.
        nonisolated func draw(in view: MTKView) {
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                self.drawOnMain(in: view)
            }
        }

        @MainActor
        private func drawOnMain(in view: MTKView) {
            guard let device = renderer.device,
                  let commandQueue = commandQueue,
                  let currentDrawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor
            else { return }

            // Use the host view's bounds rather than the drawable size for
            // canvas coordinates. The shader's projection matrix scales to
            // clip space using the *point* bounds, so vertex coordinates
            // produced by the renderer (also in points) line up exactly.
            let viewSize = view.bounds.size
            guard viewSize.width > 0, viewSize.height > 0 else { return }

            // Clear to transparent so the SwiftUI fill layer below shows.
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else { return }

            let pipeline: MTLRenderPipelineState?
            do {
                pipeline = try renderer.gradientPipelineState(colorPixelFormat: view.colorPixelFormat)
            } catch {
                pipeline = nil
            }

            if let pipeline = pipeline {
                encoder.setRenderPipelineState(pipeline)

                let generator = Engine.shared.generator(size: viewSize)
                for shape in roughView.drawables {
                    guard let drawing = generator.generate(
                        drawable: shape,
                        options: roughView.options
                    ) else { continue }

                    let draws = renderer.metalDrawList(
                        for: drawing,
                        options: roughView.options,
                        in: viewSize
                    )
                    for d in draws {
                        encode(draw: d, encoder: encoder, viewSize: viewSize, device: device)
                    }
                }
            }

            encoder.endEncoding()
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }

        private func encode(
            draw: MetalRoughRenderer.RibbonDraw,
            encoder: MTLRenderCommandEncoder,
            viewSize: CGSize,
            device: MTLDevice
        ) {
            guard !draw.mesh.vertices.isEmpty else { return }

            let bytesLength = MemoryLayout<RibbonVertex>.stride * draw.mesh.vertices.count
            guard let vertexBuffer = device.makeBuffer(
                bytes: draw.mesh.vertices,
                length: bytesLength,
                options: .storageModeShared
            ) else { return }
            encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

            // Projection: canvas points → clip space.
            // x_clip = (2 / width)  * x_pt - 1
            // y_clip = -(2 / height) * y_pt + 1   (flip Y so canvas-down → clip-up)
            var uniforms = RibbonUniforms(
                projectionScale: SIMD2<Float>(
                    Float(2.0 / viewSize.width),
                    Float(-2.0 / viewSize.height)
                ),
                projectionOffset: SIMD2<Float>(-1, 1),
                colorStart: draw.appearance.colorStart,
                colorEnd: draw.appearance.colorEnd,
                opacityScale: draw.appearance.opacityScale,
                edgeSoftness: draw.appearance.edgeSoftness,
                textureMode: draw.appearance.textureMode,
                textureParams: draw.appearance.textureParams
            )
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<RibbonUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RibbonUniforms>.stride, index: 1)

            encoder.drawPrimitives(
                type: .triangleStrip,
                vertexStart: 0,
                vertexCount: draw.mesh.vertices.count
            )
        }
    }
}

// MARK: - Uniforms

/// Mirrors the `RibbonUniforms` struct in `RibbonShaders.metal`. Field order
/// and packing must match exactly. The trailing `_pad` field aligns
/// `textureParams` (a `float4` in MSL, alignment 16) on the 16-byte
/// boundary after the two preceding `Int32`s.
struct RibbonUniforms {
    var projectionScale: SIMD2<Float>
    var projectionOffset: SIMD2<Float>
    var colorStart: SIMD4<Float>
    var colorEnd: SIMD4<Float>
    var opacityScale: Float
    var edgeSoftness: Float
    var textureMode: Int32
    var _pad: Int32 = 0
    var textureParams: SIMD4<Float>
}
