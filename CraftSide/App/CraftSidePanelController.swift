import SwiftUI
import AppKit

final class CraftSidePanelController {
    static let shared = CraftSidePanelController()

    private var panel: CraftPanel?
    private var hostingController: NSHostingController<AnyView>?

    private init() {}

    func toggle<Content: View>(side: SidebarSide, @ViewBuilder content: () -> Content) {
        if panel?.isVisible == true {
            panel?.orderOut(nil)
            return
        }
        show(side: side, content: content)
    }

    func show<Content: View>(side: SidebarSide, @ViewBuilder content: () -> Content) {
        let root = AnyView(content())
        if let hostingController {
            hostingController.rootView = root
        } else {
            hostingController = NSHostingController(rootView: root)
        }

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.contentViewController = hostingController
        position(panel, side: side)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makePanel() -> CraftPanel {
        let panel = CraftPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 720),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.minSize = NSSize(width: 340, height: 500)
        panel.maxSize = NSSize(width: 520, height: 1_300)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        return panel
    }

    private func position(_ panel: NSPanel, side: SidebarSide) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width = min(max(panel.frame.width, 370), min(430, visibleFrame.width - 32))
        let height = min(max(panel.frame.height, 680), visibleFrame.height - 24)
        let x = side == .left ? visibleFrame.minX + 10 : visibleFrame.maxX - width - 10
        let y = visibleFrame.maxY - height - 10
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true, animate: true)
    }
}

final class CraftPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
