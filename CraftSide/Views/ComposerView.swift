import SwiftUI

struct ComposerView: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("Insert", selection: $store.insertPlacement) {
                    ForEach(InsertPlacement.allCases) { placement in
                        Text(placement.label).tag(placement)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Spacer()

                if let selectedBlock = store.selectedBlock,
                   store.insertPlacement == .before || store.insertPlacement == .after {
                    Text("Target: \(selectedBlock.displayText.ifEmpty(selectedBlock.type))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            TextEditor(text: $store.composerText)
                .font(.body)
                .frame(height: 94)
                .padding(8)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(CraftPalette.border, lineWidth: 1)
                )

            HStack(spacing: 8) {
                QuickInsertButton(label: "Task", value: "- [ ] ")
                QuickInsertButton(label: "Link", value: "[title](https://)")
                QuickInsertButton(label: "Tomorrow", value: "[Tomorrow](date://\(tomorrowText))")

                Spacer()

                Button {
                    Task { await store.insertComposerText() }
                } label: {
                    if store.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Add", systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving || store.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
    }

    private var tomorrowText: String {
        DateFormatter.craftDate.string(from: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }
}

private struct QuickInsertButton: View {
    @EnvironmentObject private var store: CraftSideStore
    let label: String
    let value: String

    var body: some View {
        Button(label) {
            if !store.composerText.isEmpty, !store.composerText.hasSuffix("\n") {
                store.composerText += "\n"
            }
            store.composerText += value
        }
        .font(.caption)
        .buttonStyle(.bordered)
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
