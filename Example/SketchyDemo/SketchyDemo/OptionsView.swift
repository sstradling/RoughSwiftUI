//
//  OptionsView.swift
//  SketchyDemo
//
//  Demo app for Sketchy.
//

import SwiftUI
import Sketchy

struct OptionsView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    SwiftUI.Text("Options Gallery")
                        .font(.title2)
                        .bold()

                    SwiftUI.Text("Fine-grained rendering controls")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top)

                VStack(spacing: 16) {
                    SwiftUI.Text("Fill Spacing")
                        .font(.headline)

                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.blue)
                                .fillStyle(.hachure)
                                .fillSpacing(1)
                                .circle()
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("1x dense")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.green)
                                .fillStyle(.hachure)
                                .fillSpacing(4)
                                .circle()
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("4x default")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.red)
                                .fillStyle(.hachure)
                                .fillSpacing(10)
                                .circle()
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("10x sparse")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    SwiftUI.Text("Dash Controls")
                        .font(.headline)

                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.indigo)
                                .fill(Color.indigo.opacity(0.25))
                                .fillStyle(.dashed)
                                .dashOffset(2)
                                .dashGap(3)
                                .rectangle()
                                .frame(width: 100, height: 90)

                            SwiftUI.Text("short")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.orange)
                                .fill(Color.orange.opacity(0.25))
                                .fillStyle(.dashed)
                                .dashOffset(8)
                                .dashGap(8)
                                .rectangle()
                                .frame(width: 100, height: 90)

                            SwiftUI.Text("balanced")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.pink)
                                .fill(Color.pink.opacity(0.25))
                                .fillStyle(.dashed)
                                .dashOffset(14)
                                .dashGap(4)
                                .rectangle()
                                .frame(width: 100, height: 90)

                            SwiftUI.Text("long dash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    SwiftUI.Text("Zigzag Offset")
                        .font(.headline)

                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.mint)
                                .fillStyle(.zigzag)
                                .zigzagOffset(2)
                                .circle()
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("offset 2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.cyan)
                                .fillStyle(.zigzag)
                                .zigzagOffset(8)
                                .circle()
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("offset 8")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .fill(Color.purple)
                                .fillStyle(.zigzag)
                                .zigzagOffset(16)
                                .circle()
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("offset 16")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider()
                    .padding(.horizontal)

                VStack(spacing: 16) {
                    SwiftUI.Text("Randomness")
                        .font(.headline)

                    HStack(spacing: 16) {
                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.gray)
                                .fill(Color.gray.opacity(0.2))
                                .fillStyle(.hachure)
                                .maxRandomnessOffset(1)
                                .roughness(0.3)
                                .roundedRectangle(cornerRadius: 16)
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("subtle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.brown)
                                .fill(Color.brown.opacity(0.2))
                                .fillStyle(.hachure)
                                .maxRandomnessOffset(3)
                                .roughness(1)
                                .roundedRectangle(cornerRadius: 16)
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("default-ish")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(spacing: 8) {
                            RoughView()
                                .stroke(Color.black)
                                .fill(Color.black.opacity(0.12))
                                .fillStyle(.hachure)
                                .maxRandomnessOffset(8)
                                .roughness(2.5)
                                .roundedRectangle(cornerRadius: 16)
                                .frame(width: 90, height: 90)

                            SwiftUI.Text("rough")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
    }
}
