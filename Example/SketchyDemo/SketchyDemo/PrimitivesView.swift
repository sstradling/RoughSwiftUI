//
//  PrimitivesView.swift
//  SketchyDemo
//
//  Demo app for Sketchy.
//

import SwiftUI
import Sketchy

struct PrimitivesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    SwiftUI.Text("Primitive Drawables")
                        .font(.title2)
                        .bold()

                    SwiftUI.Text("Every base drawable supported by the generator")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                LazyVGrid(columns: [.init(), .init()], spacing: 24) {
                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.blue)
                            .strokeWidth(4)
                            .draw(Line(from: Point(x: 15, y: 65), to: Point(x: 135, y: 25)))
                            .frame(width: 150, height: 90)

                        SwiftUI.Text("Line")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.green)
                            .strokeWidth(3)
                            .draw(LinearPath(points: [
                                Point(x: 15, y: 70),
                                Point(x: 45, y: 25),
                                Point(x: 75, y: 60),
                                Point(x: 105, y: 20),
                                Point(x: 135, y: 55)
                            ]))
                            .frame(width: 150, height: 90)

                        SwiftUI.Text("LinearPath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.orange)
                            .fill(Color.orange.opacity(0.25))
                            .fillStyle(.hachure)
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

                        SwiftUI.Text("Arc")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.purple)
                            .strokeWidth(3)
                            .curveTightness(0.8)
                            .curveStepCount(14)
                            .draw(Curve(points: [
                                Point(x: 10, y: 65),
                                Point(x: 35, y: 15),
                                Point(x: 75, y: 70),
                                Point(x: 115, y: 20),
                                Point(x: 140, y: 55)
                            ]))
                            .frame(width: 150, height: 90)

                        SwiftUI.Text("Curve")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.red)
                            .fill(Color.red.opacity(0.25))
                            .fillStyle(.crossHatch)
                            .draw(Polygon(points: [
                                Point(x: 75, y: 10),
                                Point(x: 135, y: 40),
                                Point(x: 115, y: 80),
                                Point(x: 35, y: 80),
                                Point(x: 15, y: 40)
                            ]))
                            .frame(width: 150, height: 90)

                        SwiftUI.Text("Polygon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 8) {
                        RoughView()
                            .stroke(Color.teal)
                            .fill(Color.teal.opacity(0.25))
                            .fillStyle(.dots)
                            .draw(Rectangle(x: 20, y: 18, width: 110, height: 55))
                            .draw(Ellipse(x: 75, y: 45, width: 80, height: 50))
                            .frame(width: 150, height: 90)

                        SwiftUI.Text("Composed draw()")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
    }
}
