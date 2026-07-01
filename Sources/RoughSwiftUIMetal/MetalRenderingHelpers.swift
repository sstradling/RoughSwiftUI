//
//  MetalRenderingHelpers.swift
//  RoughSwiftUIMetal
//
//  Shared drawing helpers used by on-screen Metal views, animated Metal views,
//  and snapshot rendering.
//

import SwiftUI
import Metal
import RoughSwiftUI

// MARK: - SwiftUI Canvas command replay

enum FillCanvasRenderer {
    static func draw(command: RoughRenderCommand, in context: inout GraphicsContext) {
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

// MARK: - Metal ribbon encoding

enum MetalRibbonEncoder {
    static func encode(
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
}
