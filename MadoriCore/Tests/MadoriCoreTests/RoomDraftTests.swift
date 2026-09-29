import XCTest
@testable import MadoriCore

final class RoomDraftTests: XCTestCase {
    private func draft(_ openings: [OpeningDraft]) -> RoomDraft {
        RoomDraft(name: "洋室", width: 300, depth: 400, openings: openings)
    }

    func testOffsetsAreMeasuredFromLeftOrBottom() {
        let north = OpeningDraft(kind: .window, side: .north, offset: 50, width: 100)
        let east = OpeningDraft(kind: .window, side: .east, offset: 30, width: 80)
        let west = OpeningDraft(kind: .window, side: .west, offset: 30, width: 80)
        let south = OpeningDraft(kind: .door, side: .south, offset: 20, width: 80)
        let room = draft([north, east, west, south]).makeRoom()

        let zones = room.openings.map { room.zone(for: $0) }
        // 上の壁: x 50〜150
        XCTAssertEqual(zones[0].minX, 50, accuracy: 0.001)
        XCTAssertEqual(zones[0].maxX, 150, accuracy: 0.001)
        // 右の壁: y 30〜110
        XCTAssertEqual(zones[1].minY, 30, accuracy: 0.001)
        XCTAssertEqual(zones[1].maxY, 110, accuracy: 0.001)
        // 左の壁: y 30〜110
        XCTAssertEqual(zones[2].minY, 30, accuracy: 0.001)
        XCTAssertEqual(zones[2].maxY, 110, accuracy: 0.001)
        // 下の壁: x 20〜100
        XCTAssertEqual(zones[3].minX, 20, accuracy: 0.001)
        XCTAssertEqual(zones[3].maxX, 100, accuracy: 0.001)
    }

    func testRoundTripThroughRoom() {
        let original = draft([
            OpeningDraft(kind: .door, side: .south, offset: 20, width: 80),
            OpeningDraft(kind: .window, side: .north, offset: 50, width: 100),
            OpeningDraft(kind: .window, side: .west, offset: 30, width: 80)
        ])
        let restored = RoomDraft(room: original.makeRoom())
        XCTAssertEqual(restored, original)
    }

    func testNonRectangularRoomCannotBeEdited() {
        let l = Room(corners: [
            Point(x: 0, y: 0), Point(x: 400, y: 0), Point(x: 400, y: 200),
            Point(x: 200, y: 200), Point(x: 200, y: 400), Point(x: 0, y: 400)
        ])
        XCTAssertNil(RoomDraft(room: l))
    }

    func testAreaInTatami() {
        XCTAssertEqual(RoomDraft(width: 270, depth: 360).areaInTatami, 6.0, accuracy: 0.001)
    }

    func testValidation() {
        XCTAssertTrue(draft([]).issues.isEmpty)
        XCTAssertEqual(RoomDraft(width: 50, depth: 400).issues, [.sizeOutOfRange])

        let outside = OpeningDraft(kind: .door, side: .south, offset: 250, width: 80)
        XCTAssertEqual(draft([outside]).issues, [.openingOutOfWall(outside.id)])

        let narrow = OpeningDraft(kind: .door, side: .south, offset: 0, width: 10)
        XCTAssertEqual(draft([narrow]).issues, [.openingTooNarrow(narrow.id)])

        let a = OpeningDraft(kind: .door, side: .south, offset: 20, width: 80)
        let b = OpeningDraft(kind: .window, side: .south, offset: 60, width: 80)
        XCTAssertEqual(draft([a, b]).issues, [.openingsOverlap(b.id)])

        // 別の壁なら重ならない。接しているだけも重ならない。
        let c = OpeningDraft(kind: .window, side: .north, offset: 60, width: 80)
        let d = OpeningDraft(kind: .window, side: .south, offset: 100, width: 80)
        XCTAssertTrue(draft([a, c, d]).issues.isEmpty)
    }

    func testAddOpeningDefaultsAreValid() {
        var d = RoomDraft(width: 270, depth: 360)
        d.addOpening(kind: .door)
        d.addOpening(kind: .window)
        XCTAssertTrue(d.issues.isEmpty)
        XCTAssertTrue(d.hasDoor)

        var small = RoomDraft(width: 120, depth: 120)
        small.addOpening(kind: .door)
        small.addOpening(kind: .window)
        XCTAssertTrue(small.issues.isEmpty, "\(small.issues)")
    }

    func testMakeRoomKeepsIdentity() {
        let d = draft([])
        XCTAssertEqual(d.makeRoom().id, d.id)
        XCTAssertEqual(d.makeRoom().name, "洋室")
    }
}
