import AppKit
import SwiftUI

@MainActor
public final class BrowseCatalogWindowController<VM: BrowseCatalogViewModelProtocol>: NSWindowController {
    public init(viewModel: VM) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Browse Addons"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BrowseCatalogView(viewModel: viewModel))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
