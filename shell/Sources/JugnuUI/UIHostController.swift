import AppKit
import JugnuCore

/// Routes addon `RunResponse` values to shell-owned UI patterns.
@MainActor
public final class UIHostController {
    private let toast = ToastPresenter()
    private var activePanel: NSPanel?
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
            }
            return
        }

        if response.ok {
            toast.show(message: response.message ?? "OK", isError: false)
        } else {
            toast.show(message: response.error ?? "Failed", isError: true)
        }
        markPaintAndContent()
    }

    public func presentSkeleton(pattern: UIPattern, title: String?, trace: InvokeTrace) {
        activeTrace = trace
        dismissActive(markDismiss: false)
        let panel = SkeletonPanel(pattern: pattern, title: title ?? "Loading…")
        activePanel = panel
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markFirstPaint()
    }

    public func replaceSkeleton(
        with response: RunResponse,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        present(response: response, commandId: commandId, trace: activeTrace ?? InvokeTrace(commandId: commandId), followUp: followUp)
    }

    public func dismissActive(markDismiss: Bool = true) {
        activePanel?.close()
        activePanel = nil
        if markDismiss {
            activeTrace?.markDismiss()
            #if DEBUG
            if let t = activeTrace { NSLog("%@", t.debugDescription) }
            #endif
        }
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
                    do {
                        let res = try await followUp(req)
                        self?.dismissActive(markDismiss: false)
                        self?.present(response: res, commandId: commandId, trace: self?.activeTrace ?? InvokeTrace(commandId: commandId), followUp: followUp)
                    } catch {
                        self?.toast.show(message: String(describing: error), isError: true)
                    }
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
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
                    do {
                        let res = try await followUp(req)
                        self?.dismissActive(markDismiss: false)
                        self?.present(response: res, commandId: commandId, trace: self?.activeTrace ?? InvokeTrace(commandId: commandId), followUp: followUp)
                    } catch {
                        self?.toast.show(message: String(describing: error), isError: true)
                    }
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
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
                    do {
                        let res = try await followUp(req)
                        self?.dismissActive(markDismiss: false)
                        self?.present(response: res, commandId: commandId, trace: self?.activeTrace ?? InvokeTrace(commandId: commandId), followUp: followUp)
                    } catch {
                        self?.toast.show(message: String(describing: error), isError: true)
                    }
                }
            },
            onCancel: { [weak self] in
                self?.dismissActive()
            }
        )
        activePanel = panel
        panel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        markPaintAndContent()
    }
}
