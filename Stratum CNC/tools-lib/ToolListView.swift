//
//  ToolListView.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 25.08.2026.
//

import SwiftUI

struct ToolGroup: Identifiable {
    let name: String
    let tools: [Tool]
    var id: String { name }
}

extension Array where Element == Tool {

    /// Groups tools by `Tool.group`, keeping the order in which groups first appear.
    /// Tools without a group are collected in "Other", shown last.
    var groupedByGroup: [ToolGroup] {
        let otherName = "Other"
        var order: [String] = []
        var buckets: [String: [Tool]] = [:]

        for tool in self {
            let name = tool.group ?? otherName
            if buckets[name] == nil { order.append(name) }
            buckets[name, default: []].append(tool)
        }

        if let index = order.firstIndex(of: otherName) {
            order.append(order.remove(at: index))
        }
        return order.map { ToolGroup(name: $0, tools: buckets[$0] ?? []) }
    }
}

extension Tool {

    /// Geometry parameters only (the type is shown by the icon), using the same abbreviations as the editor
    /// (DS shank diameter, DC tool diameter, L length, TA tip angle).
    var listSubtitle: String {
        func number(_ value: Double) -> String {
            String(format: "%g", value)
        }

        var parts = [
            "DS \(number(shankDiameter))",
            "DC \(number(toolDiameter))"
        ]
        if let length, length > 0 {
            parts.append("L \(number(length))")
        }

        var text = parts.joined(separator: " · ") + " mm"
        if let tipAngle {
            text += " · TA \(number(tipAngle))°"
        }
        return text
    }
}

struct ToolListView: View {

    let tools: [Tool]

    @Binding var selectedToolID: Tool.ID?
    @Binding var inStockOnly: Bool
    @Binding var metalOnly: Bool
    let onDuplicate: (Tool) -> Void
    let onDelete: (Tool) -> Void

    var body: some View {
        List(selection: $selectedToolID) {
            ForEach(tools.groupedByGroup) { group in
                Section(group.name) {
                    ForEach(group.tools) { tool in
                        HStack(spacing: 10) {
                            ToolTypeIcon(type: tool.type)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(tool.name)
                                Text(tool.listSubtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 8)

                            Text("\(tool.quantity)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(tool.quantity == 0 ? .tertiary : .secondary)
                        }
                        .tag(tool.id)
                        .contextMenu {
                            Button {
                                onDuplicate(tool)
                            } label: {
                                Label("Duplicate", systemImage: "plus.square.on.square")
                            }

                            Divider()

                            Button(role: .destructive) {
                                onDelete(tool)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if tools.isEmpty {
                ContentUnavailableView(
                    "No Tools",
                    systemImage: "tray",
                    description: Text("No tools match the current filters.")
                )
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 16) {
                    Toggle("In stock only", isOn: $inStockOnly)
                    Toggle("Metal only", isOn: $metalOnly)
                        .help("Tools whose presets, name or group point to metal cutting")
                }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.bar)
        }
        .navigationTitle("Tool Library")
    }
}
