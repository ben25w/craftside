import SwiftUI

struct SetupView: View {
    @EnvironmentObject private var store: CraftSideStore
    @State private var endpoint = ""
    @State private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Connect Craft")
                    .font(.title2.bold())
                Text("Paste the API URL from Craft Settings. Add the API key if your connection requires one.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("https://connect.craft.do/...", text: $endpoint)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("API Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField("Optional", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                Task { await store.saveConnection(endpoint: endpoint, apiKey: apiKey) }
            } label: {
                Label("Connect", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding(18)
        .onAppear {
            endpoint = store.connection.endpoint
            apiKey = store.connection.apiKey
        }
    }
}
