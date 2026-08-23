import AppKit
import JugnuCore

@MainActor
public final class UIHostController {
    private let toast = ToastPresenter()
    private var activePanel: NSPanel?
    private var presentError: ((String) -> Void)?
    private var activeTrace: InvokeTrace?

    public init() {}

    public func present(
        response: RunResponse,
        commandId: String,
        trace: InvokeTrace,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        activeTrace = trace
        if let ui = response.ui {
            switch ui.pattern {
            case .confirm:
                showConfirm(ui, commandId: commandId, followUp: followUp)
            case .list:
                showList(ui, commandId: commandId, followUp: followUp)
            case .form:
                showForm(ui, commandId: commandId, followUp: followUp)
            case .note:
                showNote(ui, commandId: commandId, followUp: followUp)
            }
            return
        }

        if response.ok {
            toast.show(message: response.message ?? "Done.", isError: false)
        } else {
            toast.show(message: response.error ?? "Something went wrong. Try again.", isError: true)
        }
        markPaintAndContent()
    }

    public func presentSkeleton(pattern: UIPattern, title: String?, trace: InvokeTrace) {
        activeTrace = trace
        dismissActive(markDismiss: false)
        let panel = SkeletonPanel(pattern: pattern, title: title ?? "Loading…")
        activePanel = panel
        presentError = nil
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markFirstPaint()
    }

    public func replaceSkeleton(
        with response: RunResponse,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        present(
            response: response,
            commandId: commandId,
            trace: activeTrace ?? InvokeTrace(commandId: commandId),
            followUp: followUp
        )
    }

    public func dismissActive(markDismiss: Bool = true) {
        activePanel?.close()
        activePanel = nil
        presentError = nil
        if markDismiss {
            activeTrace?.markDismiss()
            #if DEBUG
            if let t = activeTrace { NSLog("%@", t.debugDescription) }
            #endif
        }
    }

    /// Host a confirm panel that is not an addon follow-up (e.g. uninstall).
    /// Uses the same active panel + trace hooks as addon-driven confirms.
    public func presentConfirm(
        ui: UIDescriptor,
        commandId: String,
        onConfirm: @escaping () throws -> Void
    ) {
        dismissActive(markDismiss: false)
        activeTrace = InvokeTrace(commandId: commandId)
        let panel = ConfirmPanel(
            ui: ui,
            onConfirm: { [weak self] in
                do {
                    try onConfirm()
                    self?.dismissActive()
                } catch {
                    self?.presentError?(UserFacingError.message(for: error))
                    playCommandSound(success: false)
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
        presentError = { [weak panel] message in panel?.presentError(message) }
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markPaintAndContent()
    }

    private func markFirstPaint() {
        activeTrace?.markFirstPaint()
    }

    private func markPaintAndContent() {
        activeTrace?.markFirstPaint()
        activeTrace?.markContent()
    }

    private func showConfirm(
        _ ui: UIDescriptor,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        dismissActive(markDismiss: false)
        let panel = ConfirmPanel(
            ui: ui,
            onConfirm: { [weak self] in
                Task { @MainActor in
                    let req = RunJSON.followUpRequest(
                        command: commandId,
                        args: ["confirmed": .bool(true)]
                    )
                    await self?.handleFollowUp(req, commandId: commandId, followUp: followUp)
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
        presentError = { [weak panel] message in panel?.presentError(message) }
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markPaintAndContent()
    }

    private func showList(
        _ ui: UIDescriptor,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        dismissActive(markDismiss: false)
        let panel = ListPanel(
            ui: ui,
            onSelect: { [weak self] item, action in
                Task { @MainActor in
                    var args: [String: JSONValue] = ["itemId": .string(item.id)]
                    if let action { args["action"] = .string(action) }
                    let req = RunJSON.followUpRequest(command: commandId, args: args)
                    await self?.handleFollowUp(req, commandId: commandId, followUp: followUp)
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
        presentError = { [weak panel] message in panel?.presentError(message) }
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markPaintAndContent()
    }

    private func showForm(
        _ ui: UIDescriptor,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        dismissActive(markDismiss: false)
        let panel = FormPanel(
            ui: ui,
            onSubmit: { [weak self] values in
                Task { @MainActor in
                    let req = RunJSON.followUpRequest(command: commandId, args: values)
                    await self?.handleFollowUp(req, commandId: commandId, followUp: followUp)
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
        presentError = { [weak panel] message in panel?.presentError(message) }
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markPaintAndContent()
    }

    private func showNote(
        _ ui: UIDescriptor,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        dismissActive(markDismiss: false)
        let panel = NotePanel(
            ui: ui,
            onSave: { content in
                Task {
                    let req = RunJSON.followUpRequest(command: commandId, args: ["content": .string(content)])
                    _ = try? await followUp(req)
                }
            },
            onClose: { [weak self] in
                self?.activePanel = nil
                self?.presentError = nil
                self?.activeTrace?.markDismiss()
            }
        )
        activePanel = panel
        presentError = nil
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markPaintAndContent()
    }

    private func handleFollowUp(
        _ req: RunRequest,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) async {
        do {
            let res = try await followUp(req)
            if res.ok == false, let presenter = presentError, activePanel != nil, res.ui == nil {
                presenter(res.error ?? UserFacingError.message(for: AddonRunnerError.invalidResponse))
                playCommandSound(success: false)
                return
            }
            dismissActive(markDismiss: false)
            present(
                response: res,
                commandId: commandId,
                trace: activeTrace ?? InvokeTrace(commandId: commandId),
                followUp: followUp
            )
        } catch {
            if let presenter = presentError, activePanel != nil {
                presenter(UserFacingError.message(for: error))
                playCommandSound(success: false)
            } else {
                toast.show(message: UserFacingError.message(for: error), isError: true)
            }
        }
    }
}
