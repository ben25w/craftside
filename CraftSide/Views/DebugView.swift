import SwiftUI

struct DebugView: View {
    @EnvironmentObject private var store: CraftSideStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DebugSection(title: "Selected Block") {
                    if let block = store.selectedBlock {
                        Text(block.raw.prettyPrinted)
                            .debugText()
                    } else {
                        Text("No block selected")
                            .foregroundStyle(.secondary)
                    }
                }

                DebugSection(title: "Daily Note Response") {
                    if let raw = store.selectedNote?.rawResponse {
                        Text(raw.prettyPrinted)
                            .debugText()
                    } else {
                        Text("No response loaded")
                            .foregroundStyle(.secondary)
                    }
                }

                DebugSection(title: "Last Write Response") {
                    if let raw = store.lastWriteDebug {
                        Text(raw.prettyPrinted)
                            .debugText()
                    } else {
                        Text("No write response yet")
                            .foregroundStyle(.secondary)
                    }
                }

                DebugSection(title: "Active Tasks Response") {
                    if let raw = store.activeTasks {
                        Text(raw.prettyPrinted)
                            .debugText()
                    } else {
                        Text("No task response loaded")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
        }
    }
}

private struct DebugSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension Text {
    func debugText() -> some View {
        self
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
