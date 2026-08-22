import AppKit
import JugnuCore

@MainActor
public final class ListPanel: NSPanel, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let onSelect: (UIListItem, String?) -> Void
    private let onCancel: () -> Void
    private var allItems: [UIListItem]
    private var filtered: [UIListItem]
    private let table = NSTableView()
    private let search = NSSearchField()

    public init(
        ui: UIDescriptor,
        onSelect: @escaping (UIListItem, String?) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onSelect = onSelect
        self.onCancel = onCancel
        self.allItems = ui.items ?? []
        self.filtered = self.allItems
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = ui.title ?? "Choose"
        isFloatingPanel = true
        level = .floating

        search.placeholderString = ui.placeholder ?? "Filter"
        search.delegate = self
        search.translatesAutoresizingMaskIntoConstraints = false

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        col.title = "Item"
        col.width = 380
        table.addTableColumn(col)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.target = self
        table.doubleAction = #selector(rowActivated)
        table.translatesAutoresizingMaskIntoConstraints = false

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let root = NSView()
        root.addSubview(search)
        root.addSubview(scroll)
        contentView = root
        NSLayoutConstraint.activate([
            search.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            search.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            search.topAnchor.constraint(equalTo: root.topAnchor, constant: 12),
            scroll.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -12),
        ])
        center()
    }

    public func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filtered[row]
        let text = item.subtitle.map { "\(item.title) — \($0)" } ?? item.title
        let view = NSTextField(labelWithString: text)
        return view
    }

    public func controlTextDidChange(_ obj: Notification) {
        let q = search.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        filtered = q.isEmpty
            ? allItems
            : allItems.filter {
                $0.title.lowercased().contains(q) || ($0.subtitle?.lowercased().contains(q) ?? false)
            }
        table.reloadData()
    }

    @objc private func rowActivated() {
        let row = table.clickedRow >= 0 ? table.clickedRow : table.selectedRow
        guard row >= 0, row < filtered.count else { return }
        let item = filtered[row]
        onSelect(item, item.actions?.first ?? "select")
    }

    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 { // return
            rowActivated()
        } else {
            super.keyDown(with: event)
        }
    }

    public override func cancelOperation(_ sender: Any?) { onCancel() }
}
