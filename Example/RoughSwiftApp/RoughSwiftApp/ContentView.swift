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
