//
//  AnimatedMetalRoughView.swift
//  RoughSwiftUIMetal
//
//  Created by Seth Stradling on 07/01/2026.
//  Copyright ©️2026 Seth Stradling. All Rights Reserved.
//
//  Animated host for Metal-accelerated RoughView content.
//
//  Architecture mirrors AnimatedRoughView:
//    1. Generate fallback commands and Metal ribbon draw lists once when the
//       size changes.
//    2. Precompute variance-applied fallback commands and ribbon meshes for
//       every animation step.
//    3. Playback is an O(1) frame lookup driven by a timer.
//

import SwiftUI
import Combine
import MetalKit
import RoughSwiftUI

// MARK: - Public view

/// Animated version of `MetalRoughView`.
///
/// Use `RoughView().metalAnimated(...)` when you want both shader-driven
/// Metal stroke effects and the existing RoughSwiftUI animated jitter.
/// Fills are rendered by SwiftUI Canvas; stroke ribbons are rendered by Metal.
public struct AnimatedMetalRoughView: View {
    private let config: AnimationConfig
    private let roughView: RoughView

    @State private var currentStep: Int = 0
    @State private var frameCache: MetalAnimationFrameCache = .empty
    @State private var isComputingFrames = false
    @State private var computationID = UUID()
    @State private var timer: Timer.TimerPublisher?
    @State private var timerCancellable: AnyCancellable?

    public init(config: AnimationConfig = .default, roughView: RoughView) {
        self.config = config
        self.roughView = roughView
    }

    public init(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium,
        roughView: RoughView
    ) {
        self.init(
            config: AnimationConfig(steps: steps, speed: speed, variance: variance),
            roughView: roughView
        )
    }

    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                AnimatedMetalFillLayer(
                    frame: currentFrame,
                    size: size
                )
                AnimatedMetalRibbonLayer(
                    frame: currentFrame,
                    size: size
                )
                .allowsHitTesting(false)
            }
            .onAppear {
                computeFramesIfNeeded(for: size)
            }
            .onChange(of: size) { _, newSize in
                computeFramesIfNeeded(for: newSize)
            }
        }
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: config.speed.duration) { _, _ in
            restartAnimation()
        }
    }

    private var currentFrame: MetalAnimationFrame? {
        guard !frameCache.isEmpty else { return nil }
        return frameCache[currentStep]
    }

    private func computeFramesIfNeeded(for size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        guard frameCache.size != size, !isComputingFrames else { return }

        isComputingFrames = true
        let currentComputationID = UUID()
        computationID = currentComputationID

        // Generation touches Engine.shared (@MainActor), so do it here.
        let cache = MetalAnimationFrameCache.precompute(
            roughView: roughView,
            config: config,
            size: size
        )

        guard computationID == currentComputationID else { return }
        frameCache = cache
        isComputingFrames = false
    }

    private func startAnimation() {
        let publisher = Timer.publish(every: config.speed.duration, on: .main, in: .common)
        timer = publisher
        timerCancellable = publisher
            .autoconnect()
            .sink { _ in
                withAnimation(.easeInOut(duration: config.speed.duration * 0.5)) {
                    currentStep = (currentStep + 1) % config.steps
                }
            }
    }

    private func stopAnimation() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timer = nil
    }

    private func restartAnimation() {
        stopAnimation()
        startAnimation()
    }
}

// MARK: - Frame cache

struct MetalAnimationFrame {
    let fallbackCommands: [RoughRenderCommand]
    let ribbonDraws: [MetalRoughRenderer.RibbonDraw]
}

struct MetalAnimationFrameCache {
    let frames: [MetalAnimationFrame]
    let size: CGSize

    var isEmpty: Bool { frames.isEmpty }
    var stepCount: Int { frames.count }

    subscript(step: Int) -> MetalAnimationFrame {
        frames[step % max(1, frames.count)]
    }

    static var empty: MetalAnimationFrameCache {
        MetalAnimationFrameCache(frames: [], size: .zero)
    }

    @MainActor
    static func precompute(
        roughView: RoughView,
        config: AnimationConfig,
        size: CGSize
    ) -> MetalAnimationFrameCache {
        let generator = Engine.shared.generator(size: size)
        let metalRenderer = MetalRoughRenderer(device: MTLCreateSystemDefaultDevice())
        let variance = MetalPathVarianceGenerator(config: config)

        var baseFallback: [RoughRenderCommand] = []
        var baseDraws: [MetalRoughRenderer.RibbonDraw] = []

        for drawable in roughView.drawables {
            guard let drawing = generator.generate(drawable: drawable, options: roughView.options) else {
                continue
            }
            baseFallback.append(contentsOf: metalRenderer.commands(for: drawing, options: roughView.options, in: size))
            baseDraws.append(contentsOf: metalRenderer.metalDrawList(for: drawing, options: roughView.options, in: size))
        }

        let frames = (0..<config.steps).map { step in
            MetalAnimationFrame(
                fallbackCommands: baseFallback.map { $0.withMetalVariance(generator: variance, step: step) },
                ribbonDraws: baseDraws.map { $0.withMetalVariance(generator: variance, step: step) }
            )
        }

        return MetalAnimationFrameCache(frames: frames, size: size)
    }
}

// MARK: - Variance

struct MetalPathVarianceGenerator {
    let variance: Float
    let stepSeeds: [UInt64]

    init(config: AnimationConfig, baseSeed: UInt64 = UInt64.random(in: 0..<UInt64.max)) {
        self.variance = config.variance.factor
        self.stepSeeds = (0..<config.steps).map { index in
            baseSeed &+ UInt64(index) &* 0x9E3779B97F4A7C15
        }
    }

    func computeOffset(for point: CGPoint, step: Int, index: Int) -> CGPoint {
        guard variance > 0, !stepSeeds.isEmpty else { return .zero }
        let seed = stepSeeds[step % stepSeeds.count]
        let hash1 = seed &+ UInt64(truncatingIfNeeded: index) &* 0x517CC1B727220A95
        let hash2 = seed &+ UInt64(truncatingIfNeeded: index + 1000) &* 0x517CC1B727220A95
        let rand1 = Float(Int64(bitPattern: hash1 % 2_000_000)) / 1_000_000 - 1
        let rand2 = Float(Int64(bitPattern: hash2 % 2_000_000)) / 1_000_000 - 1
        let magnitude = max(abs(Float(point.x)), abs(Float(point.y)), 10)
        let offset = magnitude * variance
        return CGPoint(x: CGFloat(rand1 * offset), y: CGFloat(rand2 * offset))
    }
}

// MARK: - Variance application

private extension RoughRenderCommand {
    func withMetalVariance(generator: MetalPathVarianceGenerator, step: Int) -> RoughRenderCommand {
        RoughRenderCommand(
            path: path.withMetalVariance(generator: generator, step: step),
            style: style,
            clipPath: clipPath?.withMetalVariance(generator: generator, step: step),
            inverseClip: inverseClip,
            cap: cap,
            join: join
        )
    }
}

private extension SwiftUI.Path {
    func withMetalVariance(generator: MetalPathVarianceGenerator, step: Int) -> SwiftUI.Path {
        var result = SwiftUI.Path()
        var index = 0

        forEach { element in
            switch element {
            case .move(let point):
                result.move(to: varied(point, generator: generator, step: step, index: &index))
            case .line(let point):
                result.addLine(to: varied(point, generator: generator, step: step, index: &index))
            case .quadCurve(let point, let control):
                let p = varied(point, generator: generator, step: step, index: &index)
                let c = varied(control, generator: generator, step: step, index: &index)
                result.addQuadCurve(to: p, control: c)
            case .curve(let point, let c1, let c2):
                let p = varied(point, generator: generator, step: step, index: &index)
                let cp1 = varied(c1, generator: generator, step: step, index: &index)
                let cp2 = varied(c2, generator: generator, step: step, index: &index)
                result.addCurve(to: p, control1: cp1, control2: cp2)
            case .closeSubpath:
                result.closeSubpath()
            }
        }

        return result
    }

    private func varied(
        _ point: CGPoint,
        generator: MetalPathVarianceGenerator,
        step: Int,
        index: inout Int
    ) -> CGPoint {
        defer { index += 1 }
        let offset = generator.computeOffset(for: point, step: step, index: index)
        return CGPoint(x: point.x + offset.x, y: point.y + offset.y)
    }
}

private extension MetalRoughRenderer.RibbonDraw {
    func withMetalVariance(generator: MetalPathVarianceGenerator, step: Int) -> MetalRoughRenderer.RibbonDraw {
        var vertices = mesh.vertices
        for index in vertices.indices {
            let point = CGPoint(
                x: CGFloat(vertices[index].position.x),
                y: CGFloat(vertices[index].position.y)
            )
            let offset = generator.computeOffset(for: point, step: step, index: index)
            vertices[index].position.x += Float(offset.x)
            vertices[index].position.y += Float(offset.y)
        }

        return MetalRoughRenderer.RibbonDraw(
            mesh: RibbonMesh(vertices: vertices, isClosed: mesh.isClosed, totalLength: mesh.totalLength),
            appearance: appearance
        )
    }
}

// MARK: - SwiftUI layers

private struct AnimatedMetalFillLayer: View {
    let frame: MetalAnimationFrame?
    let size: CGSize

    var body: some View {
        Canvas { context, _ in
            guard let frame else { return }
            for command in frame.fallbackCommands {
                FillCanvasRenderer.draw(command: command, in: &context)
            }
        }
    }
}

private struct AnimatedMetalRibbonLayer: UIViewRepresentable {
    let frame: MetalAnimationFrame?
    let size: CGSize

    func makeCoordinator() -> Coordinator {
        Coordinator()
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
        context.coordinator.frame = frame
        context.coordinator.size = size
        uiView.setNeedsDisplay()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        weak var view: MTKView?
        var frame: MetalAnimationFrame?
        var size: CGSize = .zero
        private let renderer: MetalRoughRenderer
        private let commandQueue: MTLCommandQueue?

        override init() {
            let device = MTLCreateSystemDefaultDevice()
            self.renderer = MetalRoughRenderer(device: device)
            self.commandQueue = device?.makeCommandQueue()
            super.init()
        }

        nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            DispatchQueue.main.async {
                view.setNeedsDisplay()
            }
        }

        nonisolated func draw(in view: MTKView) {
            dispatchPrecondition(condition: .onQueue(.main))
            MainActor.assumeIsolated {
                self.drawOnMain(in: view)
            }
        }

        @MainActor
        private func drawOnMain(in view: MTKView) {
            guard let frame,
                  let device = renderer.device,
                  let commandQueue,
                  let currentDrawable = view.currentDrawable,
                  let descriptor = view.currentRenderPassDescriptor,
                  let pipeline = try? renderer.gradientPipelineState(colorPixelFormat: view.colorPixelFormat)
            else { return }

            let renderSize = size == .zero ? view.bounds.size : size
            guard renderSize.width > 0, renderSize.height > 0 else { return }

            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
            else { return }

            encoder.setRenderPipelineState(pipeline)
            for draw in frame.ribbonDraws {
                MetalRibbonEncoder.encode(draw: draw, encoder: encoder, viewSize: renderSize, device: device)
            }

            encoder.endEncoding()
            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}

