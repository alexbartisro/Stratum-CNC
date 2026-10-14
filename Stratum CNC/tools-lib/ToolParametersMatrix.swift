//
//  ToolParametersMatrix.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 27.08.2026.
//

import SwiftUI

struct ToolParametersMatrix: View {
    let tool: Tool

    private let columns = [
        GridItem(.fixed(120), alignment: .leading),
        GridItem(.flexible(), alignment: .trailing),
        GridItem(.flexible(), alignment: .trailing),
        GridItem(.flexible(), alignment: .trailing),
        GridItem(.flexible(), alignment: .trailing),
        GridItem(.flexible(), alignment: .trailing),
        GridItem(.flexible(), alignment: .trailing)
    ]

    /// Presets in alphabetical order by name.
    private var sortedPresets: [ToolPreset] {
        tool.presets.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {

            // Header
            headerCell("Material", alignment: .leading)
            headerCell("Spindle RPM")
            headerCell("Feed Rate")
            headerCell("Plunge Feed")
            headerCell("Depth of Cut")
            headerCell("Step Down")
            headerCell("Ramp Angle")

            // Rows
            ForEach(sortedPresets) { preset in
                cell(preset.name, alignment: .leading)
                cell(preset.spindleRPM.map { "\($0)" })
                cell(preset.feedRate.map(format))
                cell(preset.plungeFeedRate.map(format))
                cell(preset.depthOfCut.map(format))
                cell(preset.stepDown.map(format))
                cell(preset.rampAngle.map(format))
            }
        }
        .padding()
    }

    private func headerCell(_ text: String, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.vertical, 10)
    }

    private func cell(_ text: String?, alignment: Alignment = .trailing) -> some View {
        Text(text ?? "–")
            .foregroundStyle(text == nil ? .secondary : .primary)
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                Divider()
            }
    }

    private func format(_ value: Double) -> String {
        value == floor(value)
            ? String(format: "%.0f", value)
            : String(format: "%.2f", value)
    }
}
