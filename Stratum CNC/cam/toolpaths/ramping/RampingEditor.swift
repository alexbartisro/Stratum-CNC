//
// RampingEditor.swift
// Stratum CNC
//
// Created by Cristian Baluta on 24.08.2026.
//

import SwiftUI

struct RampingEditor: View {
    @Binding var ramping: RampingSettings
    /// Max Z the ramp may descend before cutting at full depth. This comes
    /// from your existing cutting parameters (depth-per-pass / stepdown),
    /// not from RampingSettings — passed in so the diagrams can enforce it.
    let stepdown: Double
    @Environment(\.dismiss)
    private var dismiss
    // See the note at the top of this file — move these onto RampingSettings
    // once you're ready to persist them.
    @State private var helixDirection: HelixDirection = .outsideIn

    var body: some View {
        Form {
            Section {
                RampTypeSelector(
                    type: $ramping.type,
                    angle: ramping.angle,
                    length: ramping.length,
                    stepdown: stepdown,
                    helixDirection: helixDirection
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            } header: {
                Text("Ramp type")
            }

            Section {
                RampVisualization(
                    type: ramping.type,
                    angle: ramping.angle,
                    length: ramping.length,
                    stepdown: stepdown,
                    mode: .profileDetail,
                    helixDirection: helixDirection
                )
                .frame(height: RampGeometry.detailSize)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.rampCardBackground))
                )
                .animation(.easeInOut(duration: 0.2), value: ramping.type)

                if ramping.type == .helix {
                    Picker("Spiral direction", selection: $helixDirection) {
                        ForEach(HelixDirection.allCases) { dir in
                            Text(dir.rawValue).tag(dir)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text(rampDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !rampMetrics.isEmpty {
                    Text(rampMetrics)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if ramping.type != .none {
                Section {
                    HStack {
                        Text("Ramp angle")
                        Spacer()
                        TextField(
                            "",
                            value: $ramping.angle,
                            format: .number
                        )
                        .multilineTextAlignment(.trailing)
                        Text("°")
                            .foregroundStyle(.secondary)
                    }

                    if ramping.type == .linear {
                        HStack {
                            Text("Required ramp distance")
                            Spacer()
                            Text(String(format: "%.2f mm", linearRampLength))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text("Calculated automatically from the angle and current stepdown. It is not editable.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Ramp length")
                            Spacer()
                            TextField(
                                "",
                                value: $ramping.length,
                                format: .number
                            )
                            .multilineTextAlignment(.trailing)
                            Text("mm")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear {
            syncLinearRampLength()
        }
        .onChange(of: ramping.type) { _, _ in
            syncLinearRampLength()
        }
        .onChange(of: ramping.angle) { _, _ in
            syncLinearRampLength()
        }
        .onChange(of: stepdown) { _, _ in
            syncLinearRampLength()
        }
        .padding(16)
    }

    private func syncLinearRampLength() {
        guard ramping.type == .linear else { return }
        ramping.length = linearRampLength
    }

    private var linearRampLength: Double {
        RampMath.linearRequiredLength(angle: ramping.angle, stepdown: stepdown)
    }

    private var rampDescription: String {
        switch ramping.type {
        case .none:
            return "The tool plunges vertically."
        case .linear:
            let result = RampMath.linearRampOutcome(angle: ramping.angle, length: ramping.length, stepdown: stepdown)
            if result.reachesStepdown {
                return "The tool descends at \(String(format: "%.1f", ramping.angle))° over half of the ramp distance, then returns to the start point descending the rest of the way, reaching the \(String(format: "%.2f", stepdown)) mm stepdown. The distance is calculated automatically."
            } else {
                return "⚠️ At this angle, \(String(format: "%.1f", ramping.length)) mm of ramp length only reaches \(String(format: "%.2f", result.depth)) mm — short of the \(String(format: "%.2f", stepdown)) mm stepdown. Increase length or use a shallower angle."
            }
        case .helix:
            switch helixDirection {
            case .outsideIn:
                return "The tool spirals downward from the outside edge inward, shown here from above."
            case .insideOut:
                return "The tool spirals downward from the center outward, shown here from above."
            }
        }
    }

    private var rampMetrics: String {
        switch ramping.type {
        case .linear:
            let result = RampMath.linearRampOutcome(angle: ramping.angle, length: ramping.length, stepdown: stepdown)
            if result.reachesStepdown {
                return String(format: "Required distance: %.2f mm at %.1f°", result.usedLength, RampMath.clampedAngle(ramping.angle))
            } else {
                return String(format: "Needs ≥ %.1f mm at this angle to reach stepdown", RampMath.linearRequiredLength(angle: ramping.angle, stepdown: stepdown))
            }
        case .helix:
            let turns = RampMath.helixTurnsNeeded(angle: ramping.angle, diameter: ramping.length, stepdown: stepdown)
            return String(format: "%.1f turns to reach the %.2f mm stepdown", turns, stepdown)
        case .none:
            return ""
        }
    }
}
