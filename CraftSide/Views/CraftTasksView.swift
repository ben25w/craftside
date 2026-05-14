import SwiftUI

struct CraftTasksView: View {
    @EnvironmentObject private var store: CraftSideStore
    @State private var selectedFilter: TaskFilter = .today

    var body: some View {
        VStack(spacing: 0) {
            QuickTaskBar()

            HStack {
                Text(filterTitle)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(filterColor)

                Spacer()

                Picker("Filter", selection: $selectedFilter) {
                    ForEach(TaskFilter.allCases) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if let error = store.lastError {
                ErrorBanner(message: error)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(sections) { section in
                        TaskSectionView(section: section)
                    }

                    if sections.isEmpty {
                        EmptyTasksView(filter: selectedFilter)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }

            BottomTaskBar()
        }
    }

    private var sections: [TaskSection] {
        switch selectedFilter {
        case .today:
            return [
                TaskSection(title: "Overdue", color: .red, tasks: store.activeTaskSummaries.filter(\.isOverdue)),
                TaskSection(title: "Today", color: .pink, tasks: store.activeTaskSummaries.filter(\.isToday)),
                TaskSection(title: "Inbox", color: .blue, tasks: store.inboxTaskSummaries)
            ].filter { !$0.tasks.isEmpty }
        case .upcoming:
            return [TaskSection(title: "Upcoming", color: .orange, tasks: store.upcomingTaskSummaries)]
                .filter { !$0.tasks.isEmpty }
        case .inbox:
            return [TaskSection(title: "Inbox", color: .blue, tasks: store.inboxTaskSummaries)]
                .filter { !$0.tasks.isEmpty }
        case .all:
            return [
                TaskSection(title: "Overdue", color: .red, tasks: store.activeTaskSummaries.filter(\.isOverdue)),
                TaskSection(title: "Today", color: .pink, tasks: store.activeTaskSummaries.filter(\.isToday)),
                TaskSection(title: "Upcoming", color: .orange, tasks: store.upcomingTaskSummaries),
                TaskSection(title: "Inbox", color: .blue, tasks: store.inboxTaskSummaries)
            ].filter { !$0.tasks.isEmpty }
        }
    }

    private var filterTitle: String {
        selectedFilter.title
    }

    private var filterColor: Color {
        selectedFilter.color
    }
}

private struct QuickTaskBar: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)

                TextField("Type a Craft task and hit enter", text: $store.newTaskText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 17, weight: .medium))
                    .onSubmit {
                        Task { await store.addTaskFromInput() }
                    }

                Button {
                    Task { await store.addTaskFromInput() }
                } label: {
                    Image(systemName: store.isSaving ? "hourglass" : "arrow.down.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .disabled(store.isSaving || store.newTaskText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            SchedulePickerRow()
        }
        .padding(14)
        .background(.thinMaterial)
    }
}

private struct SchedulePickerRow: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        HStack(spacing: 8) {
            ScheduleChip(title: "Inbox", icon: "tray", choice: .inbox)
            ScheduleChip(title: "Today", icon: "calendar", choice: .today)
            ScheduleChip(title: "Tomorrow", icon: "sunrise", choice: .tomorrow)

            DatePicker(
                "",
                selection: $store.newTaskCustomDate,
                displayedComponents: [.date]
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .onChange(of: store.newTaskCustomDate) { date in
                store.newTaskSchedule = .custom(date)
            }
        }
    }
}

private struct ScheduleChip: View {
    @EnvironmentObject private var store: CraftSideStore
    let title: String
    let icon: String
    let choice: TaskScheduleChoice

    var body: some View {
        Button {
            store.newTaskSchedule = choice
        } label: {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(isSelected ? Color.purple.opacity(0.22) : Color.primary.opacity(0.055), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var isSelected: Bool {
        store.newTaskSchedule == choice
    }
}

private struct TaskSectionView: View {
    let section: TaskSection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(section.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(section.color)
                Spacer()
                Text("\(section.tasks.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(section.tasks) { task in
                    CraftTaskRow(task: task, tint: section.color)
                    if task.id != section.tasks.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(CraftPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CraftPalette.border, lineWidth: 1)
            )
        }
    }
}

private struct CraftTaskRow: View {
    @EnvironmentObject private var store: CraftSideStore
    let task: CraftTaskSummary
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                Task { await store.completeTask(id: task.id) }
            } label: {
                Circle()
                    .stroke(tint, lineWidth: 2.5)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(store.isSaving)
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Label(task.scheduleLabel.ifEmpty("Inbox"), systemImage: "calendar")
                        .foregroundStyle(task.isOverdue ? .red : .secondary)

                    Spacer(minLength: 8)

                    Text(task.locationLabel)
                        .foregroundStyle(.secondary)
                }
                .font(.caption.weight(.semibold))

                HStack(spacing: 8) {
                    TaskActionChip(title: "Today") {
                        await store.rescheduleTask(id: task.id, schedule: .today)
                    }
                    TaskActionChip(title: "Tomorrow") {
                        await store.rescheduleTask(id: task.id, schedule: .tomorrow)
                    }
                    TaskActionChip(title: "Inbox") {
                        await store.rescheduleTask(id: task.id, schedule: .inbox)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }
}

private struct TaskActionChip: View {
    let title: String
    let action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.055), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct BottomTaskBar: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        HStack {
            Button {
                Task { await store.refreshTasks() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plainIcon)
            .help("Refresh Craft tasks")

            Spacer()

            Button {
                store.isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plainIcon)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }
}

private struct EmptyTasksView: View {
    let filter: TaskFilter

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No \(filter.label.lowercased()) tasks")
                .font(.headline)
            Text("Add one above and it will be created in Craft.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
    }
}

private struct TaskSection: Identifiable {
    var title: String
    var color: Color
    var tasks: [CraftTaskSummary]

    var id: String { title }
}

private enum TaskFilter: String, CaseIterable, Identifiable {
    case today
    case upcoming
    case inbox
    case all

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today: "Today"
        case .upcoming: "Upcoming"
        case .inbox: "Inbox"
        case .all: "All"
        }
    }

    var title: String {
        switch self {
        case .today: "Craft Tasks"
        case .upcoming: "Upcoming"
        case .inbox: "Inbox"
        case .all: "All Tasks"
        }
    }

    var color: Color {
        switch self {
        case .today: .pink
        case .upcoming: .orange
        case .inbox: .blue
        case .all: .purple
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
