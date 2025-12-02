//
//  AnimationOptions.swift
//  RoughSwift
//
//  Created by Seth Stradling on 02/12/2025.
//  Copyright ©️2025 Seth Stradling. All Rights Reserved.
//
//  Configuration for animated rough drawings with subtle variations.
//

import Foundation

/// Speed of animation transitions between variation steps.
public enum AnimationSpeed: Sendable {
    /// Slow transitions (600ms between steps)
    case slow
    /// Medium transitions (300ms between steps)
    case medium
    /// Fast transitions (100ms between steps)
    case fast
    
    /// The duration in seconds between animation steps.
    public var duration: TimeInterval {
        switch self {
        case .slow: return 0.6
        case .medium: return 0.3
        case .fast: return 0.1
        }
    }
}

/// Amount of variation applied to strokes and fills during animation.
public enum AnimationVariance: Sendable {
    /// Very low variance (0.5% variation) - subtle breathing effect
    case veryLow
    /// Low variance (1% variation)
    case low
    /// Medium variance (5% variation)
    case medium
    /// High variance (10% variation)
    case high
    
    /// The variance factor as a decimal (0.005 = 0.5%, 0.01 = 1%, 0.05 = 5%, 0.10 = 10%).
    public var factor: Float {
        switch self {
        case .veryLow: return 0.005
        case .low: return 0.01
        case .medium: return 0.05
        case .high: return 0.10
        }
    }
}

/// Configuration for animating rough drawings with subtle variations.
public struct AnimationConfig: Sendable {
    /// Number of variation steps before looping back to the initial state.
    public let steps: Int
    
    /// Speed of transitions between steps.
    public let speed: AnimationSpeed
    
    /// Amount of variation applied to strokes and fills.
    public let variance: AnimationVariance
    
    /// Creates an animation configuration.
    /// - Parameters:
    ///   - steps: Number of variation steps before looping (default: 4)
    ///   - speed: Speed of transitions (default: .medium)
    ///   - variance: Amount of variation (default: .medium)
    public init(
        steps: Int = 4,
        speed: AnimationSpeed = .medium,
        variance: AnimationVariance = .medium
    ) {
        self.steps = max(2, steps) // Minimum 2 steps for a loop
        self.speed = speed
        self.variance = variance
    }
    
    /// Default animation configuration.
    public static let `default` = AnimationConfig()
}

