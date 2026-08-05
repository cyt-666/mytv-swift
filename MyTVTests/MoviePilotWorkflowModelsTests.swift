import XCTest
@testable import MyTV

final class MoviePilotWorkflowModelsTests: XCTestCase {
    func testDecodesWorkflowListWithFlexibleValues() throws {
        let text = """
        [
          {
            "id": "12",
            "name": "整理媒体库",
            "description": "扫描并整理",
            "trigger_type": "手动触发",
            "state": "成功",
            "run_count": "3",
            "timer": null,
            "event_type": null,
            "add_time": "2026-07-27 10:00:00",
            "last_time": "2026-07-27 11:00:00",
            "current_action": 2
          }
        ]
        """

        let workflows = try MoviePilotToolTextDecoder.decode(
            [MoviePilotWorkflow].self,
            from: text
        )

        XCTAssertEqual(workflows.count, 1)
        XCTAssertEqual(workflows[0].id, 12)
        XCTAssertEqual(workflows[0].displayName, "整理媒体库")
        XCTAssertEqual(workflows[0].displayTriggerType, "手动触发")
        XCTAssertEqual(workflows[0].displayState, "成功")
        XCTAssertEqual(workflows[0].runCount, 3)
        XCTAssertEqual(workflows[0].currentAction, "2")
    }

    func testWorkflowRunParserRejectsPlainTextFailure() {
        XCTAssertThrowsError(
            try MoviePilotWorkflowResultParser.successMessage(
                from: "执行工作流失败：整理媒体库"
            )
        )
    }

    func testWorkflowRunParserAcceptsExplicitSuccess() throws {
        let result = try MoviePilotWorkflowResultParser.successMessage(
            from: "工作流执行成功：整理媒体库 (ID: 12)"
        )
        XCTAssertEqual(result, "工作流执行成功：整理媒体库 (ID: 12)")
    }
}
