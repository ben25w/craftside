import SwiftUI

struct DailyNoteDetailView: View {
    @EnvironmentObject private var store: CraftSideStore
    @State private var editingText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.selectedNote?.title ?? "Daily Note")
                        .font(.title3.bold())
                    Text(store.selectedNote?.subtitle ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.isShowingDebug.toggle()
                } label: {
                    Image(systemName: "ladybug")
                }
                .buttonStyle(PlainIconButtonStyle())
                .help("Debug API response")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if let error = store.lastError {
                ErrorBanner(message: error)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }

            if store.isShowingDebug {
                DebugView()
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.selectedRoot == nil {
            ProgressView("Loading Daily Note")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let root = store.selectedRoot {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if store.connection.usesMCP, !store.activeTaskSummaries.isEmpty {
                        TaskBoardView(tasks: store.activeTaskSummaries)
                    }

                    if root.children.isEmpty {
                        BlockRow(block: root)
                    } else {
                        ForEach(root.children) { block in
                            BlockTreeView(block: block)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No daily note content loaded")
                    .font(.headline)
                Text("Refresh this date or use the composer to create the first block.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct BlockTreeView: View {
    let block: CraftBlock

    var body: some View {
        Group {
            if block.shouldRenderAsCard {
                VStack(alignment: .leading, spacing: 10) {
                    BlockRow(block: block)
                    if !block.children.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(block.children) { child in
                                BlockTreeView(block: child)
                            }
                        }
                        .padding(.leading, 8)
                    }
                }
                .padding(12)
                .background(CraftPalette.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CraftPalette.border, lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    BlockRow(block: block)
                    if !block.children.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(block.children) { child in
                                BlockTreeView(block: child)
                            }
                        }
                        .padding(.leading, 18)
                    }
                }
            }
        }
    }
}

private struct BlockRow: View {
    @EnvironmentObject private var store: CraftSideStore
    let block: CraftBlock
    @State private var editText = ""
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                store.selectedBlockID = block.id
                editText = block.displayText
            } label: {
                HStack(alignment: .top, spacing: 8) {
                    leadingMarker
                        .frame(width: 18)

                    blockContent
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if isSelected {
                        Image(systemName: "target")
                            .foregroundStyle(CraftPalette.purple)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(rowBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(isSelected ? CraftPalette.purple.opacity(0.45) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Edit This Block") {
                    store.selectedBlockID = block.id
                    editText = block.displayText
                    isEditing = true
                }
                Button("Insert Above") {
                    store.selectedBlockID = block.id
                    store.insertPlacement = .before
                }
                Button("Insert Below") {
                    store.selectedBlockID = block.id
                    store.insertPlacement = .after
                }
            }

            if isSelected && isEditing {
                VStack(spacing: 8) {
                    TextEditor(text: $editText)
                        .font(.body)
                        .frame(minHeight: 80)
                        .padding(6)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))

                    HStack {
                        Button("Cancel") {
                            isEditing = false
                        }
                        Spacer()
                        Button {
                            Task {
                                await store.updateSelectedBlock(markdown: editText)
                                isEditing = false
                            }
                        } label: {
                            Label("Update Block", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(10)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var isSelected: Bool {
        store.selectedBlockID == block.id
    }

    private var rowBackground: Color {
        isSelected ? CraftPalette.purpleSoft : block.type == "table" ? CraftPalette.taskPanel : Color.clear
    }

    @ViewBuilder
    private var leadingMarker: some View {
        switch block.listStyle {
        case "task":
            Image(systemName: block.taskState == "done" ? "checkmark.square.fill" : "square")
                .foregroundStyle(block.taskState == "done" ? Color.primary : .secondary)
        case "bullet":
            Text("•")
                .foregroundStyle(.secondary)
        case "numbered":
            Text("1.")
                .font(.caption)
                .foregroundStyle(.secondary)
        default:
            if block.textStyle == "h2" || block.textStyle == "h3" || block.textStyle == "page" {
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                Image(systemName: iconName)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block.type {
        case "line":
            Divider()
                .padding(.vertical, 6)
        case "image", "video", "file", "drawing", "whiteboard":
            AttachmentBlockView(block: block)
        case "richUrl":
            LinkBlockView(block: block)
        case "code":
            CodeBlockView(block: block)
        default:
            if block.isRenderable {
                MarkdownText(block.displayText, textStyle: block.textStyle)
            } else {
                UnsupportedBlockView(block: block)
            }
        }
    }

    private var iconName: String {
        switch block.type {
        case "page": "doc"
        case "collection", "collectionItem": "tablecells"
        case "code": "curlybraces"
        case "richUrl": "link"
        default: "text.alignleft"
        }
    }
}

private struct MarkdownText: View {
    let text: String
    let textStyle: String

    init(_ text: String, textStyle: String) {
        self.text = text
        self.textStyle = textStyle
    }

    var body: some View {
        Text(attributed)
            .font(font)
            .textSelection(.enabled)
            .lineSpacing(2)
            .strikethrough(text.contains("~~"))
    }

    private var attributed: AttributedString {
        (try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    private var font: Font {
        switch textStyle {
        case "h1": .system(size: 28, weight: .bold, design: .rounded)
        case "h2": .system(size: 18, weight: .bold, design: .rounded)
        case "h3": .system(size: 16, weight: .semibold, design: .rounded)
        case "h4": .headline
        case "page": .system(size: 18, weight: .bold, design: .rounded)
        case "caption": .caption
        default: .system(size: 14.5, weight: .regular, design: .default)
        }
    }
}

private struct TaskBoardView: View {
    @EnvironmentObject private var store: CraftSideStore
    let tasks: [CraftTaskSummary]

    private var overdue: [CraftTaskSummary] {
        tasks.filter(\.isOverdue)
    }

    private var today: [CraftTaskSummary] {
        tasks.filter(\.isToday)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks")
                .font(.system(size: 17, weight: .bold, design: .rounded))

            if !overdue.isEmpty {
                TaskGroupView(title: "Scheduled for Previous Days", tasks: overdue)
            }

            if !today.isEmpty {
                TaskGroupView(title: "This Day", tasks: today)
            }
        }
        .padding(12)
        .background(CraftPalette.taskPanel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(CraftPalette.border, lineWidth: 1)
        )
    }
}

private struct TaskGroupView: View {
    let title: String
    let tasks: [CraftTaskSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }

            ForEach(tasks.prefix(8)) { task in
                TaskSummaryRow(task: task)
            }

            if tasks.count > 8 {
                Label("\(tasks.count - 8) more tasks", systemImage: "ellipsis.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
        }
    }
}

private struct TaskSummaryRow: View {
    @EnvironmentObject private var store: CraftSideStore
    let task: CraftTaskSummary

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                Task { await store.completeTask(id: task.id) }
            } label: {
                Image(systemName: "square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.isSaving)

            if !task.scheduleLabel.isEmpty {
                Text(task.scheduleLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            Text(task.title)
                .font(.system(size: 13.5))
                .lineLimit(2)

            if !task.location.isEmpty {
                Text(task.location.contains("daily note") ? "Daily Note" : task.location.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
        }
    }
}

private struct AttachmentBlockView: View {
    let block: CraftBlock

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(block.fileName ?? block.displayText.ifEmpty("Attachment"))
                    .font(.body.weight(.medium))
                if let url = block.url {
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    private var icon: String {
        switch block.type {
        case "image": "photo"
        case "video": "play.rectangle"
        case "drawing", "whiteboard": "scribble"
        default: "paperclip"
        }
    }
}

private struct LinkBlockView: View {
    let block: CraftBlock

    var body: some View {
        if let urlText = block.url, let url = URL(string: urlText) {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "link")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.displayText.ifEmpty(urlText))
                            .font(.body.weight(.medium))
                        Text(urlText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        } else {
            MarkdownText(block.displayText, textStyle: block.textStyle)
        }
    }
}

private struct CodeBlockView: View {
    let block: CraftBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = block.language {
                Text(language)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(block.rawCode ?? block.displayText)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct UnsupportedBlockView: View {
    let block: CraftBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Unsupported \(block.type) block")
                .font(.caption.bold())
            Text(block.raw.prettyPrinted)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(6)
                .textSelection(.enabled)
        }
    }
}

private struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.caption)
                .textSelection(.enabled)
            Spacer()
        }
        .foregroundStyle(.red)
        .padding(10)
        .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : self
    }
}
