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

    func testMCPTaskListParsesTaskIDsAndSchedules() {
        let json = JSONValue(any: [
            "result": [
                "content": [
                    [
                        "type": "text",
                        "text": """
                        Tasks (active): 2 result(s)

                        [ ] <ABC-123> - [ ] First task
                          (schedule: 2026-05-14)
                          in: daily note 2026-05-14

                        [ ] <DEF-456> - [ ] Old task
                          (schedule: 2026-05-08)
                          in: inbox
                        """
                    ]
                ]
            ]
        ])

        let tasks = CraftTaskSummary.parse(from: json)

        XCTAssertEqual(tasks.count, 2)
        XCTAssertEqual(tasks[0].id, "ABC-123")
        XCTAssertEqual(tasks[0].title, "First task")
        XCTAssertEqual(tasks[0].location, "daily note 2026-05-14")
        XCTAssertEqual(DateFormatter.craftDate.string(from: tasks[1].schedule!), "2026-05-08")
    }
}
