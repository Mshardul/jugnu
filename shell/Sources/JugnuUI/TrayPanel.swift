import AppKit
import JugnuCore
import SwiftUI

public func trayFrame(in visibleFrame: NSRect) -> NSRect {
    let width = min(560, max(280, visibleFrame.width - 24))
    let height: CGFloat = 156
    let x = visibleFrame.midX - width / 2
    let y = visibleFrame.maxY - height
    return NSRect(x: x, y: y, width: width, height: height)
}

public func traySelection(current: Set<String>, clicked: String, adding: Bool) -> Set<String> {
    if adding {
        var next = current
        if next.contains(clicked) {
            next.remove(clicked)
        } else {
            next.insert(clicked)
        }
        return next
    }
    return [clicked]
}

public func trayMenuSelection(current: Set<String>, clicked: String) -> Set<String> {
    current.contains(clicked) ? current : [clicked]
}

@MainActor
public final class TrayPanel: NSPanel {
    var onPaths: ([String]) -> Void = { _ in }
    var onOpen: ([String]) -> Void = { _ in }
    var onReveal: ([String]) -> Void = { _ in }
    var onTrash: ([String]) -> Void = { _ in }
    private let model: TrayModel
    private let lifecycle = TrayLifecycle()
    private let dropView = TrayDropView()

    public init(ui: UIDescriptor, onClose: @escaping () -> Void) {
        model = TrayModel(ui: ui)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 156),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        becomesKeyOnlyIfNeeded = false
        delegate = lifecycle
        lifecycle.onClose = onClose

        let hosting = NSHostingView(rootView: TrayShelfView(
            model: model,
            onDismiss: { [weak self] in self?.close() }
        ))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        dropView.onDrop = { [weak self] urls in
            self?.onPaths(urls.map(\.path))
        }
        dropView.onTargeted = { [weak self] targeted in
            self?.model.targeted = targeted
        }
        dropView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: dropView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: dropView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: dropView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: dropView.bottomAnchor)
        ])
        contentView = dropView
        model.onOpen = { [weak self] paths in self?.onOpen(paths) }
        model.onReveal = { [weak self] paths in self?.onReveal(paths) }
        model.onTrash = { [weak self] paths in self?.onTrash(paths) }
    }

    override public var canBecomeKey: Bool {
        true
    }

    override public func cancelOperation(_: Any?) {
        close()
    }

    override public func keyDown(with event: NSEvent) {
        if event.specialKey == .delete || event.specialKey == .deleteForward {
            model.trashSelection()
            return
        }
        super.keyDown(with: event)
    }

    func replace(ui: UIDescriptor) {
        model.apply(ui)
    }

    func reveal(on screen: NSScreen, animated: Bool) {
        let target = trayFrame(in: screen.visibleFrame)
        if animated {
            var start = target
            start.origin.y = screen.frame.maxY
            setFrame(start, display: false)
        } else {
            setFrame(target, display: true)
        }
        makeKeyAndOrderFront(nil)
        guard animated else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            animator().setFrame(target, display: true)
        }
    }
}

@MainActor
private final class TrayModel: ObservableObject {
    @Published var title: String
    @Published var message: String
    @Published var items: [TrayFile]
    @Published var selected: Set<String> = []
    @Published var targeted = false
    var onOpen: ([String]) -> Void = { _ in }
    var onReveal: ([String]) -> Void = { _ in }
    var onTrash: ([String]) -> Void = { _ in }

    init(ui: UIDescriptor) {
        title = ui.title ?? "Temporary"
        message = ui.message ?? "Drop files or folders"
        items = Self.files(from: ui)
    }

    func apply(_ ui: UIDescriptor) {
        title = ui.title ?? "Temporary"
        message = ui.message ?? "Drop files or folders"
        items = Self.files(from: ui)
        let live = Set(items.map(\.id))
        selected = selected.intersection(live)
    }

    func activate(_ id: String) {
        selected = traySelection(current: selected, clicked: id, adding: false)
        onOpen([id])
    }

    func toggle(_ id: String) {
        selected = traySelection(current: selected, clicked: id, adding: true)
    }

    func showMenu(for id: String, event: NSEvent, view: NSView) {
        selected = trayMenuSelection(current: selected, clicked: id)
        let paths = selectedPaths()
        guard paths.isEmpty == false else { return }
        let menu = NSMenu()
        menu.addItem(menuItem("Open") { [weak self] in self?.onOpen(paths) })
        menu.addItem(menuItem("Reveal in Finder") { [weak self] in self?.onReveal(paths) })
        menu.addItem(.separator())
        let trashTitle = paths.count > 1 ? "Move \(paths.count) Items to Trash" : "Move to Trash"
        menu.addItem(menuItem(trashTitle) { [weak self] in self?.onTrash(paths) })
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    func dragURLs(startingAt id: String) -> [URL] {
        if selected.contains(id), selected.count > 1 {
            return selectedPaths().map { URL(fileURLWithPath: $0) }
        }
        selected = [id]
        return [URL(fileURLWithPath: id)]
    }

    func trashSelection() {
        let paths = selectedPaths()
        guard paths.isEmpty == false else { return }
        onTrash(paths)
    }

    func clearAll() {
        let paths = items.map(\.id)
        guard paths.isEmpty == false else { return }
        onTrash(paths)
    }

    private func selectedPaths() -> [String] {
        items.map(\.id).filter { selected.contains($0) }
    }

    private static func files(from ui: UIDescriptor) -> [TrayFile] {
        (ui.items ?? []).map { item in
            TrayFile(
                id: item.id,
                title: item.title,
                icon: NSWorkspace.shared.icon(forFile: item.id)
            )
        }
    }
}

private struct TrayFile: Identifiable {
    let id: String
    let title: String
    let icon: NSImage
}

private struct TrayShelfView: View {
    @ObservedObject var model: TrayModel
    var onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var store = ThemeStore.shared

    var body: some View {
        let theme = JugnuThemeColors(theme: resolvedTheme(from: store.config, colorScheme: colorScheme))
        VStack(alignment: .leading, spacing: JugnuTokens.Spacing.row) {
            HStack {
                Text(model.title)
                    .font(JugnuTokens.font(presetId: store.presetId, role: .headline))
                Spacer()
                Button(action: { model.clearAll() }) {
                    Text("Clear")
                        .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                        .foregroundStyle(
                            model.items.isEmpty ? theme.textSecondary.opacity(0.35) : theme.textSecondary
                        )
                }
                .buttonStyle(.plain)
                .disabled(model.items.isEmpty)
                .help("Move everything to the Trash")
                .accessibilityLabel("Clear all files")
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.textSecondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            if model.items.isEmpty {
                Text(model.message)
                    .font(JugnuTokens.font(presetId: store.presetId, role: .body))
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: JugnuTokens.Spacing.row) {
                        ForEach(model.items) { item in
                            let isSelected = model.selected.contains(item.id)
                            VStack(spacing: 4) {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .frame(width: 36, height: 36)
                                Text(item.title)
                                    .font(JugnuTokens.font(presetId: store.presetId, role: .caption))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 72)
                            }
                            .padding(4)
                            .frame(width: 84)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(isSelected ? theme.accent.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(isSelected ? theme.accent : Color.clear, lineWidth: 1)
                            )
                            .overlay(FileDragSource(
                                url: URL(fileURLWithPath: item.id),
                                onPrimaryClick: { model.activate(item.id) },
                                onToggleSelect: { model.toggle(item.id) },
                                onContextClick: { event, view in
                                    model.showMenu(for: item.id, event: event, view: view)
                                },
                                dragPaths: { model.dragURLs(startingAt: item.id) }
                            ))
                            .help(item.title)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel(item.title)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(JugnuTokens.Spacing.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: JugnuTokens.Radius.panel, style: .continuous)
                .strokeBorder(
                    model.targeted ? theme.accent : theme.accent.opacity(0.25),
                    lineWidth: model.targeted ? 2 : 1
                )
        )
    }
}

private final class TrayDropView: NSView {
    var onDrop: ([URL]) -> Void = { _ in }
    var onTargeted: (Bool) -> Void = { _ in }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func draggingEntered(_: NSDraggingInfo) -> NSDragOperation {
        onTargeted(true)
        return .copy
    }

    override func draggingExited(_: NSDraggingInfo?) {
        onTargeted(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargeted(false)
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL] ?? []
        guard urls.isEmpty == false else { return false }
        onDrop(urls)
        return true
    }
}

private struct FileDragSource: NSViewRepresentable {
    let url: URL
    var onPrimaryClick: () -> Void
    var onToggleSelect: () -> Void
    var onContextClick: (NSEvent, NSView) -> Void
    var dragPaths: () -> [URL]

    func makeNSView(context _: Context) -> FileDragView {
        let view = FileDragView()
        apply(to: view)
        return view
    }

    func updateNSView(_ view: FileDragView, context _: Context) {
        apply(to: view)
    }

    private func apply(to view: FileDragView) {
        view.url = url
        view.onPrimaryClick = onPrimaryClick
        view.onToggleSelect = onToggleSelect
        view.onContextClick = onContextClick
        view.dragPaths = dragPaths
    }
}

private final class FileDragView: NSView, NSDraggingSource {
    var url: URL?
    var onPrimaryClick: () -> Void = {}
    var onToggleSelect: () -> Void = {}
    var onContextClick: (NSEvent, NSView) -> Void = { _, _ in }
    var dragPaths: () -> [URL] = { [] }
    private var dragStarted = false
    private var suppressMouseUp = false
    private var downPoint: NSPoint?

    func draggingSession(
        _: NSDraggingSession,
        sourceOperationMaskFor _: NSDraggingContext
    ) -> NSDragOperation {
        [.copy, .move]
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        dragStarted = false
        downPoint = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStarted == false, let url, let downPoint else { return }
        let dx = event.locationInWindow.x - downPoint.x
        let dy = event.locationInWindow.y - downPoint.y
        guard (dx * dx) + (dy * dy) > 16 else { return }
        dragStarted = true
        let urls = dragPaths()
        let dragging = (urls.isEmpty ? [url] : urls).enumerated().map { index, fileURL in
            let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = NSSize(width: 32, height: 32)
            let shift = CGFloat(index) * 8
            item.setDraggingFrame(NSRect(x: shift, y: -shift, width: 32, height: 32), contents: icon)
            return item
        }
        guard dragging.isEmpty == false else { return }
        beginDraggingSession(with: dragging, event: event, source: self)
    }

    override func mouseUp(with event: NSEvent) {
        if suppressMouseUp {
            suppressMouseUp = false
            return
        }
        guard dragStarted == false else { return }
        if event.modifierFlags.contains(.command) {
            onToggleSelect()
            return
        }
        onPrimaryClick()
    }

    override func rightMouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            suppressMouseUp = true
            onToggleSelect()
            return
        }
        onContextClick(event, self)
    }
}

private final class MenuAction: NSObject {
    private let run: () -> Void

    init(_ run: @escaping () -> Void) {
        self.run = run
    }

    @objc func fire() {
        run()
    }
}

private func menuItem(_ title: String, _ run: @escaping () -> Void) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: #selector(MenuAction.fire), keyEquivalent: "")
    let box = MenuAction(run)
    item.target = box
    item.representedObject = box
    return item
}

@MainActor
private final class TrayLifecycle: NSObject, NSWindowDelegate {
    var onClose: (() -> Void)?

    func windowWillClose(_: Notification) {
        onClose?()
    }
}
