import Foundation
import Testing
@testable import Stratum_CNC

struct ProjectPersistenceTests {
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
