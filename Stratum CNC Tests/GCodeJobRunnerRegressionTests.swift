import Testing
@testable import Stratum_CNC

struct GCodeJobRunnerRegressionTests {
    @Test(arguments: ["error: Probe failed", "ALARM: Probe failed"])
    @MainActor func failedCommandsAbortTheMacro(response: String) {
        let runner = GCodeJobRunner()
        var sent: [String] = []
        var finished = false
        var failed = false
        runner.configure { sent.append($0) }
        runner.onFinish = { finished = true }
        runner.onFailure = { failed = true }
        runner.start(lines: ["G38.2 Z-10 F50", "G10L20P0Z0"])
        runner.handleMachineLine(response)
        runner.handleMachineLine("ok")
        #expect(runner.state == .failed(response))
        #expect(sent == ["G38.2 Z-10 F50"])
        #expect(!finished)
        #expect(failed)
    }
}
