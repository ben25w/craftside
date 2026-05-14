import SwiftUI
import AppKit

struct SettingsPane: View {
    @EnvironmentObject private var store: CraftSideStore
    @AppStorage("SidebarSide") private var sideRaw = SidebarSide.right.rawValue
    @AppStorage("AppearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue
    @State private var endpoint = ""
    @State private var apiKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.title2.bold())

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Craft Daily Notes API")
                            .font(.headline)
                        Text("Use a Daily Notes API URL from Craft’s Imagine tab. The value is stored in Keychain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TextField("API URL", text: $endpoint)
                            .textFieldStyle(.roundedBorder)
                        SecureField("API Key, if required", text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button {
                                Task { await store.saveConnection(endpoint: endpoint, apiKey: apiKey) }
                            } label: {
                                Label("Save Connection", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                            if store.hasConnection {
                                Button(role: .destructive) {
                                    store.disconnect()
                                    endpoint = ""
                                    apiKey = ""
                                } label: {
                                    Label("Disconnect", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Panel")
                            .font(.headline)
                        Picker("Side", selection: sideBinding) {
                            ForEach(SidebarSide.allCases) { side in
                                Text(side.label).tag(side)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("Appearance", selection: appearanceBinding) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.label).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("The menu bar icon opens and closes the side panel. Clicking away closes it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("App")
                            .font(.headline)
                        HStack {
                            Button {
                                store.isShowingSettings = false
                            } label: {
                                Label("Back to Notes", systemImage: "calendar")
                            }

                            Button(role: .destructive) {
                                NSApp.terminate(nil)
                            } label: {
                                Label("Quit", systemImage: "power")
                            }
                        }
                    }
                }

                if let error = store.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
        }
        .onAppear {
            endpoint = store.connection.endpoint
            apiKey = store.connection.apiKey
        }
    }

    private var sideBinding: Binding<SidebarSide> {
        Binding(
            get: { SidebarSide(rawValue: sideRaw) ?? .right },
            set: {
                sideRaw = $0.rawValue
                CraftSidePanelController.shared.reposition(side: $0)
            }
        )
    }

    private var appearanceBinding: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }
}
