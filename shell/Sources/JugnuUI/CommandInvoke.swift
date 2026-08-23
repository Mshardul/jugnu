import AppKit
import JugnuCore

/// Recommended invoke path: run, then present the response (toast, or a confirm/list/form follow-up
/// pushed onto `host`'s stack).
@MainActor
public enum CommandInvoke {
    public static func run(
        host: ShellHost,
        commandId: String,
        onScreen screen: NSScreen,
        execute: @escaping () async throws -> RunResponse,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) async {
        let trace = InvokeTrace(commandId: commandId)
        do {
            let response = try await execute()
            host.present(response: response, commandId: commandId, trace: trace, onScreen: screen, followUp: followUp)
        } catch {
            host.present(
                response: RunResponse(ok: false, error: UserFacingError.message(for: error)),
                commandId: commandId,
                trace: trace,
                onScreen: screen,
                followUp: followUp
            )
        }
        #if DEBUG
        print(trace.debugDescription)
        #endif
    }
}
