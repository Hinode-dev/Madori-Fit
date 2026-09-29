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

final class SavedLayoutTests: XCTestCase {
    private func makeLayoutData() throws -> (Room, [PlacedFurniture]) {
        let room = Room.rectangle(name: "洋室", width: 270, depth: 360)
        let bed = try XCTUnwrap(FurniturePresets.preset(named: "シングルベッド"))
        let item = PlacedFurniture(furniture: bed, center: Point(x: 60, y: 262.5), quarterTurns: 2)
        return (room, [item])
    }

    func testRoundTripsSnapshot() throws {
        let (room, items) = try makeLayoutData()
        let pinned: Set<UUID> = [items[0].furniture.id]
        let saved = SavedLayout(name: "案1", room: room, conditions: LayoutConditions(minWalkway: 70),
                                items: items, pinned: pinned)
        XCTAssertEqual(saved.room, room)
        XCTAssertEqual(saved.items, items)
        XCTAssertEqual(saved.pinned, pinned)
        XCTAssertEqual(saved.conditions.minWalkway, 70)
        XCTAssertTrue(saved.layout.issues.isEmpty, "\(saved.layout.issues)")

        saved.items = []
        saved.pinned = []
        XCTAssertTrue(saved.items.isEmpty)
        XCTAssertTrue(saved.pinned.isEmpty)
    }

    func testDeletingRoomDeletesSavedLayouts() throws {
        let (room, items) = try makeLayoutData()
        let container = try MadoriStorage.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let record = RoomRecord(room: room)
        context.insert(record)
        let saved = SavedLayout(name: "案1", room: room, conditions: LayoutConditions(), items: items, pinned: [])
        context.insert(saved)
        saved.owner = record
        try context.save()

        XCTAssertEqual(record.sortedSavedLayouts.count, 1)
        context.delete(record)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<SavedLayout>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<RoomRecord>()).isEmpty)
    }

    func testSavedLayoutSurvivesRoomEdits() throws {
        let (room, items) = try makeLayoutData()
        let record = RoomRecord(room: room)
        let saved = SavedLayout(name: "案1", room: room, conditions: LayoutConditions(), items: items, pinned: [])
        saved.owner = record
        // 部屋の寸法を変えても、保存した案は保存時の部屋のまま。
        record.room = Room.rectangle(name: "洋室", width: 400, depth: 500)
        XCTAssertEqual(saved.room.bounds.width, 270)
    }
}

final class FurnitureUndoTests: XCTestCase {
    /// 取り消しは、同じ名前のうち最後に追加したものだけを消す。
    func testUndoRemovesOnlyTheLastOfThatName() throws {
        let record = RoomRecord(room: Room.rectangle(width: 270, depth: 360))
        let bed = try XCTUnwrap(FurniturePresets.preset(named: "シングルベッド"))
        var first = bed
        first.id = UUID()
        var second = bed
        second.id = UUID()
        let desk = try XCTUnwrap(FurniturePresets.preset(named: "デスク"))
        record.furniture = [first, desk, second]

        var list = record.furniture
        if let i = list.lastIndex(where: { $0.name == "シングルベッド" }) {
            list.remove(at: i)
            record.furniture = list
        }
        XCTAssertEqual(record.furniture.map(\.id), [first.id, desk.id])
    }
}
