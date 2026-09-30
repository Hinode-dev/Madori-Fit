import XCTest
@testable import MadoriCore

final class SampleDataTests: XCTestCase {
    func testSampleRoomIsValidAndComplete() throws {
        let sample = SampleData.make()
        XCTAssertEqual(sample.furniture.count, 3)
        XCTAssertEqual(Set(sample.furniture.map(\.id)).count, 3)
        XCTAssertEqual(sample.passages.count, 3)
        XCTAssertEqual(sample.room.openings.count, 2)
        let draft = try XCTUnwrap(RoomDraft(room: sample.room))
        XCTAssertTrue(draft.issues.isEmpty, "\(draft.issues)")
        XCTAssertTrue(draft.hasDoor)
    }

    func testSampleProducesLayoutsWithoutProblems() throws {
        let sample = SampleData.make()
        let layouts = LayoutGenerator(room: sample.room, furniture: sample.furniture).generate(count: 3)
        XCTAssertFalse(layouts.isEmpty)
        XCTAssertTrue(layouts[0].issues.isEmpty, "\(layouts[0].issues)")
    }

    func testEachCallGivesNewIDs() {
        XCTAssertNotEqual(SampleData.make().room.id, SampleData.make().room.id)
    }

    func testSampleFurnitureIsCheckedAgainstTheRoute() {
        let sample = SampleData.make()
        for f in sample.furniture {
            let results = DeliveryChecker.check(f, route: sample.passages)
            XCTAssertEqual(results.count, 3)
        }
    }
}

final class EditHistoryTests: XCTestCase {
    func testUndoAndRedoWalkThroughStates() {
        var history = EditHistory<Int>()
        var value = 0
        // 0 → 1 → 2 と変更する。
        history.record(value); value = 1
        history.record(value); value = 2
        XCTAssertTrue(history.canUndo)
        XCTAssertFalse(history.canRedo)

        value = history.undo(current: value) ?? value
        XCTAssertEqual(value, 1)
        value = history.undo(current: value) ?? value
        XCTAssertEqual(value, 0)
        XCTAssertNil(history.undo(current: value))

        value = history.redo(current: value) ?? value
        XCTAssertEqual(value, 1)
        value = history.redo(current: value) ?? value
        XCTAssertEqual(value, 2)
        XCTAssertNil(history.redo(current: value))
    }

    func testNewChangeClearsRedo() {
        var history = EditHistory<String>()
        history.record("a")
        let back = history.undo(current: "b")
        XCTAssertEqual(back, "a")
        XCTAssertTrue(history.canRedo)
        history.record("a")
        XCTAssertFalse(history.canRedo)
    }

    func testLimitDropsTheOldest() {
        var history = EditHistory<Int>(limit: 3)
        for i in 0..<10 { history.record(i) }
        XCTAssertEqual(history.undoStack, [7, 8, 9])
    }
}
