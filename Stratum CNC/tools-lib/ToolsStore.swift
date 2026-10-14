//
//  ToolStore.swift
//  Stratum CNC
//
//  Created by Cristian Baluta on 25.08.2026.
//

import Foundation
import Observation

@MainActor
final class ToolsStore: ObservableObject {

    private(set) var library: ToolLibrary?
    @Published var tools: [Tool] = []

    /// Snapshot of what is on disk. Edits are live in `tools`; `save()` writes them out.
    @Published private var savedTools: [Tool] = []

    var hasUnsavedChanges: Bool {
        tools != savedTools
    }

    private let fileManager = FileManager.default

    private var documentDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var toolsFileURL: URL {
        documentDirectory.appendingPathComponent("tools.json")
    }

    init() {
        do {
            try load()
        } catch {
            print("Failed to load tools: \(error)")
            tools = []
        }
    }

    func load() throws {
        if !fileManager.fileExists(atPath: toolsFileURL.path) {
            try copyDefaultTools()
        }

        let data = try Data(contentsOf: toolsFileURL)

        let decoder = JSONDecoder()
        library = try decoder.decode(ToolLibrary.self, from: data)
        tools = library?.tools ?? []
        savedTools = tools
    }

    func save() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        // Write the whole library (not just the array) so `load()` can read it back.
        guard var library else {
            throw ToolStoreError.libraryNotLoaded
        }
        library.tools = tools
        self.library = library
        let data = try encoder.encode(library)

        try data.write(to: toolsFileURL, options: .atomic)
        savedTools = tools
    }

    /// Discards all edits made since the last save.
    func revertChanges() {
        tools = savedTools
    }

    func update(_ tool: Tool) throws {
        guard let index = tools.firstIndex(where: { $0.id == tool.id }) else {
            return
        }

        tools[index] = tool
        try save()
    }

    func add(_ tool: Tool) throws {
        tools.append(tool)
        try save()
    }

    @discardableResult
    func duplicate(_ tool: Tool) throws -> Tool {
        let copy = Tool(
            name: "\(tool.name) Copy",
            shankDiameter: tool.shankDiameter,
            toolDiameter: tool.toolDiameter,
            length: tool.length,
            type: tool.type,
            group: tool.group,
            quantity: tool.quantity,
            link: tool.link,
            tipAngle: tool.tipAngle,
            parameters: tool.parameters
        )
        try add(copy)
        return copy
    }

    /// Adds imported tools, skipping any whose id is already in the library
    /// (re-importing the same file doesn't create duplicates), then saves once.
    /// An existing tool that has no cutting parameters yet gets the imported ones,
    /// so tools imported before presets were supported are filled in on re-import.
    @discardableResult
    func importTools(_ imported: [Tool]) throws -> (added: Int, updated: Int, skipped: Int) {
        var indexByID: [UUID: Int] = [:]
        for (index, tool) in tools.enumerated() { indexByID[tool.id] = index }

        var added = 0, updated = 0, skipped = 0
        for tool in imported {
            if let index = indexByID[tool.id] {
                if tools[index].parameters.isEmpty && !tool.parameters.isEmpty {
                    tools[index].parameters = tool.parameters
                    updated += 1
                } else {
                    skipped += 1
                }
            } else {
                tools.append(tool)
                added += 1
            }
        }

        if added + updated > 0 { try save() }
        return (added, updated, skipped)
    }

    func delete(_ tool: Tool) throws {
        tools.removeAll { $0.id == tool.id }
        try save()
    }

    private func copyDefaultTools() throws {
        guard let bundledURL = Bundle.main.url(forResource: "default_tools", withExtension: "json") else {
            throw ToolStoreError.defaultToolsNotFound
        }

        try fileManager.copyItem(at: bundledURL, to: toolsFileURL)
    }
}

enum ToolStoreError: LocalizedError {
    case defaultToolsNotFound
    case libraryNotLoaded

    var errorDescription: String? {
        switch self {
        case .defaultToolsNotFound:
            "The bundled default_tools.json could not be found."
        case .libraryNotLoaded:
            "The tool library is not loaded, so it can't be saved."
        }
    }
}
