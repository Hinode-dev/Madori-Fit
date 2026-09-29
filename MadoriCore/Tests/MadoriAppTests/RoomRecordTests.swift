import XCTest
import SwiftData
import MadoriCore
@testable import MadoriApp

final class RoomRecordTests: XCTestCase {
    func testRoundTripsRoomFurnitureAndConditions() throws {
        var draft = RoomDraft(name: "洋室")
        draft.addOpening(kind: .door)
        let room = draft.makeRoom()
        let record = RoomRecord(room: room)

        XCTAssertEqual(record.room, room)
        XCTAssertEqual(record.name, "洋室")
        XCTAssertTrue(record.furniture.isEmpty)
        XCTAssertEqual(record.conditions, LayoutConditions())

        let bed = try XCTUnwrap(FurniturePresets.preset(named: "シングルベッド"))
        record.furniture = [bed]
        record.conditions = LayoutConditions(minWalkway: 70, preferences: [.openCenter])
        XCTAssertEqual(record.furniture, [bed])
        XCTAssertEqual(record.conditions.minWalkway, 70)
        XCTAssertEqual(record.conditions.preferences, [.openCenter])
    }

    func testSettingRoomUpdatesName() {
        let record = RoomRecord(room: Room.rectangle(name: "A", width: 200, depth: 300))
        record.room = Room.rectangle(name: "B", width: 200, depth: 300)
        XCTAssertEqual(record.name, "B")
    }

    func testPersistsInMemoryContainer() throws {
        let container = try MadoriStorage.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(RoomRecord(room: Room.rectangle(name: "保存テスト", width: 270, depth: 360)))
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RoomRecord>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.room.name, "保存テスト")
    }
}
