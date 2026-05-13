import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: CraftSideStore
    @AppStorage("SidebarPosition") private var sidebarPositionRaw = SidebarPosition.right.rawValue
    @AppStorage("ShowDailyNote") private var showDailyNote = true
    @AppStorage("AppearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue
    @State private var endpoint = ""
    @State private var apiKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings")
                    .font(.title2.bold())

                GroupBox("Sidebar") {
                    Picker("Position", selection: sidebarPositionBinding) {
                        ForEach(SidebarPosition.allCases) { position in
                            Text(position.title).tag(position)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                GroupBox("Daily Note") {
                    Toggle("Show Daily Note section", isOn: $showDailyNote)
                }

                GroupBox("Appearance") {
                    Picker("Mode", selection: appearanceBinding) {
                        ForEach(AppearancePreference.allCases) { appearance in
                            Text(appearance.title).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                GroupBox("API Connection") {
                    VStack(alignment: .leading, spacing: 10) {
                        TextField("API URL", text: $endpoint)
                            .textFieldStyle(.roundedBorder)

                        SecureField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button {
                                Task { await store.saveConnection(endpoint: endpoint, apiKey: apiKey) }
                            } label: {
                                Label("Save", systemImage: "checkmark")
                            }
                            .buttonStyle(.borderedProminent)

                            Button(role: .destructive) {
                                store.disconnect()
                                endpoint = ""
                                apiKey = ""
                            } label: {
                                Label("Disconnect", systemImage: "xmark.circle")
                            }

                            Spacer()
                        }
                    }
                }

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
        }
        .onAppear {
            endpoint = store.connection.endpoint
            apiKey = store.connection.apiKey
        }
    }

    private var sidebarPositionBinding: Binding<SidebarPosition> {
        Binding(
            get: { SidebarPosition(rawValue: sidebarPositionRaw) ?? .right },
            set: { sidebarPositionRaw = $0.rawValue }
        )
    }

    private var appearanceBinding: Binding<AppearancePreference> {
        Binding(
            get: { AppearancePreference(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }
}
