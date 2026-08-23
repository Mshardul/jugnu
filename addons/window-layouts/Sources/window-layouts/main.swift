import Foundation

enum WindowLayoutsMain {
    static func run() throws {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let request: RunRequestJSON
        if data.isEmpty {
            request = RunRequestJSON(api: 1, op: "run", command: "snap-board", args: nil)
        } else {
            request = try JSONDecoder().decode(RunRequestJSON.self, from: data)
        }
        do {
            let json = try Router.handle(request)
            FileHandle.standardOutput.write(Data(json.utf8))
        } catch AXError.notTrusted {
            FileHandle.standardOutput.write(Data("{\"ok\":false,\"error\":\"Jugnu needs Accessibility to move windows.\"}".utf8))
        } catch AXError.noFrontWindow {
            FileHandle.standardOutput.write(Data("{\"ok\":false,\"error\":\"No window to move.\"}".utf8))
        } catch {
            FileHandle.standardOutput.write(Data("{\"ok\":false,\"error\":\"Couldn’t move that window.\"}".utf8))
        }
    }
}

do {
    try WindowLayoutsMain.run()
} catch {
    FileHandle.standardOutput.write(Data("{\"ok\":false,\"error\":\"Couldn’t move that window.\"}".utf8))
}
