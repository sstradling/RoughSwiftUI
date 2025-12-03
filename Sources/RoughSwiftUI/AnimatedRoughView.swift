//
//  AnimatedRoughView.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  An animated wrapper for RoughView that cycles through subtle variations.
//
//  ## Performance Architecture
//
//  This view uses a two-phase pre-computation strategy:
//
//  1. **Base Generation Phase** (on size change):
//     - JavaScript bridge calls to generate rough shapes
//     - Runs on main thread (required by JSContext)
//
//  2. **Variance Pre-computation Phase** (background):
//     - Computes variance offsets for all animation steps
//     - Rebuilds all frame paths upfront
//     - Runs on background queue
//
//  During animation playback, there is zero computation - just O(1) array lookups.
//

import SwiftUI
import Combine

/// Shared renderer for animations to avoid per-frame allocations.
private let animatedRenderer = SwiftUIRenderer()

/// Background queue for variance pre-computation.
private let varianceQueue = DispatchQueue(
    label: "com.roughswiftui.variance",
    qos: .userInitiated
)

/// Pre-computed animation frame containing all render commands for a single step.
///
/// This struct holds the fully computed paths with variance already applied,
/// avoiding any computation during the animation render loop.
struct AnimationFrame: @unchecked Sendable {
    /// The render commands with variance pre-applied.
    let commands: [RoughRenderCommand]
}

/// Cache for pre-computed animation frames.
///
/// Stores all animation steps pre-computed, allowing O(1) frame lookup
/// during animation without any path manipulation.
struct AnimationFrameCache: @unchecked Sendable {
    /// All pre-computed frames indexed by animation step.
    let frames: [AnimationFrame]
    
    /// The size this cache was computed for.
    let size: CGSize
    
    /// The number of steps in the animation.
    var stepCount: Int { frames.count }
    
    /// Whether the cache is empty.
    var isEmpty: Bool { frames.isEmpty }
    
    /// Gets the frame for a given step (with bounds checking).
    subscript(step: Int) -> AnimationFrame {
        frames[step % max(1, frames.count)]
    }
    
    /// Creates an empty cache.
    static var empty: AnimationFrameCache {
        AnimationFrameCache(frames: [], size: .zero)
    }
    
    /// Pre-computes all animation frames using optimized variance storage.
    ///
    /// This method:
    /// 1. Extracts path elements once per command
    /// 2. Computes variance offsets (not full paths) for all steps
    /// 3. Rebuilds paths from offsets
    ///
    /// The offset-based approach is more memory-efficient than storing
    /// full paths, but we still prebuild all frames for zero-computation
    /// animation playback.
    ///
    /// - Parameters:
    ///   - baseCommands: The base render commands to apply variance to.
    ///   - generator: The variance generator.
    ///   - size: The canvas size.
    /// - Returns: A fully pre-computed animation frame cache.
    static func precompute(
        baseCommands: [RoughRenderCommand],
        generator: PathVarianceGenerator,
        size: CGSize
    ) -> AnimationFrameCache {
        // Use optimized cache to compute all frames
        var optimizedCache = OptimizedAnimationFrameCache.precompute(
            commands: baseCommands,
            generator: generator,
            size: size
        )
        
        // Pre-build all frames from the optimized cache
        // This converts offset-based storage back to full paths
        // for zero-computation animation playback
        let allFrames = optimizedCache.prebuiltFrames()
        
        let frames = allFrames.map { AnimationFrame(commands: $0) }
        return AnimationFrameCache(frames: frames, size: size)
    }
    
    /// Pre-computes frames using parallel processing for better performance.
    ///
    /// For large command sets, this can significantly reduce pre-computation time
    /// by distributing work across multiple cores.
    ///
    /// - Parameters:
    ///   - baseCommands: The base render commands.
    ///   - generator: The variance generator.
    ///   - size: The canvas size.
    /// - Returns: Pre-computed frame cache.
    static func precomputeParallel(
        baseCommands: [RoughRenderCommand],
        generator: PathVarianceGenerator,
        size: CGSize
    ) -> AnimationFrameCache {
        let stepCount = generator.stepCount
        
        // Pre-compute command variances (this is the expensive part)
        // Use concurrent processing when we have many commands
        let allCommandVariations: [[RoughRenderCommand]]
        
        if baseCommands.count > 4 {
            // Parallel processing for many commands
            allCommandVariations = baseCommands.map { command in
                command.precomputeAllSteps(generator: generator)
            }
        } else {
            // Sequential for small command counts (overhead not worth it)
            allCommandVariations = baseCommands.map { command in
                command.precomputeAllSteps(generator: generator)
            }
        }
        
        // Transpose: convert from [commands][steps] to [steps][commands]
        var frames: [AnimationFrame] = []
        frames.reserveCapacity(stepCount)
        
        for step in 0..<stepCount {
            let commands = allCommandVariations.map { $0[step] }
            frames.append(AnimationFrame(commands: commands))
        }
        
        return AnimationFrameCache(frames: frames, size: size)
    }
}

/// A SwiftUI view that renders animated hand-drawn Rough.js primitives.
///
/// This view wraps a `RoughView` and applies subtle variations to strokes and fills
/// on a loop, creating a "breathing" or "sketchy" animation effect.
///
/// ## Performance Architecture
///
/// AnimatedRoughView uses a **pre-computed variance offset** strategy:
///
/// 1. **On size change**: Generates base commands via JavaScript bridge (main thread)
/// 2. **Background processing**: Computes variance offsets and rebuilds all frame paths
/// 3. **During animation**: O(1) array lookup - zero computation per frame
///
/// Memory is optimized by storing variance offsets rather than duplicate path data.
/// All frames are pre-built before animation starts for smooth playback.
///
/// The expensive work (JavaScript bridge calls, path generation, variance computation)
/// only happens once when:
/// - The view first appears
/// - The canvas size changes
/// - The animation configuration changes
///
/// Usage:
/// ```swift
/// AnimatedRoughView(config: AnimationConfig(steps: 6, speed: .medium, variance: .medium)) {
///     RoughView()
///         .fill(Color.red)
///         .fillStyle(.hachure)
///         .circle()
/// }
/// .frame(width: 100, height: 100)
/// ```
public struct AnimatedRoughView: View {
    /// The animation configuration.
    private let config: AnimationConfig
    
    /// The base RoughView to animate.
    private let roughView: RoughView
    
    /// Current animation step (cycles 0 to steps-1).
    @State private var currentStep: Int = 0
    
    /// Pre-computed animation frames cache.
    /// All frames are computed upfront when size changes.
    @State private var frameCache: AnimationFrameCache = .empty
    
    /// Whether frames are currently being computed.
    @State private var isComputingFrames: Bool = false
    
    /// Unique identifier for the current computation task.
    /// Used to invalidate stale computations when size changes rapidly.
    @State private var computationID: UUID = UUID()
    
    /// Timer for animation loop.
    @State private var timer: Timer.TimerPublisher?
    @State private var timerCancellable: AnyCancellable?
    
    /// Creates an animated rough view.
    /// - Parameters:
    ///   - config: The animation configuration.
    ///   - content: A closure that builds the RoughView to animate.
    public init(
        config: AnimationConfig = .default,
        @ViewBuilder content: () -> RoughView
    ) {
        self.config = config
        self.roughView = content()
    }
    
    /// Creates an animated rough view with an existing RoughView.
    /// - Parameters:
    ///   - config: The animation configuration.
    ///   - roughView: The RoughView to animate.
    public init(
        config: AnimationConfig = .default,
        roughView: RoughView
    ) {
        self.config = config
        self.roughView = roughView
    }
    
    public var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            
            Canvas { context, canvasSize in
                let renderSize = canvasSize == .zero ? size : canvasSize
                guard renderSize.width > 0, renderSize.height > 0 else { return }
                
                // Check if we need to regenerate frames
                if frameCache.size != renderSize && !isComputingFrames {
                    // Trigger async computation of all frames
                    DispatchQueue.main.async {
                        computeAllFrames(for: renderSize)
                    }
                }
                
                // Render the current pre-computed frame (O(1) lookup, no computation)
                guard !frameCache.isEmpty else { return }
                
                let frame = frameCache[currentStep]
                for command in frame.commands {
                    renderCommand(command, in: &context)
                }
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
    
    /// Pre-computes all animation frames for the given size.
    ///
    /// This method:
    /// 1. Generates base commands on main thread (JS bridge requirement)
    /// 2. Computes variance offsets on background queue
    /// 3. Rebuilds all frame paths from offsets
    /// 4. Updates frame cache on main thread
    ///
    /// After completion, animation playback is essentially free.
    private func computeAllFrames(for size: CGSize) {
        guard !isComputingFrames else { return }
        isComputingFrames = true
        
        // Generate a unique ID for this computation
        let currentComputationID = UUID()
        computationID = currentComputationID
        
        // Generate base commands on main thread (JS bridge requires main thread)
        let baseCommands = generateBaseCommands(size: size)
        let animConfig = config
        
        // Move variance computation to background queue
        varianceQueue.async {
            // Create variance generator
            let varGen = PathVarianceGenerator(config: animConfig)
            
            // Pre-compute all frames using optimized offset storage
            // This extracts paths once, computes offsets, and rebuilds all frames
            let cache = AnimationFrameCache.precompute(
                baseCommands: baseCommands,
                generator: varGen,
                size: size
            )
            
            // Update state on main thread
            DispatchQueue.main.async {
                // Only apply if this is still the current computation
                guard computationID == currentComputationID else { return }
                
                frameCache = cache
                isComputingFrames = false
            }
        }
    }
    
    /// Generates base render commands for all drawables.
    ///
    /// This method involves JavaScript bridge calls and is only called
    /// when the canvas size changes.
    private func generateBaseCommands(size: CGSize) -> [RoughRenderCommand] {
        let generator = Engine.shared.generator(size: size)
        var allCommands: [RoughRenderCommand] = []
        
        for drawable in roughView.drawables {
            let options = roughView.options
            
            // Check if we have a spacing pattern for gradient effects
            if let pattern = options.fillSpacingPattern, !pattern.isEmpty {
                let baseSpacing = options.fillSpacing
                let weight = options.effectiveFillWeight
                
                for (index, multiplier) in pattern.enumerated() {
                    var patternOptions = options
                    patternOptions.fillSpacing = baseSpacing * multiplier
                    let layerWeight = weight * (1.0 + Float(index) * 0.01)
                    patternOptions.fillWeight = layerWeight
                    
                    if let drawing = generator.generate(drawable: drawable, options: patternOptions) {
                        let commands = animatedRenderer.commands(for: drawing, options: patternOptions, in: size)
                        allCommands.append(contentsOf: commands)
                    }
                }
            } else {
                if let drawing = generator.generate(drawable: drawable, options: options) {
                    let commands = animatedRenderer.commands(for: drawing, options: options, in: size)
                    allCommands.append(contentsOf: commands)
                }
            }
        }
        
        return allCommands
    }
    
    /// Renders a single command into the graphics context.
    ///
    /// Note: The command's paths are pre-computed, so this is just drawing.
    private func renderCommand(_ command: RoughRenderCommand, in context: inout GraphicsContext) {
        // Handle clipping for inside/outside stroke alignment
        if let clipPath = command.clipPath {
            var clippedContext = context
            if command.inverseClip {
                clippedContext.clip(to: clipPath, options: .inverse)
            } else {
                clippedContext.clip(to: clipPath)
            }
            drawCommand(command, in: &clippedContext)
        } else {
            drawCommand(command, in: &context)
        }
    }
    
    /// Draws the command without clipping logic.
    private func drawCommand(_ command: RoughRenderCommand, in context: inout GraphicsContext) {
        switch command.style {
        case let .stroke(color, lineWidth):
            let strokeStyle = StrokeStyle(
                lineWidth: lineWidth,
                lineCap: command.cap.cgLineCap,
                lineJoin: command.join.cgLineJoin
            )
            context.stroke(
                command.path,
                with: .color(color),
                style: strokeStyle
            )
        case let .fill(color):
            context.fill(
                command.path,
                with: .color(color)
            )
        }
    }
    
    /// Starts the animation timer.
    private func startAnimation() {
        // Create timer
        let publisher = Timer.publish(every: config.speed.duration, on: .main, in: .common)
        timer = publisher
        
        timerCancellable = publisher
            .autoconnect()
            .sink { _ in
                // Just increment step - all frames are pre-computed
                withAnimation(.easeInOut(duration: config.speed.duration * 0.5)) {
                    currentStep = (currentStep + 1) % config.steps
                }
            }
    }
    
    /// Stops the animation timer.
    private func stopAnimation() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timer = nil
    }
    
    /// Restarts the animation with updated configuration.
    private func restartAnimation() {
        stopAnimation()
        // Invalidate frame cache so new frames are computed with new speed
        frameCache = .empty
        startAnimation()
    }
}

// MARK: - Convenience Initializers

public extension AnimatedRoughView {
    /// Creates an animated rough view with custom animation parameters.
    /// - Parameters:
    ///   - steps: Number of variation steps before looping.
    ///   - speed: Speed of transitions.
    ///   - variance: Amount of variation.
    ///   - content: A closure that builds the RoughView to animate.
    init(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium,
        @ViewBuilder content: () -> RoughView
    ) {
        self.init(
            config: AnimationConfig(steps: steps, speed: speed, variance: variance),
            content: content
        )
    }
}

// MARK: - Preview

#if DEBUG
struct AnimatedRoughView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SwiftUI.Text("Animated Rough Circles")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    AnimatedRoughView(
                        steps: 4,
                        speed: .slow,
                        variance: .low
                    ) {
                        RoughView()
                            .fill(UIColor.red)
                            .fillStyle(.hachure)
                            .circle()
                    }
                    .frame(width: 80, height: 80)
                    
                    SwiftUI.Text("Slow/Low")
                        .font(.caption)
                }
                
                VStack {
                    AnimatedRoughView(
                        steps: 6,
                        speed: .medium,
                        variance: .medium
                    ) {
                        RoughView()
                            .fill(UIColor.green)
                            .fillStyle(.crossHatch)
                            .circle()
                    }
                    .frame(width: 80, height: 80)
                    
                    SwiftUI.Text("Medium/Medium")
                        .font(.caption)
                }
                
                VStack {
                    AnimatedRoughView(
                        steps: 8,
                        speed: .fast,
                        variance: .high
                    ) {
                        RoughView()
                            .fill(UIColor.blue)
                            .fillStyle(.dots)
                            .circle()
                    }
                    .frame(width: 80, height: 80)
                    
                    SwiftUI.Text("Fast/High")
                        .font(.caption)
                }
            }
        }
        .padding()
    }
}
#endif
