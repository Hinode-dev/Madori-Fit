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
