import SwiftUI
import AppKit

struct DetailView: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        VStack(spacing: 0) {
            if let document = store.selectedDocument {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(document.title)
                            .font(.title3.bold())
                            .lineLimit(3)

                        if document.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("No text content found for this note.")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(document.body)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(16)
                }

                Divider()

                HStack(spacing: 10) {
                    Button {
                        store.startEditingSelectedDocument()
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)

                    if let url = document.craftURL {
                        Button {
                            NSWorkspace.shared.open(url)
                        } label: {
                            Label("Open in Craft", systemImage: "arrow.up.forward.app")
                        }
                    }

                    Spacer()
                }
                .padding(12)
            }
        }
    }
}
