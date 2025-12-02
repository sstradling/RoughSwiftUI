//
//  ContentView.swift
//  RoughSwiftApp
//
//  Created by khoa on 26/03/2022.
//

import SwiftUI
import RoughSwiftUI

struct ContentView: View {
    @State private var flag = false
    var body: some View {
        TabView {
            StylesView()
                .tabItem {
                    Label("Styles", systemImage: "paintpalette.fill")
                }
            Chartview()
                .tabItem {
                    Label("Chart", systemImage: "chart.bar")
                }

            SVGView()
                .tabItem {
                    Label("SVG", systemImage: "swift")
                }
            
            TextView()
                .tabItem {
                    Label("Text", systemImage: "textformat")
                }

            CustomizeView()
                .tabItem {
                    Label("Customize", systemImage: "paintbrush.pointed.fill")
                }
            
            AnimatedView()
                .tabItem {
                    Label("Animated", systemImage: "sparkles")
                }
        }
    }
}

struct CustomizeView: View {
    @State var flag = false
    @State var smoothing: Float = 0.0
    @State var roughness: Float = 1.0

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Toggle example
                VStack(spacing: 12) {
                    SwiftUI.Text("Interactive Toggle")
                        .font(.headline)
                    
                    Button(action: {
                        flag.toggle()
                    }) {
                        SwiftUI.Text("Tap to Toggle")
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }

                    RoughView()
                        .fill(flag ? UIColor.green : UIColor.yellow)
                        .fillStyle(flag ? .hachure : .dots)
                        .circle()
                        .frame(width: flag ? 200 : 100, height: flag ? 200 : 100)
                        .animation(.spring(), value: flag)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Smoothing example
                VStack(spacing: 16) {
                    SwiftUI.Text("Stroke Smoothing")
                        .font(.headline)
                    
                    SwiftUI.Text("Smooths jagged strokes for a more polished look")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Smoothing slider
                    VStack(spacing: 4) {
                        HStack {
                            SwiftUI.Text("Smoothing: \(String(format: "%.1f", smoothing))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Slider(value: Binding(
                            get: { Double(smoothing) },
                            set: { smoothing = Float($0) }
                        ), in: 0...1, step: 0.1)
                    }
                    .padding(.horizontal)
                    
                    // Comparison: No smoothing vs Smoothed
                    HStack(spacing: 20) {
                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.orange)
                                .stroke(Color.black)
                                .fillStyle(.hachure)
                                .roughness(1.5)
                                .rectangle()
                                .frame(width: 120, height: 120)
                            
                            SwiftUI.Text("No Smoothing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.orange)
                                .stroke(Color.black)
                                .fillStyle(.hachure)
                                .roughness(1.5)
                                .smoothing(smoothing)
                                .rectangle()
                                .frame(width: 120, height: 120)
                            
                            SwiftUI.Text("Smoothing: \(String(format: "%.1f", smoothing))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Preset smoothing levels
                    VStack(spacing: 8) {
                        SwiftUI.Text("Preset Levels")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 12) {
                            ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { level in
                                VStack(spacing: 4) {
                                    RoughView()
                                        .fill(Color.teal)
                                        .stroke(Color.black)
                                        .fillStyle(.crossHatch)
                                        .roughness(1.2)
                                        .smoothing(Float(level))
                                        .circle()
                                        .frame(width: 70, height: 70)
                                    
                                    SwiftUI.Text(level == 0 ? "Raw" : String(format: "%.1f", level))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Roughness + Smoothing combo
                VStack(spacing: 16) {
                    SwiftUI.Text("Roughness + Smoothing")
                        .font(.headline)
                    
                    SwiftUI.Text("Combine high roughness with smoothing for organic curves")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Roughness slider
                    VStack(spacing: 4) {
                        HStack {
                            SwiftUI.Text("Roughness: \(String(format: "%.1f", roughness))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        Slider(value: Binding(
                            get: { Double(roughness) },
                            set: { roughness = Float($0) }
                        ), in: 0...3, step: 0.5)
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            RoughView()
                                .fill(Color.purple)
                                .stroke(Color.black)
                                .fillStyle(.hachure)
                                .roughness(roughness)
                                .smoothing(0)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Unsmoothed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            RoughView()
                                .fill(Color.purple)
                                .stroke(Color.black)
                                .fillStyle(.hachure)
                                .roughness(roughness)
                                .smoothing(0.7)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Smoothed (0.7)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
    }
}

struct SVGView: View {
    var apple: String {
        "M85 32C115 68 239 170 281 192 311 126 274 43 244 0c97 58 146 167 121 254 28 28 40 89 29 108 -25-45-67-39-93-24C176 409 24 296 0 233c68 56 170 65 226 27C165 217 56 89 36 54c42 38 116 96 161 122C159 137 108 72 85 32z"
    }

    var body: some View {
        VStack {
            RoughView()
                .stroke(Color(.systemTeal))
                .fill(Color.red)
                .svgStrokeWidth(1)
                .svgFillWeight(10)
                .svgFillStrokeAlignment(.outside)
                .draw(Path(d: apple))
                .animated(steps: 10, speed: .medium, variance: .veryLow)
                .frame(width: 300, height: 300)
        }
    }
}

struct StylesView: View {
    @State private var isYellowAnimating = false
    
    var body: some View {
        LazyVGrid(columns: [.init(), .init(), .init()], spacing: 12) {
            RoughView()
                .fill(Color.red)
                .fillStyle(.crossHatch)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(Color.green)
                .fillStyle(.dashed)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(Color.purple)
                .fillStyle(.dots)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(Color.cyan)
                .fillStyle(.hachure)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(Color.orange)
                .fillStyle(.solid)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(Color.gray)
                .fillStyle(.starBurst)
                .circle()
                .frame(width: 100, height: 100)

            // Yellow circle - tap to toggle animation
            Group {
                if isYellowAnimating {
                    RoughView()
                        .fill(Color.yellow)
                        .fillStyle(.zigzag)
                        .circle()
                        .animated(steps: 8, speed: .fast, variance: .medium)
                        .frame(width: 100, height: 100)
                } else {
                    RoughView()
                        .fill(Color.yellow)
                        .fillStyle(.zigzag)
                        .circle()
                        .frame(width: 100, height: 100)
                }
            }
            .onTapGesture {
                isYellowAnimating.toggle()
            }

            RoughView()
                .fill(Color(.systemTeal))
                .fillStyle(.zigzagLine)
                .circle()
                .animated(steps: 10, speed: .slow, variance: .veryLow)
                .frame(width: 100, height: 100)
            
            RoughView()
                .fill(Color.pink)
                .fillStyle(.hachure)
                .circle()
                .animated(steps: 6, speed: .medium, variance: .medium)
                .frame(width: 100, height: 100)
            
            RoughView()
                .fill(Color.indigo)
                .fillStyle(.hachure)
                .fillAngle(235)
                .circle()
                .frame(width: 100, height: 100)
            
            // Gradient pattern example
            RoughView()
                .fill(Color.mint)
                .fillStyle(.hachure)
//                .fillSpacing(10)
                .fillAngle(19)
                .fillSpacingPattern([10, 11, 30, 3, 30, 2, 90])
                .circle()
                .frame(width: 100, height: 100)
        }
    }
}

struct Chartview: View {
    var heights: [CGFloat] {
        Array(0 ..< 10).map { _ in CGFloat.random(in: 0 ..< 150) }
    }

    var body: some View {
        HStack {
            ForEach(0 ..< 10) { index in
                VStack {
                    Spacer()
                    RoughView()
                        .fill(Color.yellow)
                        .rectangle()
                        .frame(height: heights[index])
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 100)
    }
}

struct TextView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Title
                VStack(spacing: 8) {
                    SwiftUI.Text("Rough Text")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    SwiftUI.Text("Text rendered with hand-drawn styling")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Basic text examples
                VStack(spacing: 16) {
                    SwiftUI.Text("Using RoughText view")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    RoughText("Hello!", font: .systemFont(ofSize: 48, weight: .bold))
                        .fill(Color.red)
                        .stroke(Color.black)
                        .fillStyle(.hachure)
                        .frame(width: 200, height: 80)
                    
                    RoughText("Sketchy", font: .systemFont(ofSize: 36, weight: .medium))
                        .fill(Color.blue)
                        .stroke(Color.black)
                        .fillStyle(.crossHatch)
                        .frame(width: 180, height: 60)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // RoughView with text modifier
                VStack(spacing: 16) {
                    SwiftUI.Text("Using RoughView.text() modifier")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    RoughView()
                        .fill(Color.green)
                        .stroke(Color.black)
                        .fillStyle(.dots)
                        .text("Dots!", font: .systemFont(ofSize: 40, weight: .heavy))
                        .frame(width: 150, height: 70)
                    
                    RoughView()
                        .fill(Color.orange)
                        .stroke(Color.black)
                        .fillStyle(.zigzag)
                        .text("ZigZag", font: .systemFont(ofSize: 32, weight: .bold))
                        .frame(width: 160, height: 60)
                }
                
                Divider()
                    .padding(.horizontal)
                
                // Fill style showcase
                VStack(spacing: 16) {
                    SwiftUI.Text("Fill Styles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    LazyVGrid(columns: [.init(), .init()], spacing: 16) {
                        RoughText("ABC", font: .boldSystemFont(ofSize: 28))
                            .fill(Color.purple)
                            .fillStyle(.solid)
                            .frame(width: 100, height: 50)
                        
                        RoughText("ABC", font: .boldSystemFont(ofSize: 28))
                            .fill(Color.cyan)
                            .fillStyle(.hachure)
                            .frame(width: 100, height: 50)
                        
                        RoughText("ABC", font: .boldSystemFont(ofSize: 28))
                            .fill(Color.pink)
                            .fillStyle(.crossHatch)
                            .frame(width: 100, height: 50)
                        
                        RoughText("ABC", font: .boldSystemFont(ofSize: 28))
                            .fill(Color.yellow)
                            .fillStyle(.zigzagLine)
                            .frame(width: 100, height: 50)
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
    }
}

struct AnimatedView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Shapes Section
                VStack(spacing: 16) {
                    SwiftUI.Text("Animated Shapes")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    SwiftUI.Text("Watch the strokes subtly shift and wobble")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Speed comparison row
                    HStack(spacing: 20) {
                        VStack {
                            RoughView()
                                .fill(Color.red)
                                .fillStyle(.hachure)
                                .circle()
                                .animated(steps: 4, speed: .slow, variance: .medium)
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Slow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            RoughView()
                                .fill(Color.green)
                                .fillStyle(.crossHatch)
                                .circle()
                                .animated(steps: 6, speed: .medium, variance: .medium)
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Medium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            RoughView()
                                .fill(Color.blue)
                                .fillStyle(.dots)
                                .circle()
                                .animated(steps: 8, speed: .fast, variance: .medium)
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Fast")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Variance comparison row
                    HStack(spacing: 20) {
                        VStack {
                            RoughView()
                                .fill(Color.purple)
                                .fillStyle(.zigzag)
                                .rectangle()
                                .animated(steps: 5, speed: .medium, variance: .low)
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Low")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            RoughView()
                                .fill(Color.orange)
                                .fillStyle(.zigzag)
                                .rectangle()
                                .animated(steps: 5, speed: .medium, variance: .medium)
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Medium")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack {
                            RoughView()
                                .fill(Color.cyan)
                                .fillStyle(.zigzag)
                                .rectangle()
                                .animated(steps: 5, speed: .medium, variance: .high)
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("High")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                // MARK: - Animated Text Section
                VStack(spacing: 20) {
                    SwiftUI.Text("Animated Text")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    SwiftUI.Text("Text with hand-drawn wobble effects")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Main animated text
                    RoughText("Wobble", font: .systemFont(ofSize: 44, weight: .black))
                        .fill(Color.mint)
                        .stroke(Color.black)
                        .fillStyle(.hachure)
                        .animated(steps: 6, speed: .medium, variance: .low)
                        .frame(width: 220, height: 80)
                    
                    // Text speed comparison
                    VStack(spacing: 8) {
                        SwiftUI.Text("Animation Speeds")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                RoughText("Slow", font: .boldSystemFont(ofSize: 20))
                                    .fill(Color.red)
                                    .fillStyle(.hachure)
                                    .animated(steps: 4, speed: .slow, variance: .medium)
                                    .frame(width: 80, height: 40)
                                
                                SwiftUI.Text("600ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                RoughText("Med", font: .boldSystemFont(ofSize: 20))
                                    .fill(Color.orange)
                                    .fillStyle(.hachure)
                                    .animated(steps: 4, speed: .medium, variance: .medium)
                                    .frame(width: 80, height: 40)
                                
                                SwiftUI.Text("300ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                RoughText("Fast", font: .boldSystemFont(ofSize: 20))
                                    .fill(Color.green)
                                    .fillStyle(.hachure)
                                    .animated(steps: 4, speed: .fast, variance: .medium)
                                    .frame(width: 80, height: 40)
                                
                                SwiftUI.Text("100ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Text variance comparison
                    VStack(spacing: 8) {
                        SwiftUI.Text("Variance Levels")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 12) {
                            VStack(spacing: 4) {
                                RoughText("Lo", font: .boldSystemFont(ofSize: 24))
                                    .fill(Color.purple)
                                    .fillStyle(.crossHatch)
                                    .animated(steps: 6, speed: .medium, variance: .veryLow)
                                    .frame(width: 60, height: 45)
                                
                                SwiftUI.Text("0.5%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                RoughText("Med", font: .boldSystemFont(ofSize: 24))
                                    .fill(Color.blue)
                                    .fillStyle(.crossHatch)
                                    .animated(steps: 6, speed: .medium, variance: .medium)
                                    .frame(width: 70, height: 45)
                                
                                SwiftUI.Text("5%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            
                            VStack(spacing: 4) {
                                RoughText("Hi", font: .boldSystemFont(ofSize: 24))
                                    .fill(Color.cyan)
                                    .fillStyle(.crossHatch)
                                    .animated(steps: 6, speed: .medium, variance: .high)
                                    .frame(width: 60, height: 45)
                                
                                SwiftUI.Text("10%")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // Animated fill styles on text
                    VStack(spacing: 8) {
                        SwiftUI.Text("Animated Fill Styles")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        HStack(spacing: 16) {
                            RoughText("Dots", font: .boldSystemFont(ofSize: 18))
                                .fill(Color.yellow)
                                .stroke(Color.black)
                                .fillStyle(.dots)
                                .animated(steps: 5, speed: .slow, variance: .low)
                                .frame(width: 70, height: 35)
                            
                            RoughText("Zig", font: .boldSystemFont(ofSize: 18))
                                .fill(Color.pink)
                                .stroke(Color.black)
                                .fillStyle(.zigzag)
                                .animated(steps: 5, speed: .slow, variance: .low)
                                .frame(width: 60, height: 35)
                            
                            RoughText("Star", font: .boldSystemFont(ofSize: 18))
                                .fill(Color.indigo)
                                .stroke(Color.black)
                                .fillStyle(.starBurst)
                                .animated(steps: 5, speed: .slow, variance: .low)
                                .frame(width: 70, height: 35)
                        }
                    }
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#Preview("Customize View") {
    CustomizeView()
}

#Preview("SVG View") {
    SVGView()
}

#Preview("Styles View") {
    StylesView()
}

#Preview("Chart View") {
    Chartview()
}

#Preview("Text View") {
    TextView()
}

#Preview("Animated View") {
    AnimatedView()
}
