import Foundation
import Testing
@testable import Stratum_CNC

struct GCodeUploaderRegressionTests {
    @Test(arguments: [MakeraWireProtocol.makera, .smoothie])
    @MainActor func cancelledTransferCannotResumeFromLateCallback(wire: MakeraWireProtocol) throws {
        let uploader = GCodeUploader()
        var completions: [(Error?) -> Void] = []
        uploader.configure(sendLine: { _ in },
                           sendRawBytes: { _, completion in completions.append(completion) },
                           sendFrame: { _, _, completion in completions.append(completion) },
                           wireProtocol: { wire })
        uploader.upload(fileName: "old.nc", contents: Data("G1 X1".utf8))
        uploader.handleMachineLine("ready")
        let oldCompletion = try #require(completions.first)
        uploader.cancel()
        oldCompletion(nil)
        #expect(uploader.state == .cancelled)

        uploader.upload(fileName: "new.nc", contents: Data("G1 X2".utf8))
        uploader.handleMachineLine("ready")
        let sends = completions.count
        oldCompletion(nil)
        #expect(completions.count == sends)
        #expect(uploader.state == .transferring(bytesSent: 0, totalBytes: 5))
        uploader.cancel()
    }
}
