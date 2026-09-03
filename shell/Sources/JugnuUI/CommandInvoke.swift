import AppKit
import JugnuCore

/// Recommended invoke path: run, then present the response (toast, or a confirm/list/form follow-up
/// pushed onto `host`'s stack).
@MainActor
public enum CommandInvoke {
    @discardableResult
    public static func run(
        host: ShellHost,
        commandId: String,
        onScreen screen: NSScreen,
        execute: @escaping () async throws -> RunResponse,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) async -> Bool {
        let trace = InvokeTrace(commandId: commandId)
        let succeeded: Bool
        do {
            let response = try await execute()
            host.present(response: response, commandId: commandId, trace: trace, onScreen: screen, followUp: followUp)
            succeeded = response.ok
        } catch let job as JobInvokeError {
            switch job {
            case .reuse:
                succeeded = true
            case .stillStopping:
                host.present(
                    response: RunResponse(ok: false, error: UserFacingError.message(for: job)),
                    commandId: commandId,
                    trace: trace,
                    onScreen: screen,
                    followUp: followUp
                )
                succeeded = false
            }
        } catch {
            host.present(
                response: RunResponse(ok: false, error: UserFacingError.message(for: error)),
                commandId: commandId,
                trace: trace,
                onScreen: screen,
                followUp: followUp
            )
            succeeded = false
        }
        #if DEBUG
            print(trace.debugDescription)
        #endif
        return succeeded
    }
}
