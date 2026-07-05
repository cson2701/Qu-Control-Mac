import AppKit
import SwiftUI

@MainActor
final class MenuBarStatusItemController {
    private let statusBar = NSStatusBar.system
    private let popover = NSPopover()
    private let image: NSImage

    private var statusItem: NSStatusItem?

    init(image: NSImage) {
        self.image = image
        popover.behavior = .transient
        popover.animates = true
    }

    func update(isVisible: Bool, rootView: AnyView) {
        guard isVisible else {
            removeStatusItem()
            return
        }

        let statusItem = ensureStatusItem()
        popover.contentViewController = NSHostingController(rootView: rootView)

        if let button = statusItem.button {
            button.image = image
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    func closePopover() {
        guard popover.isShown else {
            return
        }

        popover.performClose(nil)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button else {
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func ensureStatusItem() -> NSStatusItem {
        if let statusItem {
            return statusItem
        }

        let statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = image
            button.imagePosition = .imageOnly
        }

        self.statusItem = statusItem
        return statusItem
    }

    private func removeStatusItem() {
        closePopover()

        if let statusItem {
            statusBar.removeStatusItem(statusItem)
        }

        statusItem = nil
    }
}
