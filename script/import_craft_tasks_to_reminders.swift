#!/usr/bin/env swift

import EventKit
import Foundation
import Security

private enum ScriptError: LocalizedError {
    case invalidArgument(String)
    case missingMCPURL
    case invalidMCPURL(String)
    case httpStatus(Int, String)
    case invalidResponse(String)
    case timeout
    case remindersDenied
    case missingDefaultReminderList

    var errorDescription: String? {
        switch self {
        case .invalidArgument(let value):
            return "Unknown argument: \(value)"
        case .missingMCPURL:
            return """
            No Craft MCP URL found.
            Set CRAFT_MCP_URL, or save the Craft MCP URL in CraftSide settings first.
            """
        case .invalidMCPURL(let value):
            return "The Craft MCP URL is not valid: \(value)"
        case .httpStatus(let status, let body):
            return body.isEmpty ? "Craft MCP returned HTTP \(status)." : "Craft MCP returned HTTP \(status): \(body)"
        case .invalidResponse(let detail):
            return "Could not read the Craft MCP response: \(detail)"
        case .timeout:
            return "Craft MCP request timed out."
        case .remindersDenied:
            return "Reminders access was not granted."
        case .missingDefaultReminderList:
            return "Apple Reminders does not have a default list for new reminders."
        }
    }
}

private struct Options {
    var dryRun = false

    static func parse(_ arguments: [String]) throws -> Options {
        var options = Options()
        for argument in arguments {
            switch argument {
            case "--dry-run":
                options.dryRun = true
            case "--help", "-h":
                printUsage()
                exit(0)
            default:
                throw ScriptError.invalidArgument(argument)
            }
        }
        return options
    }

    private static func printUsage() {
        print("""
        Import open Craft todos into Apple Reminders.

        Usage:
          swift script/import_craft_tasks_to_reminders.swift [--dry-run]

        Options:
          --dry-run   Read and parse Craft tasks, but do not create reminders.
          --help      Show this help text.

        The script reads the Craft MCP URL from CRAFT_MCP_URL first, then from
        the CraftSide Keychain item service=com.ben.CraftSide account=CraftMCPURL.
        """)
    }
}

private struct CraftTask {
    var id: String
    var title: String
    var schedule: DateComponents?
    var deadline: DateComponents?
    var scope: String

    var reminderDate: DateComponents? {
        schedule ?? deadline
    }
}

private final class CraftMCPClient {
    private let url: URL
    private let timeout: TimeInterval = 30

    init(endpoint: String) throws {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme, ["http", "https"].contains(scheme.lowercased()) else {
            throw ScriptError.invalidMCPURL(trimmed)
        }
        self.url = url
    }

    func listTasks(scope: String) throws -> [CraftTask] {
        let text = try callRead(command: "tasks list --scope \(scope)")
        return CraftTaskParser.parse(text: text, scope: scope)
    }

    private func callRead(command: String) throws -> String {
        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": Int.random(in: 10_000...99_999),
            "method": "tools/call",
            "params": [
                "name": "craft_read",
                "arguments": ["command": command]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try perform(request: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScriptError.invalidResponse("missing HTTP response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ScriptError.httpStatus(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let jsonData = extractJSONData(from: data)
        let object = try JSONSerialization.jsonObject(with: jsonData, options: [])
        guard let dictionary = object as? [String: Any] else {
            throw ScriptError.invalidResponse("top-level JSON was not an object")
        }

        if let error = dictionary["error"] {
            throw ScriptError.invalidResponse(String(describing: error))
        }

        guard let result = dictionary["result"] as? [String: Any] else {
            throw ScriptError.invalidResponse("missing result")
        }
        if (result["isError"] as? Bool) == true {
            let message = extractText(from: result).ifEmpty("Craft returned an error result")
            throw ScriptError.invalidResponse(message)
        }
        return extractText(from: result)
    }

    private func perform(request: URLRequest) throws -> (Data, URLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var taskResult: Result<(Data, URLResponse), Error>?

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                taskResult = .failure(error)
            } else if let data, let response {
                taskResult = .success((data, response))
            } else {
                taskResult = .failure(ScriptError.invalidResponse("empty response"))
            }
            semaphore.signal()
        }

        task.resume()
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            task.cancel()
            throw ScriptError.timeout
        }

        return try taskResult?.get() ?? { throw ScriptError.invalidResponse("request did not finish") }()
    }

    private func extractJSONData(from data: Data) -> Data {
        let text = String(data: data, encoding: .utf8) ?? ""
        guard text.hasPrefix("event:") || text.contains("\ndata:") else {
            return data
        }

        let combined = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .compactMap { line -> String? in
                guard line.hasPrefix("data: ") else { return nil }
                let value = String(line.dropFirst(6))
                return value == "[DONE]" ? nil : value
            }
            .joined(separator: "\n")

        return Data(combined.utf8)
    }

    private func extractText(from result: [String: Any]) -> String {
        guard let content = result["content"] as? [[String: Any]] else {
            return ""
        }
        return content
            .compactMap { item in item["text"] as? String }
            .joined(separator: "\n")
    }
}

private enum CraftTaskParser {
    static func parse(text: String, scope: String) -> [CraftTask] {
        var tasks: [CraftTask] = []
        var pending: CraftTask?
        var fallbackID = 0

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let task = parseTaskLine(line, scope: scope, fallbackID: &fallbackID) {
                if let pending {
                    tasks.append(pending)
                }
                pending = task
            } else if let date = parseDateLine(line, key: "schedule") {
                pending?.schedule = date
            } else if let date = parseDateLine(line, key: "deadline") {
                pending?.deadline = date
            }
        }

        if let pending {
            tasks.append(pending)
        }

        return tasks
    }

    private static func parseTaskLine(_ line: String, scope: String, fallbackID: inout Int) -> CraftTask? {
        if let idStart = line.firstIndex(of: "<"), let idEnd = line[idStart...].firstIndex(of: ">") {
            let id = String(line[line.index(after: idStart)..<idEnd])
            var titleText = line
            titleText.removeSubrange(idStart...idEnd)
            let title = cleanedTitle(titleText)
            guard !title.isEmpty else { return nil }
            return CraftTask(id: id, title: title, schedule: nil, deadline: nil, scope: scope)
        }

        if line.hasPrefix("- [ ]") || line.hasPrefix("- [x]") || line.hasPrefix("- [X]") {
            fallbackID += 1
            let title = cleanedTitle(line)
            guard !title.isEmpty else { return nil }
            return CraftTask(id: "\(scope)-\(fallbackID)", title: title, schedule: nil, deadline: nil, scope: scope)
        }

        return nil
    }

    private static func cleanedTitle(_ text: String) -> String {
        text
            .replacingOccurrences(of: "- [ ]", with: "")
            .replacingOccurrences(of: "- [x]", with: "")
            .replacingOccurrences(of: "- [X]", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseDateLine(_ line: String, key: String) -> DateComponents? {
        let parenthesizedPrefix = "(\(key):"
        let plainPrefix = "\(key):"
        let prefix: String
        if line.hasPrefix(parenthesizedPrefix) {
            prefix = parenthesizedPrefix
        } else if line.hasPrefix(plainPrefix) {
            prefix = plainPrefix
        } else {
            return nil
        }

        let value = line
            .replacingOccurrences(of: prefix, with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = .current
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return components
    }
}

private final class ReminderImporter {
    private let store = EKEventStore()

    func importTasks(_ tasks: [CraftTask]) throws -> Int {
        guard try requestAccess() else {
            throw ScriptError.remindersDenied
        }
        guard let list = store.defaultCalendarForNewReminders() else {
            throw ScriptError.missingDefaultReminderList
        }

        for task in tasks {
            let reminder = EKReminder(eventStore: store)
            reminder.calendar = list
            reminder.title = task.title
            reminder.dueDateComponents = task.reminderDate
            try store.save(reminder, commit: false)
        }

        try store.commit()
        return tasks.count
    }

    private func requestAccess() throws -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false
        var accessError: Error?

        if #available(macOS 14.0, *) {
            store.requestFullAccessToReminders { didGrant, error in
                granted = didGrant
                accessError = error
                semaphore.signal()
            }
        } else {
            store.requestAccess(to: .reminder) { didGrant, error in
                granted = didGrant
                accessError = error
                semaphore.signal()
            }
        }

        semaphore.wait()
        if let accessError {
            throw accessError
        }
        return granted
    }
}

private func mcpEndpoint() throws -> String {
    if let value = ProcessInfo.processInfo.environment["CRAFT_MCP_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines),
       !value.isEmpty {
        return value
    }

    if let value = try keychainString(service: "com.ben.CraftSide", account: "CraftMCPURL")?.trimmingCharacters(in: .whitespacesAndNewlines),
       !value.isEmpty {
        return value
    }

    throw ScriptError.missingMCPURL
}

private func keychainString(service: String, account: String) throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound {
        return nil
    }
    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
    guard let data = result as? Data else {
        return nil
    }
    return String(data: data, encoding: .utf8)
}

private func printSummary(active: [CraftTask], upcoming: [CraftTask], inbox: [CraftTask]) {
    print("Active: \(active.count)")
    print("Upcoming: \(upcoming.count)")
    print("Inbox: \(inbox.count)")
    print("Total reminders to add: \(active.count + upcoming.count + inbox.count)")
}

private func printDryRun(_ tasks: [CraftTask]) {
    let formatter = DateComponentsFormatter()
    _ = formatter

    print("")
    print("Dry run only. No reminders were created.")
    for task in tasks {
        let date = task.reminderDate.map(formatDate) ?? "no date"
        print("- [\(task.scope)] \(task.title) (\(date))")
    }
}

private func formatDate(_ components: DateComponents) -> String {
    guard let year = components.year, let month = components.month, let day = components.day else {
        return "no date"
    }
    return String(format: "%04d-%02d-%02d", year, month, day)
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

do {
    let options = try Options.parse(Array(CommandLine.arguments.dropFirst()))
    let client = try CraftMCPClient(endpoint: try mcpEndpoint())

    let active = try client.listTasks(scope: "active")
    let upcoming = try client.listTasks(scope: "upcoming")
    let inbox = try client.listTasks(scope: "inbox")
    let tasks = active + upcoming + inbox

    printSummary(active: active, upcoming: upcoming, inbox: inbox)

    if options.dryRun {
        printDryRun(tasks)
    } else {
        let created = try ReminderImporter().importTasks(tasks)
        print("Created \(created) reminder\(created == 1 ? "" : "s") in your default Reminders list.")
    }
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
