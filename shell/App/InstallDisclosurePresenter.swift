import AppKit
import JugnuCore
import JugnuUI

@MainActor
enum InstallDisclosurePresenter {
    static func confirm(ui: UIDescriptor, shellHost: ShellHost, commandId: String) async -> Bool {
        guard let screen = shellHost.currentScreen ?? NSScreen.main else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            MainActor.assumeIsolated {
                let session = ConfirmSession(
                    shellHost: shellHost,
                    previousCancelFollowUp: shellHost.onCancelFollowUp,
                    continuation: cont
                )
                shellHost.onCancelFollowUp = { session.dismissConfirm() }
                shellHost.setOnCancel { session.dismissConfirm() }
                shellHost.pushFollowUp(
                    ui: ui,
                    commandId: commandId,
                    trace: nil,
                    onScreen: screen,
                    followUp: { _ in
                        session.complete(confirmed: true)
                        return RunResponse(ok: true, message: "")
                    }
                )
                shellHost.orderFront()
                shellHost.armClickOutsideDismiss { session.dismissConfirm() }
            }
        }
    }
}

@MainActor
private final class ConfirmSession {
    let shellHost: ShellHost
    let previousCancelFollowUp: (() -> Void)?
    private let continuation: CheckedContinuation<Bool, Never>
    private var resumed = false

    init(
        shellHost: ShellHost,
        previousCancelFollowUp: (() -> Void)?,
        continuation: CheckedContinuation<Bool, Never>
    ) {
        self.shellHost = shellHost
        self.previousCancelFollowUp = previousCancelFollowUp
        self.continuation = continuation
    }

    func complete(confirmed: Bool) {
        finish(confirmed)
        previousCancelFollowUp?()
        if confirmed {
            shellHost.acknowledgeFollowUpHandled()
        }
    }

    func dismissConfirm() {
        complete(confirmed: false)
    }

    private func finish(_ value: Bool) {
        guard !resumed else { return }
        resumed = true
        shellHost.onCancelFollowUp = previousCancelFollowUp
        shellHost.armClickOutsideDismiss { [weak shellHost] in
            guard let shellHost, shellHost.dismissesOnOutsideClick else { return }
            shellHost.hide()
        }
        continuation.resume(returning: value)
    }
}
