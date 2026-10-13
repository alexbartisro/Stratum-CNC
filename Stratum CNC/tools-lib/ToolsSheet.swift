//
//  ToolsSheet.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 25.08.2026.
//

import SwiftUI

struct ToolsSheet: View {

    @ObservedObject var store: ToolsStore
    @State private var selectedToolID: Tool.ID?
    @State private var toolPendingDeletion: Tool?
    @State private var inStockOnly = false

    /// Tools shown in the list, after applying the in-stock filter.
    private var visibleTools: [Tool] {
        inStockOnly ? store.tools.filter { $0.quantity > 0 } : store.tools
    }

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            NavigationSplitView {
                ToolListView(
                    tools: visibleTools,
                    selectedToolID: $selectedToolID,
                    inStockOnly: $inStockOnly,
                    onDuplicate: duplicateTool,
                    onDelete: { toolPendingDeletion = $0 }
                )
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 400)
            } detail: {
                if let selectedToolID,
                   let index = store.tools.firstIndex(where: { $0.id == selectedToolID }) {
                    ToolEditorView(
                        tool: Binding(
                            get: { store.tools[index] },
                            set: { store.tools[index] = $0 }
                        ),
                        hasUnsavedChanges: store.hasUnsavedChanges,
                        onSave: {
                            do {
                                try store.save()
                            } catch {
                                print("Failed to save tools: \(error)")
                            }
                        },
                        onRevert: {
                            store.revertChanges()
                        }
                    )
                } else {
                    ContentUnavailableView(
                        "No Tool Selected",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Select a tool from the list.")
                    )
                }
            }
            .navigationTitle("Tools")
            .onAppear(perform: selectFirstIfNeeded)
            .onChange(of: inStockOnly) { _ in
                let visible = visibleTools
                if !visible.contains(where: { $0.id == selectedToolID }) {
                    selectedToolID = visible.groupedByGroup.first?.tools.first?.id
                }
            }
            .confirmationDialog(
                "Delete \"\(toolPendingDeletion?.name ?? "")\"?",
                isPresented: Binding(
                    get: { toolPendingDeletion != nil },
                    set: { if !$0 { toolPendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: toolPendingDeletion
            ) { tool in
                Button("Delete", role: .destructive) {
                    deleteTool(tool)
                }
            } message: { _ in
                Text("This can't be undone.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Tools")
                .font(.title2.weight(.semibold))

            Spacer()

            Button {
                addTool()
            } label: {
                Label("Add Tool", systemImage: "plus")
            }

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    /// Selects the first item as displayed in the (grouped) list.
    private func selectFirstIfNeeded() {
        guard selectedToolID == nil else { return }
        selectedToolID = visibleTools.groupedByGroup.first?.tools.first?.id
    }

    private func duplicateTool(_ tool: Tool) {
        do {
            let copy = try store.duplicate(tool)
            selectedToolID = copy.id
        } catch {
            print("Failed to duplicate tool: \(error)")
        }
    }

    private func deleteTool(_ tool: Tool) {
        // Pick the neighbour in the displayed (grouped) order before deleting.
        let ordered = visibleTools.groupedByGroup.flatMap(\.tools)
        let position = ordered.firstIndex(where: { $0.id == tool.id })

        do {
            try store.delete(tool)
        } catch {
            print("Failed to delete tool: \(error)")
            return
        }

        guard selectedToolID == tool.id else { return }
        let remaining = visibleTools.groupedByGroup.flatMap(\.tools)
        if let position, !remaining.isEmpty {
            selectedToolID = remaining[min(position, remaining.count - 1)].id
        } else {
            selectedToolID = nil
        }
    }

    private func addTool() {
        // New tools join the group of the currently selected tool.
        let currentGroup = store.tools.first(where: { $0.id == selectedToolID })?.group
        let tool = Tool(
            name: "New Tool",
            shankDiameter: 3.175,
            toolDiameter: 1,
            length: 10,
            type: .endMill,
            group: currentGroup
        )

        do {
            try store.add(tool)
            selectedToolID = tool.id
        } catch {
            print("Failed to add tool: \(error)")
        }
    }
}
