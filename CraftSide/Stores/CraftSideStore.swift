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

    private let client: CraftDailyNotesClient
    private let keychain: KeychainStore

    init(client: CraftDailyNotesClient = CraftDailyNotesClient(), keychain: KeychainStore = .shared) {
        self.client = client
        self.keychain = keychain
        connection = CraftConnection(
            endpoint: keychain.string(for: "CraftAPIEndpoint") ?? "",
            apiKey: keychain.string(for: "CraftAPIKey") ?? ""
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

    func saveConnection(endpoint: String, apiKey: String) async {
        do {
            try keychain.set(endpoint, for: "CraftAPIEndpoint")
            try keychain.set(apiKey, for: "CraftAPIKey")
            connection = CraftConnection(endpoint: endpoint, apiKey: apiKey)
            await refreshSelected()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func disconnect() {
        keychain.delete(account: "CraftAPIEndpoint")
        keychain.delete(account: "CraftAPIKey")
        connection = CraftConnection(endpoint: "", apiKey: "")
        notes = Self.makeInitialDateRange(around: Date())
        selectedBlockID = nil
        lastError = nil
        lastWriteDebug = nil
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
            activeTasks = try await client.fetchTasks(scope: "active", connection: connection)
        } catch {
            activeTasks = nil
        }
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
