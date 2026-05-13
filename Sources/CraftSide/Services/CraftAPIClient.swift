import Foundation

struct CraftConnection: Equatable {
    var endpoint: String
    var apiKey: String

    var isConfigured: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class CraftAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: raw)
                ?? ISO8601DateFormatter.standard.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date")
        }
    }

    func connectionInfo(using connection: CraftConnection) async throws -> CraftConnectionInfo {
        let data = try await request(path: "/connection", using: connection)
        return try decoder.decode(CraftConnectionInfo.self, from: data)
    }

    func fetchDocuments(search: String?, using connection: CraftConnection) async throws -> [NoteSummary] {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "fetchMetadata", value: "true")
        ]

        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "search", value: search))
        }

        let data = try await request(path: "/documents", query: query, using: connection)
        let response = try decoder.decode(CraftDocumentListResponse.self, from: data)

        return response.items
            .filter { !$0.isDeleted }
            .map { item in
                NoteSummary(
                    id: item.id,
                    title: item.title,
                    preview: DateFormatting.shortRelative(item.metadata?.lastModifiedAt),
                    lastModifiedAt: item.metadata?.lastModifiedAt,
                    isDailyNote: false,
                    blockIdForEditing: item.id,
                    craftURL: item.url.flatMap(URL.init(string:))
                )
            }
            .sorted { first, second in
                (first.lastModifiedAt ?? .distantPast) > (second.lastModifiedAt ?? .distantPast)
            }
    }

    func fetchTodayDailyNote(using connection: CraftConnection) async throws -> NoteSummary? {
        let query = [
            URLQueryItem(name: "date", value: "today"),
            URLQueryItem(name: "fetchMetadata", value: "true")
        ]
        let data = try await request(path: "/blocks", query: query, using: connection)
        let response = try decoder.decode(CraftBlocksResponse.self, from: data)
        guard let block = response.rootBlocks.first else {
            return nil
        }

        let title = block.displayText.isEmpty ? "Today's Daily Note" : block.displayText
        let preview = block.flattenedMarkdown().firstLineFallback("Daily note")

        return NoteSummary(
            id: block.id,
            title: title,
            preview: preview,
            lastModifiedAt: block.metadata?.lastModifiedAt,
            isDailyNote: true,
            blockIdForEditing: block.id,
            craftURL: nil
        )
    }

    func fetchDocument(_ summary: NoteSummary, using connection: CraftConnection) async throws -> NoteDocument {
        let data = try await request(
            path: "/blocks",
            query: [
                URLQueryItem(name: "id", value: summary.id),
                URLQueryItem(name: "fetchContent", value: "true"),
                URLQueryItem(name: "fetchMetadata", value: "true")
            ],
            using: connection
        )

        let response = try decoder.decode(CraftBlocksResponse.self, from: data)
        guard let root = response.rootBlocks.first else {
            throw AppError.invalidResponse
        }

        let textBlocks = root.flattenedTextBlocks()
        let body = root.flattenedMarkdown()
        let editableBlockId = textBlocks.first?.id ?? root.id

        return NoteDocument(
            id: root.id,
            title: root.displayText.isEmpty ? summary.displayTitle : root.displayText,
            body: body,
            editableBlockId: editableBlockId,
            craftURL: summary.craftURL
        )
    }

    func createDocument(title: String, body: String, using connection: CraftConnection) async throws {
        let markdown = [title, body]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let payload: [String: Any] = [
            "documents": [
                [
                    "title": title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title,
                    "content": [
                        [
                            "type": "text",
                            "markdown": markdown.isEmpty ? "Untitled" : markdown
                        ]
                    ]
                ]
            ]
        ]

        try await sendJSON(path: "/documents", method: "POST", payload: payload, using: connection)
    }

    func updateBlock(id: String, markdown: String, using connection: CraftConnection) async throws {
        let payload: [String: Any] = [
            "blocks": [
                [
                    "id": id,
                    "type": "text",
                    "markdown": markdown
                ]
            ]
        ]

        try await sendJSON(path: "/blocks", method: "PUT", payload: payload, using: connection)
    }

    func insertIntoToday(markdown: String, using connection: CraftConnection) async throws {
        let payload: [String: Any] = [
            "date": "today",
            "blocks": [
                [
                    "type": "text",
                    "markdown": markdown
                ]
            ]
        ]

        try await sendJSON(path: "/blocks", method: "POST", payload: payload, using: connection)
    }

    private func sendJSON(path: String, method: String, payload: [String: Any], using connection: CraftConnection) async throws {
        let body = try JSONSerialization.data(withJSONObject: payload)
        _ = try await request(path: path, method: method, body: body, using: connection)
    }

    @discardableResult
    private func request(
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        using connection: CraftConnection
    ) async throws -> Data {
        guard connection.isConfigured else {
            throw AppError.missingConnection
        }

        guard var components = URLComponents(string: normalizedBaseURL(connection.endpoint) + path) else {
            throw AppError.invalidURL
        }
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if !connection.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(connection.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw AppError.httpStatus(httpResponse.statusCode, bodyText)
        }

        return data
    }

    private func normalizedBaseURL(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

private extension String {
    func firstLineFallback(_ fallback: String) -> String {
        split(whereSeparator: \.isNewline)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? fallback
    }

    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
