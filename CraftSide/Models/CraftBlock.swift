import Foundation

struct CraftBlock: Identifiable, Equatable {
    var id: String
    var type: String
    var markdown: String
    var title: String
    var textStyle: String
    var listStyle: String
    var indentationLevel: Int
    var url: String?
    var fileName: String?
    var rawCode: String?
    var language: String?
    var lineStyle: String?
    var taskState: String?
    var children: [CraftBlock]
    var raw: JSONValue

    init(json: JSONValue) {
        raw = json
        id = json["id"]?.stringValue ?? UUID().uuidString
        type = json["type"]?.stringValue ?? "unknown"
        markdown = json["markdown"]?.stringValue ?? ""
        textStyle = json["textStyle"]?.stringValue ?? "body"
        listStyle = json["listStyle"]?.stringValue ?? "none"
        indentationLevel = json["indentationLevel"]?.intValue ?? 0
        url = json["url"]?.stringValue
        fileName = json["fileName"]?.stringValue
        rawCode = json["rawCode"]?.stringValue
        language = json["language"]?.stringValue
        lineStyle = json["lineStyle"]?.stringValue
        taskState = json["taskInfo"]?["state"]?.stringValue

        if let titleMarkdown = json["title"]?["markdown"]?.stringValue {
            title = titleMarkdown
        } else if let titleText = json["title"]?["text"]?.stringValue {
            title = titleText
        } else if let titleString = json["title"]?.stringValue {
            title = titleString
        } else {
            title = ""
        }

        children = json["content"]?.arrayValue?.map(CraftBlock.init(json:)) ?? []
    }

    var displayText: String {
        if !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return markdown
        }
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        if let fileName, !fileName.isEmpty {
            return fileName
        }
        if let url, !url.isEmpty {
            return url
        }
        if let rawCode, !rawCode.isEmpty {
            return rawCode
        }
        return ""
    }

    var isRenderable: Bool {
        !displayText.isEmpty || type == "line" || type == "image" || type == "video" || type == "file" || type == "richUrl"
    }

    var allBlocksDepthFirst: [CraftBlock] {
        [self] + children.flatMap(\.allBlocksDepthFirst)
    }

    var contentPreview: String {
        allBlocksDepthFirst
            .map(\.displayText)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "Empty daily note"
    }
}

struct DailyNote: Identifiable, Equatable {
    var date: Date
    var root: CraftBlock?
    var rawResponse: JSONValue?
    var loadState: LoadState

    var id: String { DateFormatter.craftDate.string(from: date) }

    var title: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInTomorrow(date) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return DateFormatter.dayTitle.string(from: date)
    }

    var subtitle: String {
        DateFormatter.craftDate.string(from: date)
    }

    var preview: String {
        root?.contentPreview ?? loadState.label
    }

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)

        var label: String {
            switch self {
            case .idle: "Not loaded"
            case .loading: "Loading"
            case .loaded: "Loaded"
            case .empty: "No blocks"
            case .failed(let message): message
            }
        }
    }
}

extension DateFormatter {
    static let craftDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let dayTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
