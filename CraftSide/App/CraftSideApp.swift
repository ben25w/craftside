import SwiftUI
import AppKit

@main
struct CraftSideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let store = CraftSideStore.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.image = NSImage(systemSymbolName: "sidebar.right", accessibilityDescription: "CraftSide")
        item.button?.imagePosition = .imageLeading
        item.button?.title = " CraftSide"
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.sendAction(on: [.leftMouseUp])
    }

    @objc private func togglePanel() {
        let side = SidebarSide(rawValue: UserDefaults.standard.string(forKey: "SidebarSide") ?? "") ?? .right
        CraftSidePanelController.shared.toggle(side: side, preferredScreen: statusItem?.button?.window?.screen) {
            SidePanelView()
                .environmentObject(store)
        }
    }
}
