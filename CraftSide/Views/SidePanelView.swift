import SwiftUI
import AppKit

struct SidePanelView: View {
    @EnvironmentObject private var store: CraftSideStore
    @AppStorage("AppearanceMode") private var appearanceRaw = AppearanceMode.system.rawValue

    private var appearance: AppearanceMode {
        AppearanceMode(rawValue: appearanceRaw) ?? .system
    }

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader()

            if !store.hasConnection || store.isShowingSettings {
                SettingsPane()
            } else {
                MainDailyNotesView()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .background(CraftPalette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CraftPalette.border, lineWidth: 1)
        )
        .task {
            await store.loadVisibleDates()
        }
    }
}

private struct PanelHeader: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("CraftSide")
                    .font(.system(size: 14, weight: .semibold))
                Text(store.selectedNote?.subtitle ?? "Daily Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.hasConnection {
                Button {
                    Task { await store.refreshSelected() }
                } label: {
                    Image(systemName: store.isLoading ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise")
                }
                .buttonStyle(PlainIconButtonStyle())
                .disabled(store.isLoading)
                .help("Refresh")
            }

            Button {
                store.isShowingSettings.toggle()
                store.isShowingDebug = false
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(PlainIconButtonStyle())
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
        .background(CraftPalette.headerBackground)
    }
}

private struct MainDailyNotesView: View {
    var body: some View {
        VStack(spacing: 0) {
            DateRailView()
            Divider()
            DailyNoteDetailView()
            Divider()
            ComposerView()
        }
    }
}

enum CraftPalette {
    static let accent = Color(red: 0.62, green: 0.98, blue: 0.13)
    static let purple = Color(red: 0.48, green: 0.30, blue: 1.0)
    static let purpleSoft = Color(red: 0.48, green: 0.30, blue: 1.0).opacity(0.12)
    static let canvas = Color(nsColor: .windowBackgroundColor).opacity(0.96)
    static let card = Color(nsColor: .controlBackgroundColor).opacity(0.84)
    static let taskPanel = Color.primary.opacity(0.045)
    static let headerBackground = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.08, blue: 0.09),
            Color(red: 0.17, green: 0.17, blue: 0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let border = Color.primary.opacity(0.08)
}
