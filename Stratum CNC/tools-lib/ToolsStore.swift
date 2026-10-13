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

    private var applicationSupportURL: URL {
        fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
    }

    private var toolsDirectoryURL: URL {
        applicationSupportURL.appendingPathComponent("Tools", isDirectory: true)
    }

    private var toolsFileURL: URL {
        toolsDirectoryURL.appendingPathComponent("tools.json")
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
        try createDirectoryIfNeeded()

        try? fileManager.removeItem(atPath: toolsFileURL.path)

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
        try createDirectoryIfNeeded()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(tools)

        try data.write(
            to: toolsFileURL,
            options: .atomic
        )
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
            tipAngle: tool.tipAngle,
            parameters: tool.parameters
        )
        try add(copy)
        return copy
    }

    func delete(_ tool: Tool) throws {
        tools.removeAll { $0.id == tool.id }
        try save()
    }

    private func createDirectoryIfNeeded() throws {
        try fileManager.createDirectory(
            at: toolsDirectoryURL,
            withIntermediateDirectories: true
        )
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

    var errorDescription: String? {
        switch self {
        case .defaultToolsNotFound:
            "The bundled default_tools.json could not be found."
        }
    }
}
