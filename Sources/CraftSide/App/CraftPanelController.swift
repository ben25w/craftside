import SwiftUI
import AppKit

final class CraftPanelController {
    static let shared = CraftPanelController()

    private var panel: CraftPanel?
    private var hostingController: NSHostingController<AnyView>?

    private init() {}

    func togglePanel<Content: View>(
        position: SidebarPosition,
        forceOpen: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        if panel?.isVisible == true, !forceOpen {
            panel?.orderOut(nil)
            return
        }

        let root = AnyView(content())
        if let hostingController {
            hostingController.rootView = root
        } else {
            let hosting = NSHostingController(rootView: root)
            hostingController = hosting
        }

        let panel = panel ?? makePanel()
        self.panel = panel

        if let hostingController, panel.contentViewController !== hostingController {
            panel.contentViewController = hostingController
        }

        positionPanel(panel, side: position)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePanel() -> CraftPanel {
        let panel = CraftPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 640),
            styleMask: [.titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .floating
        panel.minSize = NSSize(width: 320, height: 440)
        panel.maxSize = NSSize(width: 420, height: 1_200)
        return panel
    }

    private func positionPanel(_ panel: NSPanel, side: SidebarPosition) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(max(panel.frame.width, 340), 390)
        let height = min(max(panel.frame.height, 600), visibleFrame.height - 24)
        let x = side == .left ? visibleFrame.minX + 10 : visibleFrame.maxX - width - 10
        let y = visibleFrame.maxY - height - 10
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: true)
    }
}

final class CraftPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
