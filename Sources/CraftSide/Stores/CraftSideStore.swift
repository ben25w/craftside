import Foundation

@MainActor
final class CraftSideStore: ObservableObject {
    @Published var connection = CraftConnection(endpoint: "", apiKey: "")
    @Published var connectionName = ""
    @Published var allNotes: [NoteSummary] = []
    @Published var dailyNote: NoteSummary?
    @Published var selectedNote: NoteSummary?
    @Published var selectedDocument: NoteDocument?
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var isShowingSettings = false
    @Published var editorMode: EditorMode?
    @Published var draftTitle = ""
    @Published var draftBody = ""

    private let api: CraftAPIClient
    private let keychain: KeychainStore
    private let pinnedDefaultsKey = "PinnedNoteIDs"
    private var pinnedIDs: Set<String>

    init(api: CraftAPIClient = CraftAPIClient(), keychain: KeychainStore = .shared) {
        self.api = api
        self.keychain = keychain
        pinnedIDs = Set(UserDefaults.standard.stringArray(forKey: pinnedDefaultsKey) ?? [])
        connection = CraftConnection(
            endpoint: keychain.string(for: "CraftAPIEndpoint") ?? "",
            apiKey: keychain.string(for: "CraftAPIKey") ?? ""
        )
    }

    var isConfigured: Bool {
        connection.isConfigured
    }

    var filteredNotes: [NoteSummary] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else {
            return allNotes
        }

        return allNotes.filter { note in
            note.title.localizedCaseInsensitiveContains(trimmedSearch)
                || note.preview.localizedCaseInsensitiveContains(trimmedSearch)
        }
    }

    var pinnedNotes: [NoteSummary] {
        filteredNotes.filter { pinnedIDs.contains($0.id) }
    }

    var unpinnedNotes: [NoteSummary] {
        filteredNotes.filter { !pinnedIDs.contains($0.id) }
    }

    func saveConnection(endpoint: String, apiKey: String) async {
        do {
            try keychain.set(endpoint, for: "CraftAPIEndpoint")
            try keychain.set(apiKey, for: "CraftAPIKey")
            connection = CraftConnection(endpoint: endpoint, apiKey: apiKey)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() {
        keychain.delete(account: "CraftAPIEndpoint")
        keychain.delete(account: "CraftAPIKey")
        connection = CraftConnection(endpoint: "", apiKey: "")
        connectionName = ""
        allNotes = []
        dailyNote = nil
        selectedNote = nil
        selectedDocument = nil
    }

    func load() async {
        guard isConfigured else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let connectionInfo = try? api.connectionInfo(using: connection)
            async let documents = try? api.fetchDocuments(search: nil, using: connection)
            async let daily = try? api.fetchTodayDailyNote(using: connection)

            if let info = await connectionInfo {
                connectionName = info.space?.name ?? ""
            }
            if let loadedDocuments = await documents {
                allNotes = loadedDocuments
            }
            dailyNote = await daily

            if allNotes.isEmpty, let dailyNote {
                allNotes = []
                selectedNote = selectedNote ?? dailyNote
            }
        }
    }

    func select(_ note: NoteSummary) async {
        selectedNote = note
        editorMode = nil
        errorMessage = nil

        do {
            selectedDocument = try await api.fetchDocument(note, using: connection)
        } catch {
            selectedDocument = NoteDocument(
                id: note.id,
                title: note.displayTitle,
                body: note.preview,
                editableBlockId: note.blockIdForEditing,
                craftURL: note.craftURL
            )
            errorMessage = error.localizedDescription
        }
    }

    func startCreating() {
        selectedNote = nil
        selectedDocument = nil
        editorMode = .creating
        draftTitle = ""
        draftBody = ""
    }

    func startEditingSelectedDocument() {
        guard let selectedDocument, let selectedNote else { return }
        editorMode = .editing(selectedNote)
        draftTitle = selectedDocument.title
        draftBody = selectedDocument.body
    }

    func cancelEditing() {
        editorMode = nil
        draftTitle = ""
        draftBody = ""
    }

    func saveDraft() async {
        guard isConfigured else {
            errorMessage = AppError.missingConnection.localizedDescription
            return
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            switch editorMode {
            case .creating:
                do {
                    try await api.createDocument(title: draftTitle, body: draftBody, using: connection)
                } catch {
                    let fallback = [draftTitle, draftBody]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: "\n\n")
                    try await api.insertIntoToday(markdown: fallback.isEmpty ? "Untitled" : fallback, using: connection)
                }
                editorMode = nil
                await load()

            case .editing:
                guard let blockID = selectedDocument?.editableBlockId ?? selectedNote?.blockIdForEditing else {
                    throw AppError.invalidResponse
                }
                let markdown = [draftTitle, draftBody]
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n\n")
                try await api.updateBlock(id: blockID, markdown: markdown, using: connection)
                editorMode = nil
                if let selectedNote {
                    await select(selectedNote)
                }
                await load()

            case nil:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ensureTodayDailyNote() async {
        do {
            try await api.insertIntoToday(markdown: "# \(DateFormatting.isoDate.string(from: Date()))", using: connection)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isPinned(_ note: NoteSummary) -> Bool {
        pinnedIDs.contains(note.id)
    }

    func togglePin(_ note: NoteSummary) {
        if pinnedIDs.contains(note.id) {
            pinnedIDs.remove(note.id)
        } else {
            pinnedIDs.insert(note.id)
        }
        UserDefaults.standard.set(Array(pinnedIDs), forKey: pinnedDefaultsKey)
        objectWillChange.send()
    }
}
