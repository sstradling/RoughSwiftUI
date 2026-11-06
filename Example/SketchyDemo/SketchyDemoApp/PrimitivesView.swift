//
//  PrimitivesView.swift
//  SketchyDemoApp
//
//  Demo app for Sketchy.
//

import SwiftUI
import Sketchy

/// Line, linear path, arc, curve, polygon, and a view that draws more than one shape.
struct PrimitivesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    SwiftUI.Text("Primitive Drawables")
                        .font(.title2)
                        .bold()

                    SwiftUI.Text("Shapes placed with draw()")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                LazyVGrid(columns: [.init(), .init()], spacing: 24) {
                    tile("Line") {
                        RoughView()
                            .stroke(Color.blue)
                            .strokeWidth(4)
                            .seed(11)
                            .draw(Line(from: Point(x: 15, y: 65), to: Point(x: 135, y: 25)))
                            .frame(width: 150, height: 90)
                    }

                    tile("LinearPath") {
                        RoughView()
                            .stroke(Color.green)
                            .strokeWidth(3)
                            .seed(12)
                            .draw(LinearPath(points: [
                                Point(x: 15, y: 70),
                                Point(x: 45, y: 25),
                                Point(x: 75, y: 60),
                                Point(x: 105, y: 20),
                                Point(x: 135, y: 55)
                            ]))
                            .frame(width: 150, height: 90)
                    }

                    tile("Arc") {
                        RoughView()
                            .stroke(Color.orange)
                            .fill(Color.orange.opacity(0.25))
                            .fillStyle(.hachure)
                            .seed(13)
                            .draw(Arc(
                                x: 75,
                                y: 45,
                                width: 120,
                                height: 70,
                                start: 0,
                                stop: Float.pi * 1.35,
                                closed: true
                            ))
                            .frame(width: 150, height: 90)
                    }

                    tile("Curve") {
                        RoughView()
                            .stroke(Color.purple)
                            .strokeWidth(3)
                            .curveTightness(0.8)
                            .curveStepCount(14)
                            .seed(14)
                            .draw(Curve(points: [
                                Point(x: 10, y: 65),
                                Point(x: 35, y: 15),
                                Point(x: 75, y: 70),
                                Point(x: 115, y: 20),
                                Point(x: 140, y: 55)
                            ]))
                            .frame(width: 150, height: 90)
                    }

                    tile("Polygon") {
                        RoughView()
                            .stroke(Color.red)
                            .fill(Color.red.opacity(0.25))
                            .fillStyle(.crossHatch)
                            .seed(15)
                            .draw(Polygon(points: [
                                Point(x: 75, y: 10),
                                Point(x: 135, y: 40),
                                Point(x: 115, y: 80),
                                Point(x: 35, y: 80),
                                Point(x: 15, y: 40)
                            ]))
                            .frame(width: 150, height: 90)
                    }

                    tile("Composed draw()") {
                        RoughView()
                            .stroke(Color.teal)
                            .fill(Color.teal.opacity(0.25))
                            .fillStyle(.dots)
                            .seed(16)
                            .draw(Rectangle(x: 20, y: 18, width: 110, height: 55))
                            .draw(Ellipse(x: 75, y: 45, width: 80, height: 50))
                            .frame(width: 150, height: 90)
                    }
                }
            }
            .padding()
        }
    }

    private func tile<Content: View>(_ caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 8) {
            content()
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Primitives") {
    PrimitivesView()
}
