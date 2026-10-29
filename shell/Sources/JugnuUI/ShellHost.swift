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
    public private(set) var showsAppShellContent = false
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
    private var notes: [String: NotePanel] = [:]
    private var tray: TrayPanel?
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
        if stack.entries.last?.preset == .appShell {
            return false
        }
        return currentViewType.dismissesOnOutsideClick
    }

    public var panelFrame: NSRect? {
        panel?.frame
    }

    public var appShellNavigation: AppNavigation? {
        for entry in stack.entries.reversed() {
            if case let .appShell(navigation) = entry.state {
                return navigation
            }
        }
        return nil
    }

    public func showAppShell(_ navigation: AppNavigation) {
        stack.home(initial: .appShell(navigation))
    }

    public func updateAppShell(_ navigation: AppNavigation) {
        guard !stack.entries.isEmpty, stack.top.preset == .appShell else { return }
        stack.replace(ShellStackEntry(.appShell(navigation)))
    }

    public func placeAppShellFrame(in visibleFrame: NSRect) {
        guard let panel else { return }
        panel.setFrame(appShellFrame(in: visibleFrame), display: true)
    }

    public func setOnCommandW(_ handler: (() -> Void)?) {
        panel?.commandWHandler = handler
    }

    public func performCommandW() -> Bool {
        guard let panel else { return false }
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: panel.windowNumber,
            context: nil,
            characters: "w",
            charactersIgnoringModifiers: "w",
            isARepeat: false,
            keyCode: 13
        ) else { return false }
        return panel.performKeyEquivalent(with: event)
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
        morphFrame(to: preset, compactLauncher: compactLauncher, in: screen.visibleFrame, viewType: viewType)
    }

    public func morphFrame(
        to preset: ShellPreset,
        compactLauncher: Bool,
        in visibleFrame: NSRect,
        viewType: ViewType? = nil
    ) {
        guard let panel else { return }
        if preset == .appShell, viewType == nil {
            placeAppShellFrame(in: visibleFrame)
            return
        }
        let type = viewType ?? preset.defaultViewType(compactLauncher: compactLauncher)
        currentViewType = type
        let box = type.size(in: visibleFrame)
        let size = NSSize(width: box.width, height: box.height)
        let target = clampedFrame(size: size, centeredOn: visibleFrame)
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
        showsAppShellContent = false
        panel?.contentView = NSHostingView(rootView: view)
    }

    public func installAppShellContent(_ view: some View) {
        guard panel != nil else { return }
        guard !showsAppShellContent else { return }
        showsAppShellContent = true
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
        showsAppShellContent = false
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
        tray?.close()
        tray = nil
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
        if let ui = response.ui {
            switch ui.pattern {
            case .note:
                openNote(ui: ui, followUp: followUp)
            case .card:
                openCard(ui: ui)
            case .tray:
                openTray(ui: ui, commandId: commandId, onScreen: screen, followUp: followUp)
            case .list, .form, .confirm, .grid:
                pushFollowUp(ui: ui, commandId: commandId, trace: trace, onScreen: screen, followUp: followUp)
            }
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
        case .tray: return
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
        // Finder handoff creates the panel without showing it. Palette invokes
        // are already on screen; ordering front again is harmless.
        orderFront()
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

    /// hide() first so the tray doesn't leave the palette panel sitting behind it.
    /// Stays up across app switches so a drag from Finder can land on it.
    private func openTray(
        ui: UIDescriptor,
        commandId: String,
        onScreen screen: NSScreen,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        hide()
        let animated = reduceMotion() == false
        if let tray {
            bindTray(tray, commandId: commandId, followUp: followUp)
            tray.replace(ui: ui)
            tray.reveal(on: screen, animated: false)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let panel = TrayPanel(
            ui: ui,
            onClose: { [weak self] in
                self?.tray = nil
            }
        )
        bindTray(panel, commandId: commandId, followUp: followUp)
        tray = panel
        panel.reveal(on: screen, animated: animated)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func bindTray(
        _ tray: TrayPanel,
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse
    ) {
        tray.onPaths = { [weak self] paths in
            self?.sendTray(
                commandId: commandId,
                followUp: followUp,
                args: ["paths": .array(paths.map { .string($0) })]
            )
        }
        tray.onOpen = { [weak self] paths in
            let urls = paths.map { URL(fileURLWithPath: $0) }
            let opened = urls.contains { NSWorkspace.shared.open($0) }
            guard opened else {
                self?.toast.show(message: "Couldn't open that.", isError: true)
                return
            }
        }
        tray.onReveal = { paths in
            NSWorkspace.shared.activateFileViewerSelecting(paths.map { URL(fileURLWithPath: $0) })
        }
        tray.onTrash = { [weak self] paths in
            self?.sendTray(
                commandId: commandId,
                followUp: followUp,
                args: [
                    "action": .string("delete"),
                    "paths": .array(paths.map { .string($0) })
                ]
            )
        }
    }

    private func sendTray(
        commandId: String,
        followUp: @escaping (RunRequest) async throws -> RunResponse,
        args: [String: JSONValue]
    ) {
        Task { @MainActor in
            do {
                let request = RunJSON.followUpRequest(command: commandId, args: args)
                let response = try await followUp(request)
                if let next = response.ui, next.pattern == .tray {
                    self.tray?.replace(ui: next)
                }
                if response.ok == false {
                    self.toast.show(message: response.error ?? "Couldn't update ~/Temporary.", isError: true)
                }
            } catch {
                self.toast.show(message: UserFacingError.message(for: error), isError: true)
            }
        }
    }

    /// hide() first so the note doesn't leave the palette panel sitting behind it
    private func openNote(ui: UIDescriptor, followUp: @escaping (RunRequest) async throws -> RunResponse) {
        hide()
        let key = ui.title ?? "note"
        if let existing = notes[key], existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let note = NotePanel(
            ui: ui,
            persist: true,
            onSave: { [weak self] text in
                Task { @MainActor in
                    do {
                        let request = RunJSON.followUpRequest(command: key, args: ["content": .string(text)])
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
        notes[key] = note
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
