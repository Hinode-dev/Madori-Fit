import XCTest
@testable import MadoriCore

final class DeliveryCheckTests: XCTestCase {
    private func item(_ name: String, _ w: Double, _ d: Double, _ h: Double) -> Furniture {
        Furniture(name: name, category: .other, width: w, depth: d, height: h)
    }

    func testBedPassesADoorLyingFlat() {
        // 97 × 195 × 45 は、45 と 97 の断面で、80 × 200 の開口に通る。
        let bed = item("ベッド", 97, 195, 45)
        let r = DeliveryChecker.check(bed, through: .doorway(name: "玄関", width: 80, height: 200))
        XCTAssertEqual(r.status, .ok)
        XCTAssertEqual(r.margin, 35, accuracy: 0.001)
    }

    func testBigSofaIsBlockedByANarrowDoor() {
        let sofa = item("ソファ", 200, 90, 80)
        let r = DeliveryChecker.check(sofa, through: .doorway(name: "室内ドア", width: 70, height: 190))
        XCTAssertEqual(r.status, .blocked)
        XCTAssertLessThan(r.margin, 0)
    }

    func testTightWhenMarginIsSmall() {
        // 55 × 90 の断面が、58 × 195 の開口に、3cm の余裕で通る。
        let wardrobe = item("ワードローブ", 90, 55, 180)
        let r = DeliveryChecker.check(wardrobe, through: .doorway(name: "玄関", width: 58, height: 195))
        XCTAssertEqual(r.status, .tight)
        XCTAssertEqual(r.margin, 3, accuracy: 0.001)
    }

    func testFridgeThroughANarrowOpening() {
        let fridge = item("冷蔵庫", 60, 65, 170)
        XCTAssertEqual(DeliveryChecker.check(fridge, through: .doorway(name: "a", width: 70, height: 200)).status, .ok)
        XCTAssertEqual(DeliveryChecker.check(fridge, through: .doorway(name: "b", width: 62, height: 200)).status, .tight)
        XCTAssertEqual(DeliveryChecker.check(fridge, through: .doorway(name: "c", width: 58, height: 200)).status, .blocked)
    }

    func testElevatorNeedsBothDoorAndCabin() {
        let bed = item("ベッド", 97, 195, 45)
        // かご (100 × 130 × 220): 寸法を短い順に並べると (45, 97, 195) に対し (100, 130, 220) → 余り 55, 33, 25。
        let ok = Passage.elevator(name: "EV", doorWidth: 80, doorHeight: 200,
                                  cabinWidth: 100, cabinDepth: 130, cabinHeight: 220)
        let r = DeliveryChecker.check(bed, through: ok)
        XCTAssertEqual(r.status, .ok)
        XCTAssertEqual(r.margin, 25, accuracy: 0.001)

        // かごが短いと、扉を通れても入らない。
        let small = Passage.elevator(name: "EV", doorWidth: 80, doorHeight: 200,
                                     cabinWidth: 100, cabinDepth: 130, cabinHeight: 180)
        XCTAssertEqual(DeliveryChecker.check(bed, through: small).status, .blocked)
    }

    func testCornerTurnForSmallAndLongItems() {
        let corner = Passage.corner(name: "廊下", width1: 90, width2: 90, ceiling: 240)
        let small = item("箱", 60, 60, 60)
        XCTAssertEqual(DeliveryChecker.check(small, through: corner).status, .ok)

        // 厚み 90 の家具は、幅 90 の廊下を曲がれない。
        let sofa = item("ソファ", 200, 90, 80)
        XCTAssertEqual(DeliveryChecker.check(sofa, through: corner).status, .blocked)
    }

    func testThinLongItemTurnsAWideCorner() {
        // 厚み 5、長さ 200 の板は、幅 90 の廊下を曲がれる（棒の理論値は約 255 → 少し厳しめでも 200 は通る）。
        let board = item("板", 200, 5, 100)
        let r = DeliveryChecker.check(board, through: .corner(name: "廊下", width1: 90, width2: 90, ceiling: 240))
        XCTAssertEqual(r.status, .ok)
        XCTAssertGreaterThan(DeliveryChecker.maxTurnableLength(thickness: 5, w1: 90, w2: 90), 200)
        XCTAssertLessThan(DeliveryChecker.maxTurnableLength(thickness: 5, w1: 90, w2: 90), 90 * 2 * 2.9)
    }

    func testMaxTurnableLengthOfAThinRod() {
        // 太さ 0 の棒は、幅 w の廊下で 2√2·w。
        XCTAssertEqual(DeliveryChecker.maxTurnableLength(thickness: 0, w1: 100, w2: 100), 200 * 2.0.squareRoot(),
                       accuracy: 0.5)
        XCTAssertEqual(DeliveryChecker.maxTurnableLength(thickness: 100, w1: 100, w2: 100), -Double.infinity)
    }

    func testWorstPicksTheSmallestMargin() throws {
        let bed = item("ベッド", 97, 195, 45)
        let route: [Passage] = [
            .doorway(name: "玄関", width: 80, height: 200),
            .doorway(name: "細いドア", width: 60, height: 200),
            .doorway(name: "室内", width: 75, height: 200)
        ]
        let results = DeliveryChecker.check(bed, route: route)
        XCTAssertEqual(results.count, 3)
        let worst = try XCTUnwrap(DeliveryChecker.worst(results))
        XCTAssertEqual(worst.passageName, "細いドア")
        XCTAssertNil(DeliveryChecker.worst([]))
    }

    func testPassageRoundTripsThroughJSON() throws {
        let passage = Passage.elevator(name: "EV", doorWidth: 80, doorHeight: 200,
                                       cabinWidth: 100, cabinDepth: 130, cabinHeight: 220)
        let data = try JSONEncoder().encode([passage])
        XCTAssertEqual(try JSONDecoder().decode([Passage].self, from: data), [passage])
    }
}
