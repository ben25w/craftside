import SwiftUI
import AppKit

struct SidebarContainerView: View {
    @EnvironmentObject private var store: CraftSideStore
    @AppStorage("ShowDailyNote") private var showDailyNote = true
    @AppStorage("AppearancePreference") private var appearanceRaw = AppearancePreference.system.rawValue

    private var appearance: AppearancePreference {
        AppearancePreference(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()

            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.regularMaterial)
        .preferredColorScheme(appearance.colorScheme)
        .task {
            if store.isConfigured, store.allNotes.isEmpty, store.dailyNote == nil {
                await store.load()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isShowingSettings {
            SettingsView()
        } else if !store.isConfigured {
            SetupView()
        } else if store.editorMode != nil {
            EditorView()
        } else if store.selectedDocument != nil {
            DetailView()
        } else {
            NoteListView(showDailyNote: showDailyNote)
        }
    }
}

private struct HeaderView: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        HStack(spacing: 10) {
            if store.selectedDocument != nil || store.editorMode != nil || store.isShowingSettings {
                Button {
                    store.isShowingSettings = false
                    store.cancelEditing()
                    store.selectedDocument = nil
                    store.selectedNote = nil
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.borderless)
                .help("Back")
            }

            Text(store.connectionName.isEmpty ? "CraftSide" : store.connectionName)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            if store.isConfigured {
                Button {
                    store.startCreating()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .buttonStyle(.borderless)
                .help("Add Note")

                Button {
                    Task { await store.load() }
                } label: {
                    Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath.circle" : "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(store.isLoading)
                .help("Refresh")
            }

            Button {
                store.isShowingSettings.toggle()
                store.cancelEditing()
                store.selectedDocument = nil
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private extension AppearancePreference {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
