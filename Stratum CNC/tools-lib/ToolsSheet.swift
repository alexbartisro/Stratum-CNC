//
//  ToolsSheet.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 25.08.2026.
//

import SwiftUI
import UniformTypeIdentifiers

struct ToolsSheet: View {

    @ObservedObject var store: ToolsStore

    /// When set, the sheet shows a "Pick" button. Tapping it returns the selected
    /// tool through this closure and dismisses the sheet. Leave `nil` to browse/edit only.
    var onPick: ((Tool) -> Void)?
    @State private var selectedToolID: Tool.ID?
    @State private var toolPendingDeletion: Tool?
    @State private var inStockOnly = false
    @State private var isImporting = false
    @State private var importMessage: String?

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

    private var selectedTool: Tool? {
        store.tools.first { $0.id == selectedToolID }
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

            Button {
                isImporting = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if let onPick {
                Button("Pick") {
                    if let tool = selectedTool {
                        onPick(tool)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(selectedTool == nil)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [UTType(filenameExtension: "tools") ?? .data, .zip, .json]
        ) { result in
            handleImport(result)
        }
        .alert("Import Tools", isPresented: Binding(
            get: { importMessage != nil },
            set: { if !$0 { importMessage = nil } }
        )) {
            Button("OK") { importMessage = nil }
        } message: {
            Text(importMessage ?? "")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            let imported = try FusionToolsImporter.importTools(from: url)
            let counts = try store.importTools(imported.tools)

            var message = "Imported \(counts.added) tools."
            if counts.updated > 0 {
                message += " Added cutting parameters to \(counts.updated) existing tools."
            }
            if counts.skipped > 0 {
                message += " \(counts.skipped) already in the library were skipped."
            }
            if imported.unsupportedCount > 0 {
                message += " \(imported.unsupportedCount) unsupported entries (holders, taps, …) were ignored."
            }
            importMessage = message
        } catch {
            importMessage = error.localizedDescription
        }
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
