import SwiftUI
import AppKit

final class CraftSidePanelController: NSObject, NSPopoverDelegate {
    static let shared = CraftSidePanelController()

    private var popover: NSPopover?
    private var hostingController: NSHostingController<AnyView>?

    private override init() {}

    @MainActor
    func toggle<Content: View>(relativeTo button: NSStatusBarButton?, @ViewBuilder content: () -> Content) {
        guard let button else { return }

        if popover?.isShown == true {
            close()
            return
        }

        show(relativeTo: button, content: content)
    }

    @MainActor
    func close() {
        popover?.performClose(nil)
    }

    @MainActor
    private func show<Content: View>(relativeTo button: NSStatusBarButton, @ViewBuilder content: () -> Content) {
        let root = AnyView(content())
        if let hostingController {
            hostingController.rootView = root
        } else {
            hostingController = NSHostingController(rootView: root)
        }

        let popover = popover ?? makePopover()
        self.popover = popover
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 430, height: 680)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        return popover
    }
}
