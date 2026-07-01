//
//  MetalRoughSnapshotRenderer.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 07/01/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Offscreen snapshot support for Metal-accelerated rough views.
//
//  SwiftUI's `ImageRenderer` may miss `MTKView` contents because the
//  Metal layer is hosted outside the normal SwiftUI display-list pipeline.
//  This helper renders the same hybrid pipeline explicitly:
//
//    1. SwiftUI fallback/fill commands -> CGContext via UIGraphicsImageRenderer
//    2. Metal stroke ribbons -> offscreen MTLTexture
//    3. Composite texture image over fallback image
//

import CoreGraphics
import Metal
import UIKit
import RoughSwiftUI

// MARK: - Errors

/// Errors that can occur while rendering a Metal-accelerated snapshot.
public enum MetalRoughSnapshotError: Error, Equatable {
    /// The requested image size was empty or negative.
    case invalidSize

    /// A Metal command queue could not be created from the device.
    case missingCommandQueue

    /// A render target texture could not be created.
    case missingTexture

    /// A render command buffer or encoder could not be created.
    case missingCommandEncoder

    /// The Metal render command buffer completed with an error.
    case commandBufferFailed

    /// The rendered Metal texture could not be converted to a `UIImage`.
    case textureReadbackFailed
}

// MARK: - Snapshot renderer

/// Renders `RoughView` content into `UIImage` using the same hybrid
/// SwiftUI+Metal composition as `MetalRoughView`.
///
/// Use this instead of `ImageRenderer` when snapshotting views wrapped in
/// `.metalAccelerated()`. `ImageRenderer` is excellent for pure SwiftUI
/// content but may not capture hosted `MTKView` contents on every platform
/// version.
@MainActor
public enum MetalRoughSnapshotRenderer {

    /// Renders a snapshot of `roughView`.
    ///
    /// - Parameters:
    ///   - roughView: The configured `RoughView` to render.
    ///   - size: Output size in points. Must be positive.
    ///   - scale: Output scale. Pass `0` (default) to use
    ///     `UIGraphicsImageRendererFormat.default().scale`.
    ///   - backgroundColor: Optional background fill. `nil` produces a
    ///     transparent image.
    /// - Returns: A rendered image containing fills and strokes.
    public static func image(
        for roughView: RoughView,
        size: CGSize,
        scale: CGFloat = 0,
        backgroundColor: UIColor? = nil
    ) async throws -> UIImage {
        try imageSync(
            for: roughView,
            size: size,
            scale: scale,
            backgroundColor: backgroundColor
        )
    }

    /// Synchronous implementation used by the async public API and by tests.
    /// The Metal command buffer is explicitly waited on before readback.
    static func imageSync(
        for roughView: RoughView,
        size: CGSize,
        scale: CGFloat = 0,
        backgroundColor: UIColor? = nil
    ) throws -> UIImage {
        guard size.width > 0, size.height > 0 else {
            throw MetalRoughSnapshotError.invalidSize
        }

        let resolvedScale = resolveScale(scale)
        let device = MTLCreateSystemDefaultDevice()
        let renderer = MetalRoughRenderer(device: device)
        let canRenderMetal: Bool
        if device != nil {
            canRenderMetal = ((try? renderer.gradientPipelineState(colorPixelFormat: .bgra8Unorm)) != nil)
        } else {
            canRenderMetal = false
        }

        let fallbackImage = renderFallbackImage(
            roughView: roughView,
            size: size,
            scale: resolvedScale,
            backgroundColor: backgroundColor,
            renderer: canRenderMetal ? renderer : nil
        )

        guard let device, canRenderMetal else {
            // No GPU: return a full SwiftUI-rendered snapshot so callers
            // still get a useful image (without Metal-only shader effects).
            // Same fallback applies if the Metal shader library/pipeline
            // could not be created.
            return fallbackImage
        }

        let metalImage = try renderMetalImage(
            roughView: roughView,
            size: size,
            scale: resolvedScale,
            device: device,
            renderer: renderer
        )

        return composite(
            bottom: fallbackImage,
            top: metalImage,
            size: size,
            scale: resolvedScale
        )
    }

    /// Resolves `scale = 0` to the system default renderer scale.
    static func resolveScale(_ scale: CGFloat) -> CGFloat {
        if scale > 0 { return scale }
        let format = UIGraphicsImageRendererFormat.default()
        return max(1, format.scale)
    }

    // MARK: - Fallback/fill rendering

    private static func renderFallbackImage(
        roughView: RoughView,
        size: CGSize,
        scale: CGFloat,
        backgroundColor: UIColor?,
        renderer metalRenderer: MetalRoughRenderer?
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = backgroundColor != nil

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cgContext = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)

            if let backgroundColor {
                cgContext.setFillColor(backgroundColor.cgColor)
                cgContext.fill(bounds)
            }

            let generator = Engine.shared.generator(size: size)
            let swiftRenderer = SwiftUIRenderer()

            for drawable in roughView.drawables {
                guard let drawing = generator.generate(
                    drawable: drawable,
                    options: roughView.options
                ) else { continue }

                let commands: [RoughRenderCommand]
                if let metalRenderer {
                    // Device available: draw only SwiftUI fallback commands
                    // (fills and brush-profile fallback borders). Metal
                    // border ribbons are composited in a second pass.
                    commands = metalRenderer.commands(
                        for: drawing,
                        options: roughView.options,
                        in: size
                    )
                } else {
                    // No Metal device: use the full SwiftUI renderer so
                    // strokes are still present in the snapshot.
                    commands = swiftRenderer.commands(
                        for: drawing,
                        options: roughView.options,
                        in: size
                    )
                }

                for command in commands {
                    draw(command: command, in: cgContext, bounds: bounds)
                }
            }
        }
    }

    /// Draws a single `RoughRenderCommand` into a CoreGraphics context.
    /// Mirrors the private rendering logic in `SwiftUIRenderer`, translated
    /// from `GraphicsContext` to `CGContext`.
    static func draw(command: RoughRenderCommand, in context: CGContext, bounds: CGRect) {
        context.saveGState()
        defer { context.restoreGState() }

        if let clipPath = command.clipPath {
            if command.inverseClip {
                let inverse = CGMutablePath()
                inverse.addRect(bounds)
                inverse.addPath(clipPath.cgPath)
                context.addPath(inverse)
                context.clip(using: .evenOdd)
            } else {
                context.addPath(clipPath.cgPath)
                context.clip(using: .evenOdd)
            }
        }

        switch command.style {
        case let .stroke(color, lineWidth):
            context.addPath(command.path.cgPath)
            context.setStrokeColor(UIColor(color).cgColor)
            context.setLineWidth(lineWidth)
            context.setLineCap(command.cap.cgLineCap)
            context.setLineJoin(command.join.cgLineJoin)
            context.strokePath()

        case let .fill(color):
            context.addPath(command.path.cgPath)
            context.setFillColor(UIColor(color).cgColor)
            context.fillPath(using: .evenOdd)
        }
    }

    // MARK: - Metal rendering

    private static func renderMetalImage(
        roughView: RoughView,
        size: CGSize,
        scale: CGFloat,
        device: MTLDevice,
        renderer: MetalRoughRenderer
    ) throws -> UIImage {
        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalRoughSnapshotError.missingCommandQueue
        }

        let pixelWidth = max(1, Int((size.width * scale).rounded(.up)))
        let pixelHeight = max(1, Int((size.height * scale).rounded(.up)))

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelWidth,
            height: pixelHeight,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]
        textureDescriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw MetalRoughSnapshotError.missingTexture
        }

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) else {
            throw MetalRoughSnapshotError.missingCommandEncoder
        }

        if let pipeline = try renderer.gradientPipelineState(colorPixelFormat: textureDescriptor.pixelFormat) {
            encoder.setRenderPipelineState(pipeline)

            let generator = Engine.shared.generator(size: size)
            for drawable in roughView.drawables {
                guard let drawing = generator.generate(drawable: drawable, options: roughView.options) else {
                    continue
                }

                for draw in renderer.metalDrawList(for: drawing, options: roughView.options, in: size) {
                    encode(draw: draw, encoder: encoder, viewSize: size, device: device)
                }
            }
        }

        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        guard commandBuffer.status == .completed else {
            throw MetalRoughSnapshotError.commandBufferFailed
        }

        return try image(from: texture, scale: scale)
    }

    private static func encode(
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
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: draw.mesh.vertices.count)
    }

    private static func image(from texture: MTLTexture, scale: CGFloat) throws -> UIImage {
        let bytesPerPixel = 4
        let bytesPerRow = texture.width * bytesPerPixel
        var data = [UInt8](repeating: 0, count: bytesPerRow * texture.height)

        texture.getBytes(
            &data,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height),
            mipmapLevel: 0
        )

        let provider = CGDataProvider(data: Data(data) as CFData)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )

        guard let provider,
              let cgImage = CGImage(
                width: texture.width,
                height: texture.height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw MetalRoughSnapshotError.textureReadbackFailed
        }

        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    // MARK: - Compositing

    private static func composite(bottom: UIImage, top: UIImage, size: CGSize, scale: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            bottom.draw(in: CGRect(origin: .zero, size: size))
            top.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Convenience APIs

public extension RoughView {
    /// Renders this `RoughView` using the Metal-accelerated snapshot helper.
    ///
    /// Use this instead of SwiftUI `ImageRenderer` when the view is normally
    /// displayed with `.metalAccelerated()`, because `ImageRenderer` may miss
    /// the hosted `MTKView` stroke layer on some platform versions.
    @MainActor
    func metalSnapshot(
        size: CGSize,
        scale: CGFloat = 0,
        backgroundColor: UIColor? = nil
    ) async throws -> UIImage {
        try await MetalRoughSnapshotRenderer.image(
            for: self,
            size: size,
            scale: scale,
            backgroundColor: backgroundColor
        )
    }
}

public extension MetalRoughView {
    /// Renders this `MetalRoughView` into a `UIImage` using the same hybrid
    /// SwiftUI fallback + Metal stroke pipeline used on screen.
    @MainActor
    func snapshot(
        size: CGSize,
        scale: CGFloat = 0,
        backgroundColor: UIColor? = nil
    ) async throws -> UIImage {
        try await MetalRoughSnapshotRenderer.image(
            for: roughView,
            size: size,
            scale: scale,
            backgroundColor: backgroundColor
        )
    }
}

public extension RoughText {
    /// Renders this `RoughText` using the Metal-accelerated snapshot helper.
    /// The output size defaults to the text's typographic size.
    @MainActor
    func metalSnapshot(
        scale: CGFloat = 0,
        backgroundColor: UIColor? = nil
    ) async throws -> UIImage {
        try await MetalRoughSnapshotRenderer.image(
            for: underlyingRoughView,
            size: typographicSize,
            scale: scale,
            backgroundColor: backgroundColor
        )
    }
}
