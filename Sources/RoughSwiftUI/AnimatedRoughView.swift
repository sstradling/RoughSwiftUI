//
//  AnimatedRoughView.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  An animated wrapper for RoughView that cycles through subtle variations.
//

import SwiftUI
import Combine

/// Shared renderer for animations to avoid per-frame allocations.
private let animatedRenderer = SwiftUIRenderer()

/// A SwiftUI view that renders animated hand-drawn Rough.js primitives.
///
/// This view wraps a `RoughView` and applies subtle variations to strokes and fills
/// on a loop, creating a "breathing" or "sketchy" animation effect.
///
/// ## Performance
///
/// AnimatedRoughView caches the base drawing commands and only recomputes the
/// variance on each animation step. This avoids repeated JavaScript bridge calls
/// and drawing generation during animation.
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
    
    /// Current animation step.
    @State private var currentStep: Int = 0
    
    /// Variance generator (created once and reused).
    @State private var varianceGenerator: PathVarianceGenerator?
    
    /// Cached base commands (regenerated only when size or drawables change).
    @State private var cachedCommands: [RoughRenderCommand] = []
    
    /// Size for which commands were cached.
    @State private var cachedSize: CGSize = .zero
    
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
                
                // Get or create variance generator
                let varGen = varianceGenerator ?? PathVarianceGenerator(config: config)
                
                // Check if we need to regenerate base commands
                // This only happens when size changes, not on every animation step
                let commands: [RoughRenderCommand]
                if cachedSize == renderSize && !cachedCommands.isEmpty {
                    // Use cached commands (fast path - no JS calls)
                    commands = cachedCommands
                } else {
                    // Generate and cache commands (slow path - only on size change)
                    commands = generateCommands(size: renderSize)
                    
                    // Update cache on main thread after render
                    DispatchQueue.main.async {
                        cachedSize = renderSize
                        cachedCommands = commands
                    }
                }
                
                // Apply variance and render (fast - just path transforms)
                for command in commands {
                    let variedCommand = command.withVariance(generator: varGen, step: currentStep)
                    renderCommand(variedCommand, in: &context)
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
    
    /// Generates render commands for all drawables.
    ///
    /// This method is only called when the canvas size changes, not on every
    /// animation step. The generated commands are cached and reused.
    private func generateCommands(size: CGSize) -> [RoughRenderCommand] {
        // Use cached generator (avoids JS bridge call if size unchanged)
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
                    
                    // Drawing is cached by drawable + patternOptions
                    if let drawing = generator.generate(drawable: drawable, options: patternOptions) {
                        let commands = animatedRenderer.commands(for: drawing, options: patternOptions, in: size)
                        allCommands.append(contentsOf: commands)
                    }
                }
            } else {
                // Drawing is cached by drawable + options
                if let drawing = generator.generate(drawable: drawable, options: options) {
                    let commands = animatedRenderer.commands(for: drawing, options: options, in: size)
                    allCommands.append(contentsOf: commands)
                }
            }
        }
        
        return allCommands
    }
    
    /// Renders a single command into the graphics context.
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
            context.stroke(
                command.path,
                with: .color(color),
                lineWidth: lineWidth
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
        // Initialize variance generator if needed
        if varianceGenerator == nil {
            varianceGenerator = PathVarianceGenerator(config: config)
        }
        
        // Create timer
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
    
    /// Stops the animation timer.
    private func stopAnimation() {
        timerCancellable?.cancel()
        timerCancellable = nil
        timer = nil
    }
    
    /// Restarts the animation with updated configuration.
    private func restartAnimation() {
        stopAnimation()
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

