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

    var body: some View {
        VStack {
            Button(action: {
                flag.toggle()
            }) {
                Text("Click")
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

            RoughView()
                .fill(Color.yellow)
                .fillStyle(.zigzag)
                .circle()
                .frame(width: 100, height: 100)

            RoughView()
                .fill(Color(.systemTeal))
                .fillStyle(.zigzagLine)
                .circle()
                .animated(steps: 10, speed: .fast, variance: .veryLow)
                .frame(width: 100, height: 100)
            
            RoughView()
                .fill(Color.pink)
                .fillStyle(.hachure)
                .circle()
                .animated(steps: 6, speed: .medium, variance: .medium)
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

struct AnimatedView: View {
    var body: some View {
        VStack(spacing: 24) {
            Text("Animated Rough Shapes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Watch the strokes subtly shift and wobble")
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
                    
                    Text("Slow")
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
                    
                    Text("Medium")
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
                    
                    Text("Fast")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Variance comparison row
            HStack(spacing: 20) {
                VStack {
                    RoughView()
                        .fill(Color.purple)
                        .fillStyle(.zigzag)
                        .rectangle()
                        .animated(steps: 5, speed: .medium, variance: .low)
                        .frame(width: 80, height: 80)
                    
                    Text("Low Variance")
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
                    
                    Text("Medium")
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
                    
                    Text("High Variance")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
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

#Preview("Animated View") {
    AnimatedView()
}
