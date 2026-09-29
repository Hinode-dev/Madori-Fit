import XCTest
@testable import MadoriCore

final class GeometryAndRoomTests: XCTestCase {
    func testTouchingRectsDoNotIntersect() {
        let a = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
        let b = Rect(minX: 100, minY: 0, maxX: 200, maxY: 100)
        XCTAssertFalse(a.intersects(b))
        XCTAssertTrue(a.intersects(Rect(minX: 50, minY: 50, maxX: 150, maxY: 150)))
    }

    func testRectangleRoomContains() {
        let room = Room.rectangle(width: 300, depth: 400)
        XCTAssertTrue(room.isCounterClockwise)
        XCTAssertEqual(room.area, 120_000, accuracy: 0.001)
        XCTAssertTrue(room.contains(Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)))
        XCTAssertFalse(room.contains(Rect(minX: 250, minY: 0, maxX: 350, maxY: 100)))
    }

    func testLShapedRoomContains() {
        let room = Room(corners: [
            Point(x: 0, y: 0), Point(x: 400, y: 0), Point(x: 400, y: 200),
            Point(x: 200, y: 200), Point(x: 200, y: 400), Point(x: 0, y: 400)
        ])
        XCTAssertTrue(room.contains(Rect(minX: 20, minY: 300, maxX: 120, maxY: 380)))
        XCTAssertFalse(room.contains(Rect(minX: 250, minY: 250, maxX: 350, maxY: 350)))
        // 凹角をまたぐ長方形
        XCTAssertFalse(room.contains(Rect(minX: 150, minY: 150, maxX: 250, maxY: 250)))
    }

    func testDoorZone() {
        let door = Opening(kind: .door, wallIndex: 0, offset: 50, width: 80)
        let room = Room.rectangle(width: 300, depth: 400, openings: [door])
        let zone = room.zone(for: door)
        XCTAssertEqual(zone.minX, 50, accuracy: 0.001)
        XCTAssertEqual(zone.maxX, 130, accuracy: 0.001)
        XCTAssertEqual(zone.minY, 0, accuracy: 0.001)
        XCTAssertEqual(zone.maxY, 80, accuracy: 0.001)
    }

    func testWindowZoneOnTopWall() {
        // 壁 2 は (300,400) から (0,400) へ進む。内側は -y 方向。
        let window = Opening(kind: .window, wallIndex: 2, offset: 50, width: 100)
        let room = Room.rectangle(width: 300, depth: 400, openings: [window])
        let zone = room.zone(for: window)
        XCTAssertEqual(zone.minX, 150, accuracy: 0.001)
        XCTAssertEqual(zone.maxX, 250, accuracy: 0.001)
        XCTAssertEqual(zone.minY, 380, accuracy: 0.001)
        XCTAssertEqual(zone.maxY, 400, accuracy: 0.001)
    }

    func testPlacedFurnitureGeometry() {
        let bed = Furniture(name: "bed", category: .bed, width: 100, depth: 200, height: 40, frontClearance: 60)
        let p0 = PlacedFurniture(furniture: bed, center: Point(x: 50, y: 100), quarterTurns: 0)
        XCTAssertEqual(p0.footprint, Rect(minX: 0, minY: 0, maxX: 100, maxY: 200))
        XCTAssertEqual(p0.clearanceZone, Rect(minX: 0, minY: 200, maxX: 100, maxY: 260))

        let p1 = PlacedFurniture(furniture: bed, center: Point(x: 100, y: 50), quarterTurns: 1)
        XCTAssertEqual(p1.footprint, Rect(minX: 0, minY: 0, maxX: 200, maxY: 100))
        XCTAssertEqual(p1.clearanceZone, Rect(minX: -60, minY: 0, maxX: 0, maxY: 100))
    }
}
