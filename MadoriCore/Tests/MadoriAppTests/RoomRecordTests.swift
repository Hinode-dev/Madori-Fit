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

final class DeliveryRouteTests: XCTestCase {
    func testRouteIncludesTheRoomsOwnDoors() {
        var draft = RoomDraft(name: "洋室")
        draft.addOpening(kind: .door)
        draft.addOpening(kind: .window)
        let record = RoomRecord(room: draft.makeRoom())
        record.passages = [.doorway(name: "玄関", width: 75, height: 195)]

        let route = record.deliveryRoute
        XCTAssertEqual(route.count, 2)                       // 玄関 + この部屋のドア（窓は含まない）
        XCTAssertEqual(route[0].name, "玄関")
        XCTAssertTrue(route[1].name.hasPrefix("この部屋のドア"))
        XCTAssertEqual(route[1].openingWidth, 80)
    }

    func testPassagesRoundTrip() {
        let record = RoomRecord(room: Room.rectangle(width: 270, depth: 360))
        XCTAssertTrue(record.passages.isEmpty)
        let elevator = Passage.elevator(name: "EV", doorWidth: 80, doorHeight: 200,
                                        cabinWidth: 100, cabinDepth: 130, cabinHeight: 220)
        record.passages = [elevator]
        XCTAssertEqual(record.passages, [elevator])
    }
}

final class RoomRenameTests: XCTestCase {
    func testRenamingUpdatesBothTheRoomAndTheListName() {
        let record = RoomRecord(room: Room.rectangle(name: "", width: 270, depth: 360))
        XCTAssertEqual(record.name, "")

        var room = record.room
        room.name = "寝室"
        record.room = room
        XCTAssertEqual(record.name, "寝室")
        XCTAssertEqual(record.room.name, "寝室")
    }
}

final class StorageOpenTests: XCTestCase {
    private struct Boom: LocalizedError {
        var errorDescription: String? { "壊れています" }
    }

    func testFailureIsReportedNotThrown() {
        let result = MadoriStorage.open { throw Boom() }
        guard case .failed(let message) = result else { return XCTFail("失敗になるはず") }
        XCTAssertEqual(message, "壊れています")
    }

    func testTemporaryStorageOpens() {
        guard case .ready = MadoriStorage.openTemporary() else { return XCTFail("開けるはず") }
    }

    func testSampleCanBeSavedIntoARecord() throws {
        let sample = SampleData.make()
        let record = RoomRecord(room: sample.room)
        record.furniture = sample.furniture
        record.passages = sample.passages
        XCTAssertEqual(record.name, "サンプル: 6畳の洋室")
        XCTAssertEqual(record.furniture.count, 3)
        XCTAssertEqual(record.deliveryRoute.count, 4)     // 通り道 3 + この部屋のドア 1
    }
}
