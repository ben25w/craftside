import SwiftUI

struct EditorView: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(editorTitle)
                    .font(.headline)

                TextField("Title", text: $store.draftTitle)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $store.draftBody)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxHeight: .infinity)
            }
            .padding(14)

            Divider()

            formattingBar

            Divider()

            HStack {
                Button("Cancel") {
                    store.cancelEditing()
                }

                Spacer()

                Button {
                    Task { await store.saveDraft() }
                } label: {
                    if store.isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Save", systemImage: "checkmark")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSaving || draftIsEmpty)
            }
            .padding(12)
        }
    }

    private var editorTitle: String {
        switch store.editorMode {
        case .creating:
            "Add Note"
        case .editing:
            "Edit Note"
        case nil:
            ""
        }
    }

    private var draftIsEmpty: Bool {
        store.draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && store.draftBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var formattingBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FormatButton(title: "Bold", systemImage: "bold") {
                    append("**bold**")
                }
                FormatButton(title: "Italic", systemImage: "italic") {
                    append("*italic*")
                }
                FormatButton(title: "Heading", systemImage: "textformat.size") {
                    append("# Heading")
                }
                FormatButton(title: "Bulleted List", systemImage: "list.bullet") {
                    append("- List item")
                }
                FormatButton(title: "Numbered List", systemImage: "list.number") {
                    append("1. List item")
                }
                FormatButton(title: "Checklist", systemImage: "checklist") {
                    append("- [ ] Task")
                }
                FormatButton(title: "Inline Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                    append("`code`")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func append(_ snippet: String) {
        if !store.draftBody.isEmpty, !store.draftBody.hasSuffix("\n") {
            store.draftBody += "\n"
        }
        store.draftBody += snippet
    }
}

private struct FormatButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.bordered)
        .help(title)
    }
}
