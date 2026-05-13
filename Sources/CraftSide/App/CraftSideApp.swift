import SwiftUI
import AppKit

@main
struct CraftSideApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = CraftSideStore()
    @AppStorage("SidebarPosition") private var sidebarPositionRaw = SidebarPosition.right.rawValue

    var body: some Scene {
        MenuBarExtra("CraftSide", systemImage: "sidebar.right") {
            Button("Toggle CraftSide") {
                togglePanel()
            }
            .keyboardShortcut(" ", modifiers: [.option])

            Button("Refresh") {
                Task { await store.load() }
            }

            Divider()

            Button("Settings") {
                store.isShowingSettings = true
                togglePanel(forceOpen: true)
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 420)
        }
    }

    private func togglePanel(forceOpen: Bool = false) {
        let position = SidebarPosition(rawValue: sidebarPositionRaw) ?? .right
        CraftPanelController.shared.togglePanel(position: position, forceOpen: forceOpen) {
            SidebarContainerView()
                .environmentObject(store)
                .frame(width: 360)
                .frame(minHeight: 560)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
