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
    public var onCancelFollowUp: (() -> Void)?

    public init(reduceMotion: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) {
        self.stack = ShellStack()
        self.reduceMotion = reduceMotion
    }

    public var isVisible: Bool {
        panel?.isVisible ?? false
    }

    /// panel survives hide() so reopen skips the NSPanel/NSHostingView rebuild and its cold paint
    var hasPanel: Bool {
        panel != nil
    }

    public var currentScreen: NSScreen? {
        panel?.screen
    }

    public private(set) var currentViewType: ViewType = .seek

    public var dismissesOnOutsideClick: Bool {
        currentViewType.dismissesOnOutsideClick
    }

    public func setOnCancel(_ handler: (() -> Void)?) {
        panel?.escHandler = handler
    }

    /// returns false at root so the caller can decide dismiss vs pop
    @discardableResult
    public func popTop() -> Bool {
        guard !stack.isAtRoot else { return false }
        stack.pop()
        return true
    }

    public func goHome() {
        stack.home(initial: .launcher(query: "", selection: nil, scroll: 0))
    }

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

    func attach(panel: KeyablePanel) {
        self.panel = panel
    }

    public func push(_ entry: ShellStackEntry) {
        stack.push(entry)
    }

    public func replace(_ entry: ShellStackEntry) {
        stack.replace(entry)
    }

    /// drops stale callbacks from a view no longer on top (the frame right after a push, before onAppear)
    public func updateTopState(_ state: ShellViewState) {
        guard !stack.entries.isEmpty, state.preset == stack.top.preset else { return }
        stack.replace(ShellStackEntry(state))
    }

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

    public func ensurePanel(initialContent content: some View, size: NSSize) {
        guard panel == nil else { return }
        attach(panel: PanelChrome.borderless(size: size, content: content))
    }

    public func orderFront() {
        guard let panel else { return }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }
}

public extension ShellHost {
    /// empties the stack (never pops); panel kept for the next invoke to reuse
    func hide() {
        stopOutsideClickMonitor()
        panel?.orderOut(nil)
        stack.clear()
        followUpDescriptor = nil
        followUpError.message = nil
        activeFollowUp = nil
    }

    func armClickOutsideDismiss(onOutside: @escaping () -> Void) {
        startOutsideClickMonitor(onOutside: onOutside)
    }

    func showToast(message: String, isError: Bool) {
        toast.show(message: message, isError: isError)
    }

    func dismissDetachedPanels() {
        for reference in cards.values {
            reference.value?.orderOut(nil)
        }
        cards.removeAll()
    }
}

extension ShellHost {
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
        case .grid: state = .grid(highlightedID: nil)
        case .note: return // note is detached, not a stack push
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
        case .grid:
            setContent(GridPanelView(
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
        default:
            break
        }
    }

    private func cancelFollowUp() {
        if let trace = activeFollowUp?.trace {
            trace.markDismiss()
            #if DEBUG
                NSLog("%@", trace.debugDescription)
            #endif
        }
        onCancelFollowUp?()
    }

    /// Awaitable confirms dismiss via onCancelFollowUp first; clear so submitFollowUp won't pop/toast again.
    public func acknowledgeFollowUpHandled() {
        activeFollowUp = nil
        followUpDescriptor = nil
        followUpError.message = nil
    }

    /// hide() first so the note doesn't leave the palette panel sitting behind it
    private func openNote(ui: UIDescriptor, followUp: @escaping (RunRequest) async throws -> RunResponse) {
        hide()
        let commandId = ui.title ?? "note"
        let note = NotePanel(
            ui: ui,
            persist: true,
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
