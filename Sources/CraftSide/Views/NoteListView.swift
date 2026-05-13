import SwiftUI

struct NoteListView: View {
    @EnvironmentObject private var store: CraftSideStore
    var showDailyNote: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if showDailyNote {
                        DailyNoteSection()
                    }

                    if !store.pinnedNotes.isEmpty {
                        SectionHeader(title: "Pinned")
                        ForEach(store.pinnedNotes) { note in
                            NoteRow(note: note)
                        }
                    }

                    SectionHeader(title: store.allNotes.isEmpty ? "Daily Notes" : "Recent")
                    ForEach(store.unpinnedNotes) { note in
                        NoteRow(note: note)
                    }

                    if store.unpinnedNotes.isEmpty && store.pinnedNotes.isEmpty && store.dailyNote == nil {
                        EmptyListView()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 14)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search notes", text: $store.searchText)
                .textFieldStyle(.plain)
        }
        .padding(10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(12)
    }
}

private struct DailyNoteSection: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        SectionHeader(title: "Daily Note")

        if let dailyNote = store.dailyNote {
            NoteRow(note: dailyNote)
        } else {
            Button {
                Task { await store.ensureTodayDailyNote() }
            } label: {
                HStack {
                    Label("Start today's note", systemImage: "calendar.badge.plus")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct NoteRow: View {
    @EnvironmentObject private var store: CraftSideStore
    let note: NoteSummary

    var body: some View {
        Button {
            Task { await store.select(note) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: note.isDailyNote ? "calendar" : (store.isPinned(note) ? "pin.fill" : "doc.text"))
                    .foregroundStyle(store.isPinned(note) ? Color.accentColor : .secondary)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(note.displayTitle)
                        .lineLimit(1)
                        .foregroundStyle(.primary)

                    if !note.preview.isEmpty {
                        Text(note.preview)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 6)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(store.isPinned(note) ? "Unpin" : "Pin") {
                store.togglePin(note)
            }
        }
    }
}

private struct SectionHeader: View {
    var title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }
}

private struct EmptyListView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No notes found")
                .font(.headline)
            Text("Refresh, check the Craft connection, or create a note.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}
