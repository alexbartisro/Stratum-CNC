import Foundation
import Testing
@testable import Stratum_CNC

struct MachineConnectionTests {
    @Test @MainActor func disconnectStopsPendingControllerWork() async throws {
        let model = ControllerModel()
        model.connection.connect(to: .mock)
        model.startJob(lines: ["G1 X10", "G1 X20"])
        model.uploader.upload(fileName: "job.nc", contents: Data("G1 X1".utf8))
        model.connection.disconnect()
        #expect(!model.jobRunner.isActive)
        #expect(model.uploader.state == .failed("Connection closed"))
        model.connection.connect(to: .mock)
        defer { model.connection.disconnect() }
        model.connection.clearLogs()
        try await Task.sleep(for: .milliseconds(300))
        #expect(!model.connection.rawLog.contains(where: { $0.contains("G1 X20") || $0.hasPrefix("> play ") }))
    }

    @Test @MainActor func ignoresRepliesFromPreviousMockSession() async throws {
        let connection = MachineConnection()
        connection.connect(to: .mock)
        var replies: [String] = []
        connection.onLine = { replies.append($0) }
        connection.send("G1 X10")
        connection.connect(to: .mock)
        defer { connection.disconnect() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(replies.isEmpty)
        #expect(connection.isConnected)
        #expect(connection.wireProtocol == .makera)
    }

    @Test @MainActor func cancelledSocketCannotDisconnectReplacementSession() async throws {
        let connection = MachineConnection()
        connection.connect(to: MakeraMachine(name: "Local test", ip: "127.0.0.1", port: 9, busy: false))
        connection.connect(to: .mock)
        defer { connection.disconnect() }
        try await Task.sleep(for: .milliseconds(300))
        #expect(connection.isConnected)
        #expect(connection.wireProtocol == .makera)
        #expect(connection.lastError == nil)
    }
}
