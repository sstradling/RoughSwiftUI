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
            
            BrushStrokeView()
                .tabItem {
                    Label("Brushes", systemImage: "pencil.tip")
                }
            
            ScribbleFillView()
                .tabItem {
                    Label("Scribble", systemImage: "scribble.variable")
                }
        }
    }
}

struct CustomizeView: View {
    @State var flag = false

    var body: some View {
        VStack {
            Button(action: {
                flag.toggle()
            }) {
                SwiftUI.Text("Click")
            }

            RoughView()
                .fill(flag ? UIColor.green : UIColor.yellow)
                .fillStyle(flag ? .hachure : .dots)
                .circle()
                .frame(width: flag ? 200 : 100, height: flag ? 200 : 100)
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

struct BrushStrokeView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // MARK: - Header
                VStack(spacing: 8) {
                    SwiftUI.Text("Custom Brush Profiles")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    SwiftUI.Text("Variable-width strokes with calligraphic effects")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // MARK: - Brush Tip Comparison
                VStack(spacing: 16) {
                    SwiftUI.Text("Brush Tips")
                        .font(.headline)
                    
                    SwiftUI.Text("Direction-sensitive ellipse-based brush tips")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 24) {
                        // Circular brush
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.blue)
                                .strokeWidth(4)
                                .brushTip(.circular)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Circular")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Calligraphic brush
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.purple)
                                .strokeWidth(4)
                                .brushTip(.calligraphic)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Calligraphic")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Flat brush
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.orange)
                                .strokeWidth(4)
                                .brushTip(.flat)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Flat")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Thickness Profiles
                VStack(spacing: 16) {
                    SwiftUI.Text("Thickness Profiles")
                        .font(.headline)
                    
                    SwiftUI.Text("Stroke width varies along the path")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Taper examples
                    VStack(spacing: 16) {
                        HStack(spacing: 24) {
                            // Uniform
                            VStack(spacing: 8) {
                                RoughView()
                                    .stroke(Color.gray)
                                    .strokeWidth(8)
                                    .thicknessProfile(.uniform)
                                    .draw(Line(from: Point(x: 10, y: 40), to: Point(x: 90, y: 40)))
                                    .frame(width: 100, height: 60)
                                
                                SwiftUI.Text("Uniform")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Taper In
                            VStack(spacing: 8) {
                                RoughView()
                                    .stroke(Color.green)
                                    .strokeWidth(8)
                                    .thicknessProfile(.taperIn(start: 0.3))
                                    .draw(Line(from: Point(x: 10, y: 40), to: Point(x: 90, y: 40)))
                                    .frame(width: 100, height: 60)
                                
                                SwiftUI.Text("Taper In")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Taper Out
                            VStack(spacing: 8) {
                                RoughView()
                                    .stroke(Color.red)
                                    .strokeWidth(8)
                                    .thicknessProfile(.taperOut(end: 0.3))
                                    .draw(Line(from: Point(x: 10, y: 40), to: Point(x: 90, y: 40)))
                                    .frame(width: 100, height: 60)
                                
                                SwiftUI.Text("Taper Out")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        HStack(spacing: 24) {
                            // Natural Pen
                            VStack(spacing: 8) {
                                RoughView()
                                    .stroke(Color.indigo)
                                    .strokeWidth(8)
                                    .thicknessProfile(.naturalPen)
                                    .draw(Line(from: Point(x: 10, y: 40), to: Point(x: 90, y: 40)))
                                    .frame(width: 100, height: 60)
                                
                                SwiftUI.Text("Natural Pen")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Pressure Curve
                            VStack(spacing: 8) {
                                RoughView()
                                    .stroke(Color.cyan)
                                    .strokeWidth(8)
                                    .thicknessProfile(.penPressure)
                                    .draw(Line(from: Point(x: 10, y: 40), to: Point(x: 90, y: 40)))
                                    .frame(width: 100, height: 60)
                                
                                SwiftUI.Text("Pressure")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // Custom profile
                            VStack(spacing: 8) {
                                RoughView()
                                    .stroke(Color.pink)
                                    .strokeWidth(8)
                                    .thicknessProfile(.custom([0.3, 1.0, 0.5, 1.0, 0.3]))
                                    .draw(Line(from: Point(x: 10, y: 40), to: Point(x: 90, y: 40)))
                                    .frame(width: 100, height: 60)
                                
                                SwiftUI.Text("Custom")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Stroke Caps & Joins
                VStack(spacing: 16) {
                    SwiftUI.Text("Stroke Caps & Joins")
                        .font(.headline)
                    
                    SwiftUI.Text("Customize line endings and corners")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 24) {
                        // Butt cap
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.brown)
                                .strokeWidth(10)
                                .strokeCap(.butt)
                                .draw(Line(from: Point(x: 20, y: 30), to: Point(x: 80, y: 30)))
                                .frame(width: 100, height: 50)
                            
                            SwiftUI.Text("Butt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Round cap
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.teal)
                                .strokeWidth(10)
                                .strokeCap(.round)
                                .draw(Line(from: Point(x: 20, y: 30), to: Point(x: 80, y: 30)))
                                .frame(width: 100, height: 50)
                            
                            SwiftUI.Text("Round")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Square cap
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.mint)
                                .strokeWidth(10)
                                .strokeCap(.square)
                                .draw(Line(from: Point(x: 20, y: 30), to: Point(x: 80, y: 30)))
                                .frame(width: 100, height: 50)
                            
                            SwiftUI.Text("Square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Complete Brush Profiles
                VStack(spacing: 16) {
                    SwiftUI.Text("Brush Profile Presets")
                        .font(.headline)
                    
                    SwiftUI.Text("Combined tip, thickness, and style settings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        // Calligraphic preset
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.black)
                                .strokeWidth(3)
                                .brushProfile(.calligraphic)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Calligraphic")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Marker preset
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.blue)
                                .strokeWidth(4)
                                .brushProfile(.marker)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Marker")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Pen preset
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.purple)
                                .strokeWidth(3)
                                .brushProfile(.pen)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Pen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Combined Example
                VStack(spacing: 16) {
                    SwiftUI.Text("Combined Effects")
                        .font(.headline)
                    
                    SwiftUI.Text("Custom brush tip + thickness profile on shapes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        // Rectangle with calligraphic + taper
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.black)
                                .strokeWidth(4)
                                .brushTip(roundness: 0.3, angle: .pi / 4, directionSensitive: true)
                                .thicknessProfile(.naturalPen)
                                .rectangle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Calligraphic\n+ Taper")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Circle with flat brush + pressure
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.indigo)
                                .strokeWidth(5)
                                .brushTip(.flat)
                                .thicknessProfile(.penPressure)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Flat\n+ Pressure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Ellipse with custom settings
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.teal)
                                .strokeWidth(4)
                                .brushTip(roundness: 0.5, angle: .pi / 6, directionSensitive: true)
                                .thicknessProfile(.taperBoth(start: 0.2, end: 0.2))
                                .draw(Ellipse(x: 50, y: 50, width: 90, height: 70))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Custom\nBrush")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Animated Brush Strokes
                VStack(spacing: 16) {
                    SwiftUI.Text("Animated Brush Strokes")
                        .font(.headline)
                    
                    SwiftUI.Text("Shapes with brush profiles + animation")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Animated shapes with brush profiles
                    HStack(spacing: 20) {
                        // Animated calligraphic ellipse
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.purple)
                                .fill(Color.purple.opacity(0.15))
                                .fillStyle(.hachure)
                                .strokeWidth(3)
                                .strokeCap(.round)
                                .strokeJoin(.round)
                                .draw(Ellipse(x: 50, y: 50, width: 90, height: 70))
                                .animated(steps: 6, speed: .slow, variance: .low)
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Animated rectangle with round caps
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.orange)
                                .fill(Color.orange.opacity(0.15))
                                .fillStyle(.crossHatch)
                                .strokeWidth(3)
                                .strokeCap(.round)
                                .strokeJoin(.round)
                                .rectangle()
                                .animated(steps: 8, speed: .medium, variance: .medium)
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Rectangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Animated circle with round styling
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.teal)
                                .fill(Color.teal.opacity(0.15))
                                .fillStyle(.dots)
                                .strokeWidth(3)
                                .strokeCap(.round)
                                .strokeJoin(.round)
                                .circle()
                                .animated(steps: 5, speed: .fast, variance: .low)
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Animated line with round caps
                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.indigo)
                            .strokeWidth(4)
                            .strokeCap(.round)
                            .draw(Line(from: Point(x: 20, y: 40), to: Point(x: 180, y: 40)))
                            .animated(steps: 6, speed: .slow, variance: .medium)
                            .frame(width: 200, height: 60)
                        
                        SwiftUI.Text("Animated line")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Multiple animated shapes in a row
                    HStack(spacing: 16) {
                        RoughView()
                            .stroke(Color.pink)
                            .fill(Color.pink.opacity(0.15))
                            .fillStyle(.sunBurst)
                            .strokeWidth(2)
                            .strokeCap(.round)
                            .circle()
                            .animated(steps: 5, speed: .medium, variance: .low)
                            .frame(width: 80, height: 80)
                        
                        RoughView()
                            .stroke(Color.green)
                            .fill(Color.green.opacity(0.15))
                            .fillStyle(.starBurst)
                            .strokeWidth(2)
                            .strokeCap(.round)
                            .rectangle()
                            .animated(steps: 7, speed: .slow, variance: .medium)
                            .frame(width: 80, height: 80)
                        
                        RoughView()
                            .stroke(Color.blue)
                            .fill(Color.blue.opacity(0.15))
                            .fillStyle(.dashed)
                            .strokeWidth(2)
                            .strokeCap(.round)
                            .draw(Ellipse(x: 40, y: 40, width: 70, height: 50))
                            .animated(steps: 6, speed: .fast, variance: .low)
                            .frame(width: 80, height: 80)
                    }
                    
                    SwiftUI.Text("More animated shapes with round caps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                    .frame(height: 40)
            }
            .padding()
        }
    }
    
}

struct ScribbleFillView: View {
    // Star path for concave shape example
    var starPath: String {
        "M50 0 L61 35 L98 35 L68 57 L79 91 L50 70 L21 91 L32 57 L2 35 L39 35 Z"
    }
    
    // Arrow/chevron path for another concave example
    var arrowPath: String {
        "M10 50 L50 10 L90 50 L70 50 L70 90 L30 90 L30 50 Z"
    }
    
    // Crescent moon path
    var crescentPath: String {
        "M50 5 A45 45 0 1 1 50 95 A30 30 0 1 0 50 5"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // MARK: - Header
                VStack(spacing: 8) {
                    SwiftUI.Text("Scribble Fill")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    SwiftUI.Text("A single continuous zig-zag traversing the shape")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)
                
                // MARK: - Convex Shapes
                VStack(spacing: 16) {
                    SwiftUI.Text("Convex Shapes")
                        .font(.headline)
                    
                    SwiftUI.Text("Simple shapes filled with scribble pattern")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        // Circle
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.blue)
                                .fill(Color.blue)
                                .fillStyle(.scribble)
                                .scribbleTightness(12)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Rectangle
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.green)
                                .fill(Color.green)
                                .fillStyle(.scribble)
                                .scribbleTightness(15)
                                .scribbleOrigin(45)
                                .rectangle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Rectangle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Ellipse
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.purple)
                                .fill(Color.purple)
                                .fillStyle(.scribble)
                                .scribbleTightness(10)
                                .scribbleOrigin(90)
                                .draw(Ellipse(x: 50, y: 50, width: 90, height: 60))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Ellipse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Concave Shapes
                VStack(spacing: 16) {
                    SwiftUI.Text("Concave Shapes")
                        .font(.headline)
                    
                    SwiftUI.Text("Complex shapes split into separate stroke segments")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        // Star
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.orange)
                                .fill(Color.orange)
                                .fillStyle(.scribble)
                                .scribbleTightness(20)
                                .draw(Path(d: starPath))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Star")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Arrow
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.red)
                                .fill(Color.red)
                                .fillStyle(.scribble)
                                .scribbleTightness(15)
                                .scribbleOrigin(0)
                                .draw(Path(d: arrowPath))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Arrow")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // Crescent
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.indigo)
                                .fill(Color.indigo)
                                .fillStyle(.scribble)
                                .scribbleTightness(18)
                                .draw(Path(d: crescentPath))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Crescent")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Tightness Comparison
                VStack(spacing: 16) {
                    SwiftUI.Text("Tightness")
                        .font(.headline)
                    
                    SwiftUI.Text("Number of zig-zags (density)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.cyan)
                                .fill(Color.cyan)
                                .fillStyle(.scribble)
                                .scribbleTightness(5)
                                .circle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("5")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.cyan)
                                .fill(Color.cyan)
                                .fillStyle(.scribble)
                                .scribbleTightness(15)
                                .circle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("15")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.cyan)
                                .fill(Color.cyan)
                                .fillStyle(.scribble)
                                .scribbleTightness(30)
                                .circle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("30")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.cyan)
                                .fill(Color.cyan)
                                .fillStyle(.scribble)
                                .scribbleTightness(50)
                                .circle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("50")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Curvature Comparison
                VStack(spacing: 16) {
                    SwiftUI.Text("Curvature")
                        .font(.headline)
                    
                    SwiftUI.Text("Smoothness of zig-zag corners (0-50)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.pink)
                                .fill(Color.pink)
                                .fillStyle(.scribble)
                                .scribble(tightness: 12, curvature: 0)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("0 (sharp)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.pink)
                                .fill(Color.pink)
                                .fillStyle(.scribble)
                                .scribble(tightness: 12, curvature: 15)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("15")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.pink)
                                .fill(Color.pink)
                                .fillStyle(.scribble)
                                .scribble(tightness: 12, curvature: 30)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("30")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.pink)
                                .fill(Color.pink)
                                .fillStyle(.scribble)
                                .scribble(tightness: 12, curvature: 50)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("50 (smooth)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Origin Angle
                VStack(spacing: 16) {
                    SwiftUI.Text("Origin Angle")
                        .font(.headline)
                    
                    SwiftUI.Text("Starting position on shape edge (0-360°)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.mint)
                                .fill(Color.mint)
                                .fillStyle(.scribble)
                                .scribble(origin: 0, tightness: 15)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("0° (right)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.mint)
                                .fill(Color.mint)
                                .fillStyle(.scribble)
                                .scribble(origin: 45, tightness: 15)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("45°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.mint)
                                .fill(Color.mint)
                                .fillStyle(.scribble)
                                .scribble(origin: 90, tightness: 15)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("90° (bottom)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.mint)
                                .fill(Color.mint)
                                .fillStyle(.scribble)
                                .scribble(origin: 135, tightness: 15)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("135°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Variable Tightness
                VStack(spacing: 16) {
                    SwiftUI.Text("Variable Tightness")
                        .font(.headline)
                    
                    SwiftUI.Text("Tightness pattern creates variable density sections")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.indigo)
                                .fill(Color.indigo)
                                .fillStyle(.scribble)
                                .scribble(origin: 0, tightnessPattern: [5, 20, 5], curvature: 25)
                                .rectangle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("[5,20,5]")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SwiftUI.Text("sparse-dense-sparse")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.orange)
                                .fill(Color.orange)
                                .fillStyle(.scribble)
                                .scribble(origin: 0, tightnessPattern: [3, 8, 15, 8, 3], curvature: 30)
                                .rectangle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("[3,8,15,8,3]")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SwiftUI.Text("gradient density")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.purple)
                                .fill(Color.purple)
                                .fillStyle(.scribble)
                                .scribble(origin: 0, tightnessPattern: [15, 5, 15, 5], curvature: 20)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("[15,5,15,5]")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            SwiftUI.Text("alternating")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - With Brush Strokes
                VStack(spacing: 16) {
                    SwiftUI.Text("With Brush Strokes")
                        .font(.headline)
                    
                    SwiftUI.Text("Variable-width strokes using brush profiles")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 20) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.brown)
                                .fill(Color.brown)
                                .fillStyle(.scribble)
                                .fillWeight(3)
                                .scribble(tightness: 10, curvature: 20, useBrushStroke: true)
                                .thicknessProfile(.penPressure)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Pressure")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.teal)
                                .fill(Color.teal)
                                .fillStyle(.scribble)
                                .fillWeight(3)
                                .scribble(tightness: 12, curvature: 25, useBrushStroke: true)
                                .thicknessProfile(.naturalPen)
                                .rectangle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Natural Pen")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.gray)
                                .fill(Color.gray)
                                .fillStyle(.scribble)
                                .fillWeight(3)
                                .scribble(tightness: 15, curvature: 30, useBrushStroke: true)
                                .brushTip(.calligraphic)
                                .draw(Ellipse(x: 50, y: 50, width: 90, height: 70))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("Calligraphic")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Opacity Examples
                VStack(spacing: 16) {
                    SwiftUI.Text("Opacity")
                        .font(.headline)
                    
                    SwiftUI.Text("Transparency for fill and stroke (0-100%)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.blue)
                                .strokeOpacity(100)
                                .fill(Color.blue)
                                .fillOpacity(30)
                                .fillStyle(.hachure)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Fill 30%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.green)
                                .strokeOpacity(50)
                                .fill(Color.green)
                                .fillOpacity(50)
                                .fillStyle(.crossHatch)
                                .circle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Both 50%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.red)
                                .strokeOpacity(20)
                                .fill(Color.red)
                                .fillOpacity(80)
                                .fillStyle(.solid)
                                .rectangle()
                                .frame(width: 80, height: 80)
                            
                            SwiftUI.Text("Stroke 20%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Divider()
                    .padding(.horizontal)
                
                // MARK: - Overlapping Scribbles with Opacity
                VStack(spacing: 16) {
                    SwiftUI.Text("Overlapping Scribbles")
                        .font(.headline)
                    
                    SwiftUI.Text("High tightness + heavy weight + low opacity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.clear)
                                .fill(Color.purple)
                                .fillOpacity(25)
                                .fillWeight(4)
                                .fillStyle(.scribble)
                                .scribble(tightness: 40, curvature: 35)
                                .circle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("T:40 W:4 O:25%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.clear)
                                .fill(Color.orange)
                                .fillOpacity(20)
                                .fillWeight(5)
                                .fillStyle(.scribble)
                                .scribble(tightness: 50, curvature: 40)
                                .rectangle()
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("T:50 W:5 O:20%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.clear)
                                .fill(Color.cyan)
                                .fillOpacity(15)
                                .fillWeight(6)
                                .fillStyle(.scribble)
                                .scribble(tightness: 60, curvature: 30)
                                .draw(Ellipse(x: 50, y: 50, width: 90, height: 70))
                                .frame(width: 100, height: 100)
                            
                            SwiftUI.Text("T:60 W:6 O:15%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // Extra large example showing the effect clearly
                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.indigo.opacity(0.3))
                            .strokeWidth(1)
                            .fill(Color.indigo)
                            .fillOpacity(12)
                            .fillWeight(8)
                            .fillStyle(.scribble)
                            .scribble(tightness: 80, curvature: 45)
                            .rectangle()
                            .frame(width: 280, height: 140)
                        
                        SwiftUI.Text("Dense overlapping: T:80 W:8 O:12%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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

#Preview("Brush Stroke View") {
    BrushStrokeView()
}

#Preview("Scribble Fill View") {
    ScribbleFillView()
}
