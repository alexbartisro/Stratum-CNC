import Foundation
import Testing
@testable import Stratum_CNC

struct ProjectPersistenceTests {
    @Test @MainActor func importsNeverOverwriteExistingAssetsOrHideCopyFailures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = Project(name: "Import test")
        let paths = try ProjectPaths(project: project, documentsDirectory: root)
        try FileManager.default.createDirectory(at: paths.assetsDirectory, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("part.svg")
        try "original".write(to: source, atomically: true, encoding: .utf8)
        let model = ProjectModel(project: project, paths: paths)
        let first = try model.importAsset(from: source)
        try "replacement".write(to: source, atomically: true, encoding: .utf8)
        let second = try model.importAsset(from: source)
        #expect(first.name != second.name)
        #expect(try String(contentsOf: paths.assetsDirectory.appendingPathComponent(first.name), encoding: .utf8) == "original")
        #expect(throws: (any Error).self) { try model.importAsset(from: root.appendingPathComponent("missing.svg")) }
        #expect(model.projectData.assets?.count == 2)
    }

    @Test @MainActor func explicitSaveFlushesPendingMetadata() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = Project(name: "Metadata test")
        let paths = try ProjectPaths(project: project, documentsDirectory: root)
        try FileManager.default.createDirectory(at: paths.assetsDirectory, withIntermediateDirectories: true)
        let model = ProjectModel(project: project, paths: paths)
        model.projectData.isStockVisible = false
        try model.save()
        let reopened = ProjectModel(project: project, paths: paths)
        #expect(reopened.projectData.isStockVisible == false)
    }

    @Test @MainActor func restoresEditedToolpathsOnReopen() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let project = Project(name: "Persistence test")
        let paths = try ProjectPaths(project: project, documentsDirectory: root)
        try FileManager.default.createDirectory(at: paths.assetsDirectory, withIntermediateDirectories: true)
        let model = ProjectModel(project: project, paths: paths)
        model.camModel.addToolpath()
        model.camModel.toolpaths[0].name = "Saved contour"
        let saved = model.camModel.toolpaths
        let reopened = ProjectModel(project: project, paths: paths)
        #expect(reopened.camModel.toolpaths == saved)
        model.camModel.deleteToolpath(saved[0].id)
        let afterDeletion = ProjectModel(project: project, paths: paths)
        #expect(afterDeletion.camModel.toolpaths.isEmpty)
    }
}
