import Foundation

struct CraftTaskSummary: Identifiable, Equatable {
    var id: String
    var title: String
    var schedule: Date?
    var location: String

    var isToday: Bool {
        guard let schedule else { return false }
        return Calendar.current.isDateInToday(schedule)
    }

    var isTomorrow: Bool {
        guard let schedule else { return false }
        return Calendar.current.isDateInTomorrow(schedule)
    }

    var isOverdue: Bool {
        guard let schedule else { return false }
        return Calendar.current.startOfDay(for: schedule) < Calendar.current.startOfDay(for: Date())
    }

    var scheduleLabel: String {
        guard let schedule else { return "" }
        if Calendar.current.isDateInToday(schedule) { return "Today" }
        if Calendar.current.isDateInTomorrow(schedule) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(schedule) { return "Yesterday" }
        return DateFormatter.shortTaskDate.string(from: schedule)
    }

    var locationLabel: String {
        if location.contains("daily note") {
            return "Daily Note"
        }
        if location.isEmpty {
            return "Craft"
        }
        return location.capitalized
    }

    static func parse(from json: JSONValue) -> [CraftTaskSummary] {
        guard let text = json["result"]?["content"]?.arrayValue?.first?["text"]?.stringValue else {
            return []
        }

        var tasks: [CraftTaskSummary] = []
        var pending: CraftTaskSummary?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if let task = parseTaskLine(line) {
                if let pending {
                    tasks.append(pending)
                }
                pending = task
            } else if line.hasPrefix("(schedule:") {
                pending?.schedule = parseSchedule(line)
            } else if line.hasPrefix("in:") {
                pending?.location = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        if let pending {
            tasks.append(pending)
        }
        return tasks
    }

    private static func parseTaskLine(_ line: String) -> CraftTaskSummary? {
        guard let idStart = line.firstIndex(of: "<"),
              let idEnd = line[idStart...].firstIndex(of: ">") else {
            return nil
        }

        let id = String(line[line.index(after: idStart)..<idEnd])
        let suffix = line[line.index(after: idEnd)...]
        let title = suffix
            .replacingOccurrences(of: "- [ ]", with: "")
            .replacingOccurrences(of: "- [x]", with: "")
            .replacingOccurrences(of: "- [X]", with: "")
            .replacingOccurrences(of: "- ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return CraftTaskSummary(id: id, title: title, schedule: nil, location: "")
    }

    private static func parseSchedule(_ line: String) -> Date? {
        let value = line
            .replacingOccurrences(of: "(schedule:", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DateFormatter.craftDate.date(from: value)
    }
}

extension DateFormatter {
    static let shortTaskDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM"
        return formatter
    }()
}
