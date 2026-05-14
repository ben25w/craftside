import AppKit
import SwiftUI

@MainActor
final class CraftEdgeTriggerController {
    static let shared = CraftEdgeTriggerController()

    private var panel: NSPanel?
    private var hostingController: NSHostingController<EdgeTriggerView>?
    private var side: SidebarSide = .right
    private var action: (() -> Void)?

    private init() {}

    func configure(side: SidebarSide, action: @escaping () -> Void) {
        self.action = action
        update(side: side)
    }

    func update(side: SidebarSide) {
        self.side = side
        let panel = panel ?? makePanel()
        self.panel = panel

        if let hostingController {
            hostingController.rootView = EdgeTriggerView(side: side) { [weak self] in
                self?.action?()
            }
        } else {
            let controller = NSHostingController(rootView: EdgeTriggerView(side: side) { [weak self] in
                self?.action?()
            })
            hostingController = controller
            panel.contentViewController = controller
        }

        position(panel, side: side)
        panel.orderFrontRegardless()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 18, height: 112),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }

    private func position(_ panel: NSPanel, side: SidebarSide) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: 18, height: 112)
        let x = side == .left ? visibleFrame.minX : visibleFrame.maxX - size.width
        let y = visibleFrame.midY - size.height / 2
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true, animate: false)
    }
}

private struct EdgeTriggerView: View {
    let side: SidebarSide
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule()
                    .fill(.black.opacity(0.76))
                Capsule()
                    .fill(Color(red: 0.64, green: 1.0, blue: 0.12))
                    .frame(width: 5, height: 54)
            }
            .frame(width: 18, height: 112)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Open CraftSide")
        .accessibilityLabel("Open CraftSide from \(side.label) edge")
    }
}
