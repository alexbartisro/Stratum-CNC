import Foundation
import Testing
@testable import Stratum_CNC

struct MachineConnectionTests {
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
