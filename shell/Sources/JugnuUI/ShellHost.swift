import AppKit
import Combine
import JugnuCore
import SwiftUI

public func clampedFrame(size requested: NSSize, centeredOn screenFrame: NSRect) -> NSRect {
    let width = min(requested.width, screenFrame.width)
    let height = min(requested.height, screenFrame.height)
    let x = screenFrame.midX - width / 2
    let y = screenFrame.midY - height / 2
    return NSRect(x: x, y: y, width: width, height: height)
}

@MainActor
public final class ShellHost: ObservableObject {
    @Published public private(set) var stack: ShellStack
    private var panel: KeyablePanel?
    private let reduceMotion: () -> Bool
    private var outsideClickMonitor: Any?
    private var followUpDescriptor: UIDescriptor?
    private let followUpError = PanelErrorState()
    private var activeFollowUp: (
        commandId: String,
        followUp: (RunRequest) async throws -> RunResponse,
        trace: InvokeTrace
    )?
    private let toast = ToastPresenter()
    private var cards: [String: WeakCardPanel] = [:]
    /// Set by the caller (AppDelegate) right after `pushFollowUp`/`renderFollowUpContent`
    public var onCancelFollowUp: (() -> Void)?

    public init(reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.stack = ShellStack()
        self.reduceMotion = reduceMotion
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// Panel survives hide() so reopen skips the NSPanel/NSHostingView rebuild and its cold paint.
    var hasPanel: Bool {
        panel != nil
    }

    /// The screen the panel is currently on, if it's up.
    public var currentScreen: NSScreen? {
        panel?.screen
    }

    public private(set) var currentViewType: ViewType = .seek

    public var dismissesOnOutsideClick: Bool {
        currentViewType.dismissesOnOutsideClick
    }

    /// Sets the panel's Esc/Cmd+. handler. Callers should rebind this whenever the hosted content changes.
    public func setOnCancel(_ handler: (() -> Void)?) {
        panel?.escHandler = handler
    }

    /// Pops one stack entry. Returns false (no-op) if already at root — caller decides dismiss vs pop.
    @discardableResult
    public func popTop() -> Bool {
        guard !stack.isAtRoot else { return false }
        stack.pop()
        return true
    }

    /// Resets the stack to a fresh `[launcher]` (home), per the invoke-hotkey home rule.
    public func goHome() {
        stack.home(initial: .launcher(query: "", selection: nil, scroll: 0))
    }

    /// Genuine click outside the app's own windows (not resign-key, not Cmd+Tab). Always dismisses, never pops.
    private func startOutsideClickMonitor(onOutside: @escaping () -> Void) {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { _ in
            onOutside()
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
        }
        outsideClickMonitor = nil
    }

    public func morphFrame(
        to preset: ShellPreset,
        compactLauncher: Bool,
        on screen: NSScreen,
        viewType: ViewType? = nil
    ) {
        guard let panel else { return }
        let type = viewType ?? preset.defaultViewType(compactLauncher: compactLauncher)
        currentViewType = type
        let box = type.size(in: screen.visibleFrame)
        let size = NSSize(width: box.width, height: box.height)
        let target = clampedFrame(size: size, centeredOn: screen.visibleFrame)
        if reduceMotion() {
            panel.setFrame(target, display: true)
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                panel.animator().setFrame(target, display: true)
            }
        }
    }

    /// Exposed for Task 5+ to attach the real KeyablePanel once content views exist.
    func attach(panel: KeyablePanel) {
        self.panel = panel
    }

    /// Pushes a child entry onto the stack (or refocuses in place if it's an idempotent re-push of the current top).
    public func push(_ entry: ShellStackEntry) {
        stack.push(entry)
    }

    /// Replaces the top entry with a sibling, keeping the same parent.
    public func replace(_ entry: ShellStackEntry) {
        stack.replace(entry)
    }

    /// Live-updates the current top entry's snapshot in place (same preset, new state) without
    /// pushing/popping. Called by content views as the user types/scrolls/selects, so a later pop
    /// restores what was actually on screen. Silently drops stale callbacks from a view that's no
    /// longer on top (e.g. the frame right after a push, before the new content's onAppear fires).
    public func updateTopState(_ state: ShellViewState) {
        guard !stack.entries.isEmpty, state.preset == stack.top.preset else { return }
        stack.replace(ShellStackEntry(state))
    }

    /// Swaps the panel's hosted content to `view`. Callers own the mapping from `stack.top.preset` to a concrete view.
    public func setContent(_ view: some View) {
        panel?.contentView = NSHostingView(rootView: view)
    }

    public func showJobProgress(startedAt: Date, onScreen screen: NSScreen, onCancel: @escaping () -> Void) {
        ensurePanel(initialContent: EmptyView(), size: ViewType.ask.size(in: screen.visibleFrame))
        setContent(ThemedPanelBackground {
            JobProgressView(startedAt: startedAt, onCancel: onCancel)
        })
        morphFrame(to: .confirm, compactLauncher: false, on: screen, viewType: .ask)
        orderFront()
    }

    /// Builds the single `KeyablePanel` with `content` if it doesn't exist yet; no-op otherwise.
    public func ensurePanel(initialContent content: some View, size: NSSize) {
        guard panel == nil else { return }
        attach(panel: PanelChrome.borderless(size: size, content: content))
    }

    /// Brings the panel to front and makes it key, without rebuilding or touching the stack.
    public func orderFront() {
        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

public extension ShellHost {
    /// Orders the panel out and empties the stack (never pops); panel kept for the next invoke to reuse.
    func hide() {
        stopOutsideClickMonitor()
        panel?.orderOut(nil)
        stack.clear()
        followUpDescriptor = nil
        followUpError.message = nil
        activeFollowUp = nil
    }

    /// Starts (or restarts) the global click-outside monitor. Call once the panel is visible;
    /// `hide()` stops it. Fires only for genuine mouse-down outside the app's own windows —
    /// resign-key / Cmd+Tab never trigger this.
    func armClickOutsideDismiss(onOutside: @escaping () -> Void) {
        startOutsideClickMonitor(onOutside: onOutside)
    }

    func dismissDetachedPanels() {
        for reference in cards.values {
            reference.value?.orderOut(nil)
        }
        cards.removeAll()
    }
}

extension ShellHost {
    /// Presents `response`'s follow-up UI (confirm/list/form) as a stack push, or shows a toast and
    /// leaves the stack untouched if there's no UI. AppModel-free: `followUp` is a plain
    /// `RunRequest -> RunResponse` closure supplied by the caller (AppDelegate/AddonUninstallPresenter),
    /// so no dependency on the App target is introduced here.
    public func present(
        response: RunResponse,
        commandId: String,
        trace: InvokeTrace,
        onScreen screen: NSScreen,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        if let ui = response.ui, ui.pattern != .note, ui.pattern != .card {
            pushFollowUp(ui: ui, commandId: commandId, trace: trace, onScreen: screen, followUp: followUp)
            return
        }
        if let ui = response.ui, ui.pattern == .note {
            openNote(ui: ui, followUp: followUp)
            trace.markFirstPaint()
            trace.markContent()
            return
        }
        if let ui = response.ui, ui.pattern == .card {
            openCard(ui: ui)
            trace.markFirstPaint()
            trace.markContent()
            return
        }
        if response.ok {
            toast.show(message: response.message ?? "Done.", isError: false)
        } else {
            toast.show(message: response.error ?? "Something went wrong. Try again.", isError: true)
        }
        trace.markFirstPaint()
        trace.markContent()
    }

    /// Pushes a `confirm`/`list`/`form` follow-up as a child of the current top (spec §4) instead of
    /// opening a separate panel. Idempotent re-push (same preset already on top) just refocuses, per
    /// `ShellStack.push`'s existing rule.
    public func pushFollowUp(
        ui: UIDescriptor,
        commandId: String,
        trace: InvokeTrace?,
        onScreen screen: NSScreen,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        let state: ShellViewState
        switch ui.pattern {
        case .confirm: state = .confirm
        case .list: state = .list(query: "", highlightedID: nil, scroll: 0)
        case .form: state = .form(values: [:], focusedFieldID: nil)
        case .note: return // note is detached, not a stack push — handled separately (Task 12)
        case .card: return
        }
        let resolvedTrace = trace ?? InvokeTrace(commandId: commandId)
        followUpDescriptor = ui
        followUpError.message = nil
        activeFollowUp = (commandId, followUp, resolvedTrace)
        stack.push(ShellStackEntry(state))
        renderFollowUpContent()
        morphFrame(
            to: state.preset,
            compactLauncher: false,
            on: screen,
            viewType: ui.view ?? ui.pattern.defaultViewType
        )
        resolvedTrace.markFirstPaint()
        resolvedTrace.markContent()
    }

    /// Re-hosts the confirm/list/form view for whatever's currently on top, if it's a follow-up preset
    /// and a descriptor is stashed for it. No-op otherwise.
    public func renderFollowUpContent() {
        guard let ui = followUpDescriptor else { return }
        switch stack.top.preset {
        case .confirm:
            setContent(ConfirmView(
                ui: ui,
                errorState: followUpError,
                onConfirm: { [weak self] in self?.submitFollowUp(args: ["confirmed": .bool(true)]) },
                onCancel: { [weak self] in self?.cancelFollowUp() }
            ))
        case .list:
            setContent(ListPanelView(
                ui: ui,
                errorState: followUpError,
                onSelect: { [weak self] item, action in
                    var args: [String: JSONValue] = ["itemId": .string(item.id)]
                    if let action {
                        args["action"] = .string(action)
                    }
                    self?.submitFollowUp(args: args)
                },
                onCancel: { [weak self] in self?.cancelFollowUp() }
            ))
        case .form:
            setContent(FormPanelView(
                ui: ui,
                errorState: followUpError,
                onSubmit: { [weak self] values in self?.submitFollowUp(args: values) },
                onCancel: { [weak self] in self?.cancelFollowUp() }
            ))
        default:
            break
        }
    }

    /// Cancel button / Esc on a follow-up: same as any other pop. Caller (AppDelegate) still owns
    /// popping the stack and morphing the frame, via `onCancelFollowUp`.
    private func cancelFollowUp() {
        if let trace = activeFollowUp?.trace {
            trace.markDismiss()
            #if DEBUG
                NSLog("%@", trace.debugDescription)
            #endif
        }
        onCancelFollowUp?()
    }

    /// Opens `.note` as a detached `NSPanel`, separate from the in-panel stack. Resets the launcher
    /// (hides the in-panel host) so the note doesn't leave the palette panel sitting behind it.
    /// AppModel-free: `followUp` is the same closure `present` already received, reused to persist
    /// the note's content on close via a synthetic `RunRequest` — there's no response UI to show back
    /// (the note window is already gone), so a failed save surfaces as a toast instead.
    private func openNote(ui: UIDescriptor, followUp: @escaping (RunRequest) async throws -> RunResponse) {
        hide()
        let commandId = ui.title ?? "note"
        let note = NotePanel(
            ui: ui,
            persist: true, // today's shipped command is a persist:true scratchpad; persist:false Quick Note is backlog
            // (spec §2)
            onSave: { [weak self] text in
                Task { @MainActor in
                    do {
                        let request = RunJSON.followUpRequest(command: commandId, args: ["content": .string(text)])
                        let response = try await followUp(request)
                        if response.ok == false {
                            self?.toast.show(message: response.error ?? "Couldn't save note.", isError: true)
                        }
                    } catch {
                        self?.toast.show(message: UserFacingError.message(for: error), isError: true)
                    }
                }
            },
            onClose: {}
        )
        note.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openCard(ui: UIDescriptor) {
        hide()
        let key = ui.title ?? "card"
        let shouldReduceMotion = reduceMotion()

        if let card = cards[key]?.value {
            card.replace(ui: ui, reduceMotion: shouldReduceMotion)
            card.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let reference = WeakCardPanel()
        let card = CardPanel(
            ui: ui,
            reduceMotion: shouldReduceMotion,
            onClose: { [weak self, weak reference] in
                guard self?.cards[key]?.value === reference?.value else { return }
                self?.cards[key] = nil
            }
        )
        reference.value = card
        cards[key] = reference
        card.makeKeyAndOrderFront(nil)
        card.dismissOnOutsideClick()
        NSApp.activate(ignoringOtherApps: true)
    }

    private func submitFollowUp(args: [String: JSONValue]) {
        guard let active = activeFollowUp else { return }
        let request = RunJSON.followUpRequest(command: active.commandId, args: args)
        Task { @MainActor in
            do {
                let response = try await active.followUp(request)
                guard self.activeFollowUp?.commandId == active.commandId else { return }
                if response.ok == false, response.ui == nil {
                    self.followUpError.message = response.error ?? UserFacingError
                        .message(for: AddonRunnerError.invalidResponse)
                    playCommandSound(success: false)
                    return
                }
                guard let screen = self.panel?.screen ?? NSScreen.main else { return }
                self.stack.pop() // drop the finished follow-up before presenting its result
                self.followUpDescriptor = nil
                self.present(
                    response: response,
                    commandId: active.commandId,
                    trace: active.trace,
                    onScreen: screen,
                    followUp: active.followUp
                )
            } catch {
                self.followUpError.message = UserFacingError.message(for: error)
                playCommandSound(success: false)
            }
        }
    }
}

private final class WeakCardPanel {
    weak var value: CardPanel?
}
