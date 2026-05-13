import Foundation

enum SidebarPosition: String, CaseIterable, Identifiable {
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        }
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Match System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum EditorMode: Equatable {
    case creating
    case editing(NoteSummary)
}

struct NoteSummary: Identifiable, Hashable {
    var id: String
    var title: String
    var preview: String
    var lastModifiedAt: Date?
    var isDailyNote: Bool
    var blockIdForEditing: String?
    var craftURL: URL?

    var displayTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : title
    }
}

struct NoteDocument: Identifiable, Hashable {
    var id: String
    var title: String
    var body: String
    var editableBlockId: String?
    var craftURL: URL?
}

struct CraftBlock: Codable, Identifiable, Hashable {
    var id: String
    var type: String?
    var markdown: String?
    var title: CraftTitle?
    var content: [CraftBlock]?
    var metadata: CraftMetadata?
}

struct CraftTitle: Codable, Hashable {
    var markdown: String?
    var text: String?
}

struct CraftMetadata: Codable, Hashable {
    var lastModifiedAt: Date?
    var createdAt: Date?
}

struct CraftDocumentListResponse: Decodable {
    var items: [CraftDocumentItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        items = try container.decodeIfPresent([CraftDocumentItem].self, forKey: DynamicCodingKey("items"))
            ?? container.decodeIfPresent([CraftDocumentItem].self, forKey: DynamicCodingKey("documents"))
            ?? []
    }
}

struct CraftDocumentItem: Decodable, Identifiable, Hashable {
    var id: String
    var title: String
    var isDeleted: Bool
    var metadata: CraftMetadata?
    var url: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case documentId
        case title
        case isDeleted
        case deleted
        case metadata
        case url
        case documentUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .documentId)
            ?? UUID().uuidString
        title = try container.decodeFlexibleTitle(forKey: .title) ?? "Untitled"
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted)
            ?? container.decodeIfPresent(Bool.self, forKey: .deleted)
            ?? false
        metadata = try container.decodeIfPresent(CraftMetadata.self, forKey: .metadata)
        url = try container.decodeIfPresent(String.self, forKey: .url)
            ?? container.decodeIfPresent(String.self, forKey: .documentUrl)
    }
}

struct CraftBlocksResponse: Decodable {
    var items: [CraftBlock]?
    var block: CraftBlock?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        items = try container.decodeIfPresent([CraftBlock].self, forKey: DynamicCodingKey("items"))
        block = try container.decodeIfPresent(CraftBlock.self, forKey: DynamicCodingKey("block"))

        if items == nil, block == nil {
            block = try? CraftBlock(from: decoder)
        }
    }

    var rootBlocks: [CraftBlock] {
        if let items, !items.isEmpty { return items }
        if let block { return [block] }
        return []
    }
}

struct CraftConnectionInfo: Decodable {
    struct Space: Decodable {
        var id: String?
        var name: String?
    }

    struct URLTemplates: Decodable {
        var block: String?
        var document: String?
        var dailyNote: String?
    }

    var space: Space?
    var urlTemplates: URLTemplates?
}

struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleTitle(forKey key: Key) throws -> String? {
        if let string = try decodeIfPresent(String.self, forKey: key) {
            return string
        }

        if let title = try decodeIfPresent(CraftTitle.self, forKey: key) {
            return title.markdown ?? title.text
        }

        return nil
    }
}

extension CraftBlock {
    var displayText: String {
        if let markdown, !markdown.isEmpty {
            return markdown
        }

        if let titleText = title?.markdown ?? title?.text, !titleText.isEmpty {
            return titleText
        }

        return ""
    }

    func flattenedTextBlocks() -> [CraftBlock] {
        var blocks: [CraftBlock] = []
        if type == "text" || markdown != nil {
            blocks.append(self)
        }
        content?.forEach { blocks.append(contentsOf: $0.flattenedTextBlocks()) }
        return blocks
    }

    func flattenedMarkdown() -> String {
        flattenedTextBlocks()
            .compactMap { $0.markdown }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n\n")
    }
}
