//
//  WhatsNewView.swift
//  SketchyDemoApp
//
//  Demo app for Sketchy.
//

import SwiftUI
import Sketchy

/// Fill inset, sticker backing, variable marker, width stops, opacity, watercolor, and SVG arcs.
struct WhatsNewView: View {
    private let ink = Color(red: 0.12, green: 0.14, blue: 0.18)
    private let blue = Color(red: 0.18, green: 0.46, blue: 0.67)
    private let wash = Color(red: 0.20, green: 0.48, blue: 0.62)

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    SwiftUI.Text("What's New")
                        .font(.title2)
                        .bold()

                    SwiftUI.Text("Stickers, fill placement, markers, and watercolor")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)

                section("Sticker backing", detail: "White, tinted, or grained paper behind the ink. Smoothness 1 follows the star. Torn chops the edge.") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            stickerSample("none", backing: nil)
                            stickerSample("close", backing: StickerBacking(width: 10, smoothness: 0.05))
                            stickerSample("silhouette", backing: StickerBacking(width: 10, smoothness: 1))
                            stickerSample("fully smooth", backing: StickerBacking(width: 10, smoothness: 1, edge: .fullySmooth()))
                            stickerSample(
                                "torn",
                                backing: StickerBacking(
                                    width: 12,
                                    smoothness: 0.45,
                                    edge: .torn(StickerTear(depth: 6, length: 12, jaggedness: 0.4))
                                )
                            )
                        }
                    }

                    HStack(spacing: 16) {
                        stickerSample(
                            "tint",
                            backing: StickerBacking(
                                width: 10,
                                smoothness: 1,
                                color: UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1)
                            )
                        )
                        stickerSample(
                            "grain",
                            backing: StickerBacking(width: 10, smoothness: 1, texture: .paper(seed: 6))
                        )
                        stickerSample(
                            "tint + grain",
                            backing: StickerBacking(
                                width: 10,
                                smoothness: 1,
                                color: UIColor(red: 0.96, green: 0.91, blue: 0.78, alpha: 1),
                                texture: .paper(amount: 0.55, seed: 6)
                            )
                        )
                    }
                }

                Divider()

                section("Fill Padding & Offset", detail: "The outline stays put. Padding insets the fill. Offset shifts it.") {
                    HStack(spacing: 16) {
                        fillSample("flush", padding: 0, offset: .zero)
                        fillSample("padding 14", padding: 14, offset: .zero)
                        fillSample("offset", padding: 0, offset: CGSize(width: 12, height: -10))
                    }
                }

                Divider()

                section("Variable Marker", detail: "An open stroke. Closed shapes keep an even width.") {
                    VStack(spacing: 16) {
                        markerLine("even", profile: .marker)
                        markerLine("variation 0.4", profile: .marker(variation: 0.4, seed: 4))
                        markerLine(
                            "tapered",
                            profile: .marker(variation: 0.35, taperStart: 0.18, taperEnd: 0.22, seed: 4)
                        )
                    }
                }

                Divider()

                section("Width Stops", detail: "Absolute widths in points. The flat marker tip still follows direction.") {
                    RoughView()
                        .stroke(blue)
                        .brushProfile(.marker)
                        .widthStops([(0, 3), (0.12, 16), (0.88, 16), (1, 3)])
                        .roughness(0.4)
                        .seed(149)
                        .draw(Curve(points: [
                            Point(x: 16, y: 78),
                            Point(x: 70, y: 22),
                            Point(x: 140, y: 86),
                            Point(x: 210, y: 30)
                        ]))
                        .frame(width: 230, height: 110)

                    SwiftUI.Text("3pt, then 16pt, then 3pt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                section("Opacity Profile", detail: "A multiplier on the stroke. Overlaps do not darken.") {
                    VStack(spacing: 16) {
                        opacityLine(
                            "stops",
                            profile: .stops([
                                OpacityStop(0.08, at: 0),
                                OpacityStop(1, at: 0.5),
                                OpacityStop(0.08, at: 1)
                            ])
                        )
                        opacityLine(
                            "noise",
                            profile: .noise(minimum: 0.2, maximum: 1, variation: 1, seed: 8, frequency: 3)
                        )
                    }
                }

                Divider()

                section("Watercolor", detail: "The brush is the wash. The fill clips a wash to the shape.") {
                    VStack(spacing: 20) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(wash)
                                .strokeWidth(18)
                                .brushProfile(.watercolor)
                                .seed(7)
                                .draw(Curve(points: [
                                    Point(x: 18, y: 72),
                                    Point(x: 80, y: 18),
                                    Point(x: 150, y: 80),
                                    Point(x: 220, y: 28)
                                ]))
                                .frame(width: 240, height: 100)
                            SwiftUI.Text("brush")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 20) {
                            VStack(spacing: 8) {
                                RoughView()
                                    .fill(wash)
                                    .fillStyle(.watercolor)
                                    .stroke(ink)
                                    .strokeWidth(2)
                                    .seed(11)
                                    .circle()
                                    .frame(width: 120, height: 120)
                                SwiftUI.Text("fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 8) {
                                RoughView()
                                    .fill(Color(red: 0.75, green: 0.45, blue: 0.28))
                                    .fillStyle(.watercolor)
                                    .fillPadding(8)
                                    .stroke(ink)
                                    .strokeWidth(2)
                                    .seed(12)
                                    .roundedRectangle(cornerRadius: 18)
                                    .frame(width: 120, height: 120)
                                SwiftUI.Text("fill + padding")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Divider()

                section("SVG Arcs", detail: "A and a become cubic segments, then take the same roughness as a curve.") {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(blue)
                                .strokeWidth(3)
                                .seed(31)
                                .draw(Path(d: "M20 78 A70 42 15 0 1 200 70"))
                                .frame(width: 230, height: 100)
                            SwiftUI.Text("open elliptical arc")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(ink)
                                .strokeWidth(2)
                                .fill(Color(red: 0.86, green: 0.55, blue: 0.24).opacity(0.85))
                                .fillStyle(.hachure)
                                .seed(32)
                                .draw(Path(d: "M30 88 A70 48 0 0 1 190 88 L190 96 A70 48 0 0 0 30 96 Z"))
                                .frame(width: 230, height: 80)
                            SwiftUI.Text("closed arc band")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func section<Content: View>(
        _ title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            SwiftUI.Text(title)
                .font(.headline)
            SwiftUI.Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            content()
        }
    }

    private func stickerSample(_ caption: String, backing: StickerBacking?) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(ink)
                .strokeWidth(1.6)
                .fill(blue)
                .fillStyle(.hachure)
                .fillAngle(0)
                .fillSpacing(2.6)
                .roughness(1.35)
                .seed(42)
                .stickerBacking(backing)
                .draw(Polygon(points: demoStar))
                .frame(width: 120, height: 120)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.27, green: 0.36, blue: 0.43))
                )
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var demoStar: [Point] {
        (0..<10).map { index in
            let angle = -Float.pi / 2 + Float(index) * .pi / 5
            let radius: Float = index.isMultiple(of: 2) ? 36 : 15
            return Point(x: 60 + cos(angle) * radius, y: 60 + sin(angle) * radius)
        }
    }

    private func fillSample(_ caption: String, padding: CGFloat, offset: CGSize) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(ink)
                .strokeWidth(2)
                .fill(Color.orange)
                .fillStyle(.hachure)
                .fillSpacing(3)
                .fillPadding(padding)
                .fillOffset(offset)
                .seed(3)
                .circle()
                .frame(width: 96, height: 96)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func markerLine(_ caption: String, profile: BrushProfile) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(Color(red: 0.15, green: 0.38, blue: 0.32))
                .strokeWidth(16)
                .brushProfile(profile)
                .seed(4)
                .draw(Line(from: Point(x: 14, y: 24), to: Point(x: 210, y: 24)))
                .frame(width: 230, height: 48)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func opacityLine(_ caption: String, profile: OpacityProfile) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(Color.indigo)
                .strokeWidth(14)
                .opacityProfile(profile)
                .seed(8)
                .draw(Line(from: Point(x: 14, y: 22), to: Point(x: 210, y: 22)))
                .frame(width: 230, height: 44)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("What's New") {
    WhatsNewView()
}
