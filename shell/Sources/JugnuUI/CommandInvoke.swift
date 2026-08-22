import JugnuCore

/// Recommended invoke path: optional skeleton chrome, then run, then present.
@MainActor
public enum CommandInvoke {
    public static func run(
        host: UIHostController,
        commandId: String,
        defaultPattern: UIPattern?,
        title: String?,
        execute: @escaping () async throws -> RunResponse,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) async {
        let trace = InvokeTrace(commandId: commandId)
        if let pattern = defaultPattern {
            host.presentSkeleton(pattern: pattern, title: title, trace: trace)
        }
        do {
            let response = try await execute()
            trace.markContent()
            if defaultPattern != nil {
                host.replaceSkeleton(with: response, commandId: commandId, followUp: followUp)
            } else {
                host.present(response: response, commandId: commandId, trace: trace, followUp: followUp)
            }
        } catch {
            host.dismissActive(markDismiss: false)
            host.present(
                response: RunResponse(ok: false, error: UserFacingError.message(for: error)),
                commandId: commandId,
                trace: trace,
                followUp: followUp
            )
        }
        #if DEBUG
        print(trace.debugDescription)
        #endif
    }
}
