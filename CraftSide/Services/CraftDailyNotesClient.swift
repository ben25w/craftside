import Foundation

struct CraftConnection: Equatable {
    var endpoint: String
    var apiKey: String
    var mcpEndpoint: String

    var isConfigured: Bool {
        !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !mcpEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var usesMCP: Bool {
        !mcpEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

final class CraftDailyNotesClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchDailyNote(date: Date, connection: CraftConnection) async throws -> (CraftBlock?, JSONValue) {
        if connection.usesMCP {
            return try await fetchDailyNoteFromMCP(date: date, connection: connection)
        }

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
        if connection.usesMCP {
            return try await insertMarkdownWithMCP(
                markdown,
                date: date,
                placement: placement,
                siblingID: siblingID,
                connection: connection
            )
        }

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
        if connection.usesMCP {
            return try await callMCPTool(name: "craft_write", command: "blocks update --id \(id) --markdown \(Self.quotedMCPArgument(markdown))", connection: connection)
        }

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
        if connection.usesMCP {
            return try await callMCPTool(name: "craft_read", command: "tasks list --scope \(scope) --format json", connection: connection)
        }

        let data = try await request(
            path: "/tasks",
            query: [URLQueryItem(name: "scope", value: scope)],
            accept: "application/json",
            connection: connection
        )
        return try parseJSON(data)
    }

    func completeTask(id: String, connection: CraftConnection) async throws -> JSONValue {
        if connection.usesMCP {
            return try await callMCPTool(name: "craft_write", command: "tasks update --task \(id) --state done", connection: connection)
        }
        throw AppError.invalidResponse
    }

    func addTask(markdown: String, schedule: TaskScheduleChoice, connection: CraftConnection) async throws -> JSONValue {
        guard connection.usesMCP else { throw AppError.invalidResponse }

        var command = "tasks add --markdown \(Self.quotedMCPArgument(markdown))"
        switch schedule {
        case .inbox:
            command += " --location inbox"
        case .today:
            command += " --location dailyNote --date today --schedule today"
        case .tomorrow:
            command += " --location dailyNote --date tomorrow --schedule tomorrow"
        case .custom(let date):
            let text = DateFormatter.craftDate.string(from: date)
            command += " --location dailyNote --date \(text) --schedule \(text)"
        }
        return try await callMCPTool(name: "craft_write", command: command, connection: connection)
    }

    func updateTaskSchedule(id: String, schedule: TaskScheduleChoice, connection: CraftConnection) async throws -> JSONValue {
        guard connection.usesMCP else { throw AppError.invalidResponse }

        var command = "tasks update --task \(id)"
        switch schedule {
        case .inbox:
            command += " --location inbox"
        case .today:
            command += " --location dailyNote --date today --schedule today"
        case .tomorrow:
            command += " --location dailyNote --date tomorrow --schedule tomorrow"
        case .custom(let date):
            let text = DateFormatter.craftDate.string(from: date)
            command += " --location dailyNote --date \(text) --schedule \(text)"
        }
        return try await callMCPTool(name: "craft_write", command: command, connection: connection)
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

    private func fetchDailyNoteFromMCP(date: Date, connection: CraftConnection) async throws -> (CraftBlock?, JSONValue) {
        let dateText = DateFormatter.craftDate.string(from: date)
        let response = try await callMCPTool(
            name: "craft_read",
            command: "blocks get --date \(dateText) --format json",
            connection: connection
        )

        guard let text = response["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue else {
            return (nil, response)
        }

        let json = try parseJSON(Data(text.utf8))
        let root = extractBlocks(from: json).first
        return (root, json)
    }

    private func insertMarkdownWithMCP(
        _ markdown: String,
        date: Date,
        placement: InsertPlacement,
        siblingID: String?,
        connection: CraftConnection
    ) async throws -> JSONValue {
        let quotedMarkdown = Self.quotedMCPArgument(markdown)
        let command: String

        switch placement {
        case .start:
            command = "blocks add --date \(DateFormatter.craftDate.string(from: date)) --markdown \(quotedMarkdown) --position start"
        case .end:
            command = "blocks add --date \(DateFormatter.craftDate.string(from: date)) --markdown \(quotedMarkdown) --position end"
        case .before:
            if let siblingID {
                command = "blocks add --siblingId \(siblingID) --markdown \(quotedMarkdown) --position before"
            } else {
                command = "blocks add --date \(DateFormatter.craftDate.string(from: date)) --markdown \(quotedMarkdown) --position end"
            }
        case .after:
            if let siblingID {
                command = "blocks add --siblingId \(siblingID) --markdown \(quotedMarkdown) --position after"
            } else {
                command = "blocks add --date \(DateFormatter.craftDate.string(from: date)) --markdown \(quotedMarkdown) --position end"
            }
        }

        return try await callMCPTool(name: "craft_write", command: command, connection: connection)
    }

    private func callMCPTool(name: String, command: String, connection: CraftConnection) async throws -> JSONValue {
        guard let url = URL(string: connection.mcpEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AppError.invalidURL
        }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 10_000...99_999),
            "method": "tools/call",
            "params": [
                "name": name,
                "arguments": ["command": command]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let text = String(data: data, encoding: .utf8) ?? ""
        if text.hasPrefix("event:") || text.contains("\ndata:") {
            let dataLines = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .compactMap { line -> String? in
                    guard line.hasPrefix("data: ") else { return nil }
                    return String(line.dropFirst(6))
                }
                .joined(separator: "\n")
            return try parseJSON(Data(dataLines.utf8))
        }
        return try parseJSON(data)
    }

    private func parseJSON(_ data: Data) throws -> JSONValue {
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return JSONValue(any: object)
    }

    private func extractBlocks(from json: JSONValue) -> [CraftBlock] {
        if let data = json["data"]?.arrayValue {
            return data.map(CraftBlock.init(json:))
        }
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

    private static func quotedMCPArgument(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }
}
