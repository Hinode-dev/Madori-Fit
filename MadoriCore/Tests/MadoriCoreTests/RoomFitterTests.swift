import XCTest
@testable import MadoriCore

final class RoomFitterTests: XCTestCase {
    /// 400×300cm の部屋（左下が原点）を、angle だけ回して offset だけ動かしたスキャン結果。
    private func scan(rotatedBy angle: Double, extra: [ScannedSurface] = []) -> ScannedRoom {
        func place(_ kind: ScannedSurface.Kind, _ x: Double, _ y: Double, _ a: Double,
                   _ width: Double, bottom: Double = 0) -> ScannedSurface {
            let p = Point(x: x * cos(angle) - y * sin(angle) + 1000,
                          y: x * sin(angle) + y * cos(angle) - 500)
            return ScannedSurface(kind: kind, center: p, angle: a + angle, width: width, bottomHeight: bottom)
        }
        let half = Double.pi / 2
        var surfaces = [
            place(.wall, 200, 0, 0, 400), place(.wall, 400, 150, half, 300),
            place(.wall, 200, 300, 0, 400), place(.wall, 0, 150, half, 300),
            place(.door, 100, 0, 0, 90),
            place(.window, 200, 300, 0, 150, bottom: 100)
        ]
        surfaces += extra
        return ScannedRoom(surfaces: surfaces, ceilingHeight: 240)
    }

    func testFitsRotatedRoom() throws {
        let fit = try XCTUnwrap(RoomFitter.fit(scan(rotatedBy: 20 * .pi / 180)))
        let d = fit.draft
        XCTAssertEqual(d.width, 400, accuracy: 1)
        XCTAssertEqual(d.depth, 300, accuracy: 1)
        XCTAssertEqual(d.ceilingHeight, 240)
        XCTAssertTrue(fit.warnings.isEmpty, "\(fit.warnings)")
        XCTAssertTrue(d.issues.isEmpty, "\(d.issues)")

        let door = try XCTUnwrap(d.openings.first { $0.kind == .door })
        XCTAssertEqual(door.side, .south)
        XCTAssertEqual(door.offset, 55, accuracy: 1)   // 中心 100 − 幅 90 の半分
        XCTAssertEqual(door.width, 90, accuracy: 1)

        let window = try XCTUnwrap(d.openings.first { $0.kind == .window })
        XCTAssertEqual(window.side, .north)
        XCTAssertEqual(window.offset, 125, accuracy: 1)  // 中心 200 − 幅 150 の半分
        XCTAssertEqual(window.sillHeight, 100, accuracy: 1)
    }

    func testUnrotatedRoomIsFitAsIs() throws {
        let fit = try XCTUnwrap(RoomFitter.fit(scan(rotatedBy: 0)))
        XCTAssertEqual(fit.draft.width, 400, accuracy: 1)
        XCTAssertEqual(fit.draft.depth, 300, accuracy: 1)
    }

    func testOpeningWithoutDoorWarns() throws {
        var s = scan(rotatedBy: 0)
        s.surfaces.removeAll { $0.kind == .door }
        let fit = try XCTUnwrap(RoomFitter.fit(s))
        XCTAssertEqual(fit.warnings.count, 1)
    }

    func testPassageCountsAsDoor() throws {
        var s = scan(rotatedBy: 0)
        s.surfaces.removeAll { $0.kind == .door }
        s.surfaces.append(ScannedSurface(kind: .opening, center: Point(x: 1400, y: -400), angle: .pi / 2, width: 90))
        let fit = try XCTUnwrap(RoomFitter.fit(s))
        XCTAssertTrue(fit.draft.hasDoor)
        XCTAssertEqual(fit.draft.openings.last?.side, .east)
    }

    func testInteriorWallWarnsAboutShape() throws {
        // 部屋の中ほどに長い壁がある（L 字や仕切りの可能性）。
        let partition = ScannedSurface(kind: .wall, center: Point(x: 200 + 1000, y: 150 - 500),
                                       angle: .pi / 2, width: 200)
        let fit = try XCTUnwrap(RoomFitter.fit(scan(rotatedBy: 0, extra: [partition])))
        XCTAssertTrue(fit.warnings.contains { $0.contains("四角ではない") })
    }

    func testNoWallsReturnsNil() {
        XCTAssertNil(RoomFitter.fit(ScannedRoom(surfaces: [])))
    }
}

final class RoomFitterCleanupTests: XCTestCase {
    private func walls() -> [ScannedSurface] {
        let half = Double.pi / 2
        return [
            ScannedSurface(kind: .wall, center: Point(x: 200, y: 0), angle: 0, width: 400),
            ScannedSurface(kind: .wall, center: Point(x: 400, y: 150), angle: half, width: 300),
            ScannedSurface(kind: .wall, center: Point(x: 200, y: 300), angle: 0, width: 400),
            ScannedSurface(kind: .wall, center: Point(x: 0, y: 150), angle: half, width: 300)
        ]
    }

    func testDoorAndOpeningAtSamePlaceAreMerged() throws {
        var surfaces = walls()
        surfaces.append(ScannedSurface(kind: .door, center: Point(x: 100, y: 0), angle: 0, width: 90))
        surfaces.append(ScannedSurface(kind: .opening, center: Point(x: 105, y: 0), angle: 0, width: 95))
        let fit = try XCTUnwrap(RoomFitter.fit(ScannedRoom(surfaces: surfaces)))
        XCTAssertEqual(fit.draft.openings.count, 1)
        XCTAssertEqual(fit.draft.openings[0].kind, .door)
        XCTAssertTrue(fit.warnings.contains { $0.contains("まとめました") })
        XCTAssertTrue(fit.draft.issues.isEmpty, "\(fit.draft.issues)")
    }

    func testSeparateOpeningsAreKept() throws {
        var surfaces = walls()
        surfaces.append(ScannedSurface(kind: .door, center: Point(x: 60, y: 0), angle: 0, width: 80))
        surfaces.append(ScannedSurface(kind: .window, center: Point(x: 250, y: 300), angle: 0, width: 150,
                                       bottomHeight: 90))
        let fit = try XCTUnwrap(RoomFitter.fit(ScannedRoom(surfaces: surfaces)))
        XCTAssertEqual(fit.draft.openings.count, 2)
        XCTAssertFalse(fit.warnings.contains { $0.contains("まとめました") })
    }

    func testTinyDetectionsAreIgnored() throws {
        var surfaces = walls()
        surfaces.append(ScannedSurface(kind: .door, center: Point(x: 100, y: 0), angle: 0, width: 30))
        surfaces.append(ScannedSurface(kind: .window, center: Point(x: 250, y: 300), angle: 0, width: 20))
        let fit = try XCTUnwrap(RoomFitter.fit(ScannedRoom(surfaces: surfaces)))
        XCTAssertTrue(fit.draft.openings.isEmpty)
    }
}

final class RoomOpeningEditTests: XCTestCase {
    func testRemoveAndChangeKind() {
        let door = Opening(kind: .door, wallIndex: 0, offset: 20, width: 80)
        let window = Opening(kind: .window, wallIndex: 2, offset: 60, width: 150)
        var room = Room.rectangle(width: 300, depth: 400, openings: [door, window])

        room.setKind(.window, ofOpening: door.id)
        XCTAssertEqual(room.openings[0].kind, .window)
        room.setKind(.door, ofOpening: UUID())                       // 存在しない ID は無視
        XCTAssertEqual(room.openings.count, 2)

        room.removeOpening(id: door.id)
        XCTAssertEqual(room.openings.map(\.id), [window.id])
    }
}
