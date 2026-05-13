import SwiftUI

struct DateRailView: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let today = store.notes.first(where: { Calendar.current.isDateInToday($0.date) }) {
                DateRow(note: today, isPinnedToday: true)
                    .padding(.horizontal, 12)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    Button {
                        store.expandEarlier()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(PlainIconButtonStyle())
                    .help("Show earlier dates")

                    ForEach(store.notes) { note in
                        if !Calendar.current.isDateInToday(note.date) {
                            DateChip(note: note)
                        }
                    }

                    Button {
                        store.expandLater()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(PlainIconButtonStyle())
                    .help("Show later dates")
                }
                .padding(.horizontal, 12)
            }
        }
        .padding(.vertical, 10)
    }
}

private struct DateRow: View {
    @EnvironmentObject private var store: CraftSideStore
    let note: DailyNote
    let isPinnedToday: Bool

    var body: some View {
        Button {
            Task { await store.select(date: note.date) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "pin.fill")
                    .foregroundStyle(CraftPalette.purple)
                VStack(alignment: .leading, spacing: 1) {
                    Text(isPinnedToday ? "Today’s Daily Note" : note.title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(note.preview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                statusDot
            }
            .padding(10)
            .background(isSelected ? CraftPalette.purpleSoft : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var isSelected: Bool {
        Calendar.current.isDate(note.date, inSameDayAs: store.selectedDate)
    }

    private var statusDot: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 7, height: 7)
    }

    private var statusColor: Color {
        switch note.loadState {
        case .loaded: .green
        case .failed: .red
        case .loading: .orange
        case .empty: .secondary
        case .idle: .secondary.opacity(0.35)
        }
    }
}

private struct DateChip: View {
    @EnvironmentObject private var store: CraftSideStore
    let note: DailyNote

    var body: some View {
        Button {
            Task { await store.select(date: note.date) }
        } label: {
            VStack(spacing: 2) {
                Text(note.title)
                    .font(.caption.bold())
                    .lineLimit(1)
                Text(note.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 92, height: 46)
            .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isSelected ? CraftPalette.purple.opacity(0.55) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var isSelected: Bool {
        Calendar.current.isDate(note.date, inSameDayAs: store.selectedDate)
    }

    private var background: Color {
        isSelected ? CraftPalette.purpleSoft : Color.primary.opacity(0.04)
    }
}
