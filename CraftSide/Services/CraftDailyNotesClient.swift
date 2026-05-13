import Foundation

struct CraftConnection: Equatable {
    var endpoint: String
    var apiKey: String

    var isConfigured: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class CraftDailyNotesClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDailyNote(date: Date, connection: CraftConnection) async throws -> (CraftBlock?, JSONValue) {
        let data = try await request(
            path: "/blocks",
            query: [
                URLQueryItem(name: "date", value: DateFormatter.craftDate.string(from: date)),
                URLQueryItem(name: "maxDepth", value: "-1"),
                URLQueryItem(name: "fetchMetadata", value: "true")
            ],
            accept: "application/json",
            connection: connection
        )

        let json = try parseJSON(data)
        let root = extractBlocks(from: json).first
        return (root, json)
    }

    func fetchMarkdown(date: Date, connection: CraftConnection) async throws -> String {
        let data = try await request(
            path: "/blocks",
            query: [
                URLQueryItem(name: "date", value: DateFormatter.craftDate.string(from: date)),
                URLQueryItem(name: "maxDepth", value: "-1")
            ],
            accept: "text/markdown",
            connection: connection
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    func insertMarkdown(
        _ markdown: String,
        date: Date,
        placement: InsertPlacement,
        siblingID: String?,
        connection: CraftConnection
    ) async throws -> JSONValue {
        let dateText = DateFormatter.craftDate.string(from: date)
        let position: [String: String]

        switch placement {
        case .start:
            position = ["position": "start", "date": dateText]
        case .end:
            position = ["position": "end", "date": dateText]
        case .before:
            guard let siblingID else {
                position = ["position": "end", "date": dateText]
                break
            }
            position = ["position": "before", "siblingId": siblingID]
        case .after:
            guard let siblingID else {
                position = ["position": "end", "date": dateText]
                break
            }
            position = ["position": "after", "siblingId": siblingID]
        }

        let positionData = try JSONSerialization.data(withJSONObject: position, options: [])
        let positionText = String(data: positionData, encoding: .utf8) ?? "{\"position\":\"end\",\"date\":\"\(dateText)\"}"
        let data = try await request(
            path: "/blocks",
            query: [URLQueryItem(name: "position", value: positionText)],
            method: "POST",
            body: Data(markdown.utf8),
            contentType: "text/markdown",
            accept: "application/json",
            connection: connection
        )
        return try parseJSON(data)
    }

    func updateBlockMarkdown(id: String, markdown: String, connection: CraftConnection) async throws -> JSONValue {
        let payload: [String: Any] = [
            "blocks": [
                [
                    "id": id,
                    "markdown": markdown
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let response = try await request(
            path: "/blocks",
            method: "PUT",
            body: data,
            contentType: "application/json",
            accept: "application/json",
            connection: connection
        )
        return try parseJSON(response)
    }

    func fetchTasks(scope: String, connection: CraftConnection) async throws -> JSONValue {
        let data = try await request(
            path: "/tasks",
            query: [URLQueryItem(name: "scope", value: scope)],
            accept: "application/json",
            connection: connection
        )
        return try parseJSON(data)
    }

    private func request(
        path: String,
        query: [URLQueryItem] = [],
        method: String = "GET",
        body: Data? = nil,
        contentType: String? = nil,
        accept: String,
        connection: CraftConnection
    ) async throws -> Data {
        guard connection.isConfigured else {
            throw AppError.missingConnection
        }

        let base = connection.endpoint
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: base + path) else {
            throw AppError.invalidURL
        }
        components.queryItems = query.isEmpty ? nil : query

        guard let url = components.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if !connection.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.setValue("Bearer \(connection.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    private func parseJSON(_ data: Data) throws -> JSONValue {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return JSONValue(any: object)
    }

    private func extractBlocks(from json: JSONValue) -> [CraftBlock] {
        if let items = json["items"]?.arrayValue {
            return items.map(CraftBlock.init(json:))
        }
        if let block = json["block"] {
            return [CraftBlock(json: block)]
        }
        if json["type"]?.stringValue != nil {
            return [CraftBlock(json: json)]
        }
        return []
    }
}
