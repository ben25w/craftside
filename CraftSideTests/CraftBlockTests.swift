import XCTest

final class CraftBlockTests: XCTestCase {
    func testNestedDailyNoteResponseParsesChildren() {
        let json = JSONValue(any: [
            "type": "page",
            "id": "root",
            "title": ["markdown": "Today"],
            "content": [
                [
                    "type": "text",
                    "id": "a",
                    "markdown": "Hello **Craft**",
                    "textStyle": "body",
                    "listStyle": "none"
                ],
                [
                    "type": "text",
                    "id": "b",
                    "markdown": "Buy milk",
                    "listStyle": "task",
                    "taskInfo": ["state": "todo"]
                ]
            ]
        ])

        let block = CraftBlock(json: json)

        XCTAssertEqual(block.id, "root")
        XCTAssertEqual(block.title, "Today")
        XCTAssertEqual(block.children.count, 2)
        XCTAssertEqual(block.children[1].listStyle, "task")
        XCTAssertEqual(block.children[1].taskState, "todo")
        XCTAssertEqual(block.allBlocksDepthFirst.map(\.id), ["root", "a", "b"])
    }

    func testUnsupportedBlockKeepsRawDebugPayload() {
        let json = JSONValue(any: [
            "type": "mystery",
            "id": "unknown",
            "custom": ["value": true]
        ])

        let block = CraftBlock(json: json)

        XCTAssertFalse(block.isRenderable)
        XCTAssertTrue(block.raw.prettyPrinted.contains("\"custom\""))
        XCTAssertTrue(block.raw.prettyPrinted.contains("\"value\""))
    }
}
