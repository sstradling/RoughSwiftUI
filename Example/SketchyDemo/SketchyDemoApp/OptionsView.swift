//
//  OptionsView.swift
//  SketchyDemoApp
//
//  Demo app for Sketchy.
//

import SwiftUI
import Sketchy

/// Fill spacing, dash length, zigzag pitch, and how rough a stroke is allowed to be.
struct OptionsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    SwiftUI.Text("Options Gallery")
                        .font(.title2)
                        .bold()

                    SwiftUI.Text("Spacing, dashes, zigzag pitch, and roughness")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                section("Fill Spacing", detail: "1 is tighter than the default of 4. 10 is sparse.") {
                    HStack(spacing: 16) {
                        sample("1", color: .blue, spacing: 1)
                        sample("4", color: .green, spacing: 4)
                        sample("10", color: .red, spacing: 10)
                    }
                }

                Divider()

                section("Dash Controls") {
                    HStack(spacing: 16) {
                        dashSample("short", color: .indigo, offset: 2, gap: 3)
                        dashSample("balanced", color: .orange, offset: 8, gap: 8)
                        dashSample("long dash", color: .pink, offset: 14, gap: 4)
                    }
                }

                Divider()

                section("Zigzag Offset") {
                    HStack(spacing: 16) {
                        zigzagSample("offset 2", color: .mint, offset: 2)
                        zigzagSample("offset 8", color: .cyan, offset: 8)
                        zigzagSample("offset 16", color: .purple, offset: 16)
                    }
                }

                Divider()

                section("Stroke continuity", detail: "Same seed. Continuous is the default: four cubics per pass. Legacy samples the circle.") {
                    HStack(spacing: 16) {
                        continuitySample("legacy", continuity: .legacy)
                        continuitySample("continuous", continuity: .continuous)
                    }
                }

                Divider()

                section("Randomness", detail: "maxRandomnessOffset and roughness. The middle tile is the default.") {
                    HStack(spacing: 16) {
                        roughSample("subtle", color: .gray, randomness: 0.5, roughness: 0.2)
                        roughSample("default", color: .brown, randomness: 2, roughness: 1)
                        roughSample("rough", color: .black, randomness: 8, roughness: 2.5)
                    }
                }
            }
            .padding()
        }
    }

    private func section<Content: View>(
        _ title: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 16) {
            SwiftUI.Text(title)
                .font(.headline)
            if let detail {
                SwiftUI.Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            content()
        }
    }

    private func sample(_ caption: String, color: Color, spacing: Float) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .fill(color)
                .fillStyle(.hachure)
                .fillSpacing(spacing)
                .seed(21)
                .circle()
                .frame(width: 90, height: 90)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func dashSample(_ caption: String, color: Color, offset: Float, gap: Float) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(color)
                .fill(color.opacity(0.25))
                .fillStyle(.dashed)
                .dashOffset(offset)
                .dashGap(gap)
                .seed(22)
                .rectangle()
                .frame(width: 100, height: 90)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func zigzagSample(_ caption: String, color: Color, offset: Float) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .fill(color)
                .fillStyle(.zigzag)
                .zigzagOffset(offset)
                .seed(23)
                .circle()
                .frame(width: 90, height: 90)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func continuitySample(_ caption: String, continuity: StrokeContinuity) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(Color(red: 0.12, green: 0.14, blue: 0.18))
                .strokeWidth(3)
                .roughness(1.4)
                .strokeContinuity(continuity)
                .seed(42)
                .circle()
                .frame(width: 120, height: 120)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func roughSample(_ caption: String, color: Color, randomness: Float, roughness: Float) -> some View {
        VStack(spacing: 8) {
            RoughView()
                .stroke(color)
                .fill(color.opacity(0.2))
                .fillStyle(.hachure)
                .maxRandomnessOffset(randomness)
                .roughness(roughness)
                .seed(24)
                .roundedRectangle(cornerRadius: 16)
                .frame(width: 90, height: 90)
            SwiftUI.Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Options") {
    OptionsView()
}
