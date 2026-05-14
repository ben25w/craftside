import Foundation
import Combine

@MainActor
final class CraftSideStore: ObservableObject {
    static let shared = CraftSideStore()

    @Published var connection: CraftConnection
    @Published var notes: [DailyNote]
    @Published var selectedDate: Date
    @Published var selectedBlockID: String?
    @Published var composerText = ""
    @Published var insertPlacement: InsertPlacement = .end
    @Published var isShowingSettings = false
    @Published var isShowingDebug = false
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var lastError: String?
    @Published var lastWriteDebug: JSONValue?
    @Published var activeTasks: JSONValue?
    @Published var activeTaskSummaries: [CraftTaskSummary] = []
    @Published var upcomingTasks: JSONValue?
    @Published var upcomingTaskSummaries: [CraftTaskSummary] = []
    @Published var inboxTasks: JSONValue?
    @Published var inboxTaskSummaries: [CraftTaskSummary] = []
    @Published var newTaskText = ""
    @Published var newTaskSchedule: TaskScheduleChoice = .today
    @Published var newTaskCustomDate = Date()

    private let client: CraftDailyNotesClient
    private let keychain: KeychainStore

    init(client: CraftDailyNotesClient = CraftDailyNotesClient(), keychain: KeychainStore = .shared) {
        self.client = client
        self.keychain = keychain
        connection = CraftConnection(
            endpoint: keychain.string(for: "CraftAPIEndpoint") ?? "",
            apiKey: keychain.string(for: "CraftAPIKey") ?? "",
            mcpEndpoint: keychain.string(for: "CraftMCPURL") ?? ""
        )
        selectedDate = Date()
        notes = Self.makeInitialDateRange(around: Date())
    }

    var selectedNote: DailyNote? {
        notes.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var selectedRoot: CraftBlock? {
        selectedNote?.root
    }

    var selectedBlock: CraftBlock? {
        guard let selectedBlockID else { return nil }
        return selectedRoot?.allBlocksDepthFirst.first { $0.id == selectedBlockID }
    }

    var hasConnection: Bool {
        connection.isConfigured
    }

    func saveConnection(endpoint: String, apiKey: String, mcpEndpoint: String) async {
        do {
            try keychain.set(endpoint, for: "CraftAPIEndpoint")
            try keychain.set(apiKey, for: "CraftAPIKey")
            try keychain.set(mcpEndpoint, for: "CraftMCPURL")
            connection = CraftConnection(endpoint: endpoint, apiKey: apiKey, mcpEndpoint: mcpEndpoint)
            await refreshSelected()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        keychain.delete(account: "CraftAPIEndpoint")
        keychain.delete(account: "CraftAPIKey")
        keychain.delete(account: "CraftMCPURL")
        connection = CraftConnection(endpoint: "", apiKey: "", mcpEndpoint: "")
        notes = Self.makeInitialDateRange(around: Date())
        selectedBlockID = nil
        lastError = nil
        lastWriteDebug = nil
        activeTasks = nil
        activeTaskSummaries = []
        upcomingTasks = nil
        upcomingTaskSummaries = []
        inboxTasks = nil
        inboxTaskSummaries = []
    }

    func select(date: Date) async {
        selectedDate = date
        selectedBlockID = nil
        isShowingSettings = false
        await refreshSelected()
    }

    func refreshSelected() async {
        guard hasConnection else { return }
        let targetDate = selectedDate
        updateNote(date: targetDate) { note in
            note.loadState = .loading
        }
        isLoading = true
        lastError = nil

        do {
            let (root, raw) = try await client.fetchDailyNote(date: targetDate, connection: connection)
            updateNote(date: targetDate) { note in
                note.root = root
                note.rawResponse = raw
                note.loadState = root == nil ? .empty : .loaded
            }
            if selectedBlockID == nil {
                selectedBlockID = root?.children.first?.id ?? root?.id
            }
        } catch {
            updateNote(date: targetDate) { note in
                note.loadState = .failed(error.localizedDescription)
            }
            lastError = error.localizedDescription
        }

        await loadTasks()
        isLoading = false
    }

    func loadVisibleDates() async {
        guard hasConnection else { return }
        await refreshSelected()
        for offset in [-1, 1, -2, 2, -3, 3] {
            guard let date = Calendar.current.date(byAdding: .day, value: offset, to: selectedDate) else { continue }
            await fetchIfNeeded(date: date)
        }
    }

    func refreshTasks() async {
        guard hasConnection else { return }
        isLoading = true
        lastError = nil
        await loadTasks()
        isLoading = false
    }

    func expandEarlier() {
        guard let first = notes.first?.date else { return }
        let additions = (1...7).compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: first) }
        notes = additions.map { DailyNote(date: $0, root: nil, rawResponse: nil, loadState: .idle) } + notes
    }

    func expandLater() {
        guard let last = notes.last?.date else { return }
        let additions = (1...7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: last) }
        notes += additions.map { DailyNote(date: $0, root: nil, rawResponse: nil, loadState: .idle) }
    }

    func insertComposerText() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSaving = true
        lastError = nil
        do {
            let response = try await client.insertMarkdown(
                text,
                date: selectedDate,
                placement: insertPlacement,
                siblingID: selectedBlockID,
                connection: connection
            )
            lastWriteDebug = response
            composerText = ""
            await refreshSelected()
        } catch {
            lastError = error.localizedDescription
        }
        isSaving = false
    }

    func updateSelectedBlock(markdown: String) async {
        guard let selectedBlockID else { return }
        let text = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isSaving = true
        lastError = nil
        do {
            let response = try await client.updateBlockMarkdown(id: selectedBlockID, markdown: text, connection: connection)
            lastWriteDebug = response
            await refreshSelected()
        } catch {
            lastError = error.localizedDescription
        }
        isSaving = false
    }

    func completeTask(id: String) async {
        guard connection.usesMCP else {
            lastError = "Task completion needs the Craft MCP connection."
            return
        }

        isSaving = true
        lastError = nil
        do {
            lastWriteDebug = try await client.completeTask(id: id, connection: connection)
            await refreshSelected()
        } catch {
            lastError = error.localizedDescription
        }
        isSaving = false
    }

    func addTaskFromInput() async {
        let text = newTaskText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard connection.usesMCP else {
            lastError = "Adding Craft tasks needs the Craft MCP connection."
            return
        }

        isSaving = true
        lastError = nil
        do {
            let schedule = resolvedNewTaskSchedule
            lastWriteDebug = try await client.addTask(markdown: text, schedule: schedule, connection: connection)
            newTaskText = ""
            await loadTasks()
        } catch {
            lastError = error.localizedDescription
        }
        isSaving = false
    }

    func rescheduleTask(id: String, schedule: TaskScheduleChoice) async {
        guard connection.usesMCP else {
            lastError = "Changing Craft task dates needs the Craft MCP connection."
            return
        }

        isSaving = true
        lastError = nil
        do {
            lastWriteDebug = try await client.updateTaskSchedule(id: id, schedule: schedule, connection: connection)
            await loadTasks()
        } catch {
            lastError = error.localizedDescription
        }
        isSaving = false
    }

    private func fetchIfNeeded(date: Date) async {
        guard let note = notes.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }),
              note.loadState == .idle else { return }
        do {
            let (root, raw) = try await client.fetchDailyNote(date: date, connection: connection)
            updateNote(date: date) { note in
                note.root = root
                note.rawResponse = raw
                note.loadState = root == nil ? .empty : .loaded
            }
        } catch {
            updateNote(date: date) { note in
                note.loadState = .failed(error.localizedDescription)
            }
        }
    }

    private func loadTasks() async {
        do {
            let response = try await client.fetchTasks(scope: "active", connection: connection)
            activeTasks = response
            activeTaskSummaries = CraftTaskSummary.parse(from: response)
        } catch {
            activeTasks = nil
            activeTaskSummaries = []
        }

        do {
            let response = try await client.fetchTasks(scope: "upcoming", connection: connection)
            upcomingTasks = response
            upcomingTaskSummaries = CraftTaskSummary.parse(from: response)
        } catch {
            upcomingTasks = nil
            upcomingTaskSummaries = []
        }

        do {
            let response = try await client.fetchTasks(scope: "inbox", connection: connection)
            inboxTasks = response
            inboxTaskSummaries = CraftTaskSummary.parse(from: response)
        } catch {
            inboxTasks = nil
            inboxTaskSummaries = []
        }
    }

    private var resolvedNewTaskSchedule: TaskScheduleChoice {
        if case .custom = newTaskSchedule {
            return .custom(newTaskCustomDate)
        }
        return newTaskSchedule
    }

    private func updateNote(date: Date, update: (inout DailyNote) -> Void) {
        if let index = notes.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            update(&notes[index])
        } else {
            var note = DailyNote(date: date, root: nil, rawResponse: nil, loadState: .idle)
            update(&note)
            notes.append(note)
            notes.sort { $0.date < $1.date }
        }
    }

    private static func makeInitialDateRange(around date: Date) -> [DailyNote] {
        (-7...14).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: date)
        }
        .map { DailyNote(date: $0, root: nil, rawResponse: nil, loadState: .idle) }
    }
}
