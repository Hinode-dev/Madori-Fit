import XCTest
@testable import MadoriCore

final class LayoutGeneratorTests: XCTestCase {
    /// 6 畳ほどの部屋。ドアは下の壁、窓は上の壁。
    private func makeRoom() -> Room {
        Room.rectangle(width: 270, depth: 360, openings: [
            Opening(kind: .door, wallIndex: 0, offset: 20, width: 80),
            Opening(kind: .window, wallIndex: 2, offset: 60, width: 150)
        ])
    }

    private func makeFurniture() -> [Furniture] {
        ["シングルベッド", "デスク", "ワードローブ"].compactMap { FurniturePresets.preset(named: $0) }
    }

    func testGeneratesValidLayouts() {
        let room = makeRoom()
        let evaluator = LayoutEvaluator(room: room, conditions: LayoutConditions())
        let layouts = LayoutGenerator(room: room, furniture: makeFurniture()).generate(count: 3)

        XCTAssertFalse(layouts.isEmpty)
        XCTAssertTrue(layouts[0].issues.isEmpty, "最良の案には問題がないはず: \(layouts[0].issues)")

        for layout in layouts {
            for (i, item) in layout.items.enumerated() {
                var others = layout.items
                others.remove(at: i)
                XCTAssertTrue(evaluator.isPlacementValid(item, others: others), "\(item.furniture.name) が不正")
            }
        }
    }

    func testSameSeedGivesSameResult() {
        let generator = LayoutGenerator(room: makeRoom(), furniture: makeFurniture())
        let a = generator.generate(count: 3, seed: 42)
        let b = generator.generate(count: 3, seed: 42)
        XCTAssertEqual(a.map { $0.items.map(\.center) }, b.map { $0.items.map(\.center) })
    }

    func testLayoutsDiffer() {
        let generator = LayoutGenerator(room: makeRoom(), furniture: makeFurniture())
        let layouts = generator.generate(count: 3, minDifference: 60)
        for i in layouts.indices {
            for j in layouts.indices where i < j {
                XCTAssertGreaterThanOrEqual(LayoutGenerator.difference(layouts[i], layouts[j]), 60)
            }
        }
    }

    func testTooLargeFurnitureIsReportedAsUnplaced() {
        let room = Room.rectangle(width: 150, depth: 150)
        let huge = Furniture(name: "巨大ベッド", category: .bed, width: 200, depth: 300, height: 40)
        let layouts = LayoutGenerator(room: room, furniture: [huge]).generate(count: 1)
        XCTAssertEqual(layouts.first?.issues.first?.kind, .unplaced)
    }

    func testTallFurnitureAvoidsWindow() {
        let room = makeRoom()
        let windowZone = room.zone(for: room.openings[1])
        let layouts = LayoutGenerator(room: room, furniture: makeFurniture()).generate(count: 3)
        for layout in layouts {
            for item in layout.items where item.furniture.height > 90 {
                XCTAssertFalse(item.footprint.intersects(windowZone))
            }
        }
    }

    func testDeskNearWindowPreference() {
        let room = makeRoom()
        let windowCenter = room.zone(for: room.openings[1]).center
        let desk = [FurniturePresets.preset(named: "デスク")].compactMap { $0 }
        let layout = LayoutGenerator(
            room: room, furniture: desk,
            conditions: LayoutConditions(preferences: [.deskNearWindow])
        ).generate(count: 1).first
        let distance = layout?.items.first?.center.distance(to: windowCenter) ?? .infinity
        XCTAssertLessThan(distance, 200)
    }

    func testWalkwayBlockedByFurnitureIsDetected() {
        // 部屋を横断する家具の奥に別の家具がある配置。奥へは通路幅を保って回り込めない。
        let room = Room.rectangle(width: 200, depth: 200, openings: [
            Opening(kind: .door, wallIndex: 0, offset: 10, width: 80)
        ])
        let wall = Furniture(name: "壁", category: .storage, width: 200, depth: 40, height: 180)
        let barrier = PlacedFurniture(furniture: wall, center: Point(x: 100, y: 120), quarterTurns: 0)
        let behind = Furniture(name: "奥の棚", category: .storage, width: 60, depth: 30, height: 100)
        let target = PlacedFurniture(furniture: behind, center: Point(x: 100, y: 175), quarterTurns: 0)
        let evaluator = LayoutEvaluator(room: room, conditions: LayoutConditions())
        let blocked = evaluator.inaccessibleItems([barrier, target])
        XCTAssertTrue(blocked.contains(where: { $0.furniture.name == "奥の棚" }))
    }
}

final class FixedPlacementTests: XCTestCase {
    private func room() -> Room {
        Room.rectangle(width: 270, depth: 360, openings: [
            Opening(kind: .door, wallIndex: 0, offset: 20, width: 80)
        ])
    }

    func testFixedFurnitureStaysPutInEveryLayout() throws {
        let furniture = ["シングルベッド", "デスク", "ワードローブ"].compactMap { FurniturePresets.preset(named: $0) }
        let bed = furniture[0]
        // 上の壁に、頭側を付けて置く。
        let fixedBed = PlacedFurniture(furniture: bed, center: Point(x: 60, y: 360 - 195 / 2), quarterTurns: 2)
        let layouts = LayoutGenerator(room: room(), furniture: furniture)
            .generate(count: 3, fixed: [fixedBed])

        XCTAssertFalse(layouts.isEmpty)
        for layout in layouts {
            let placedBed = try XCTUnwrap(layout.items.first { $0.furniture.id == bed.id })
            XCTAssertEqual(placedBed, fixedBed)
            XCTAssertEqual(layout.items.filter { $0.furniture.id == bed.id }.count, 1)
        }
        XCTAssertTrue(layouts[0].issues.isEmpty, "\(layouts[0].issues)")
    }

    func testOtherFurnitureAvoidsFixedOne() throws {
        let furniture = ["シングルベッド", "デスク"].compactMap { FurniturePresets.preset(named: $0) }
        let fixedBed = PlacedFurniture(furniture: furniture[0], center: Point(x: 60, y: 260), quarterTurns: 2)
        let layouts = LayoutGenerator(room: room(), furniture: furniture).generate(count: 3, fixed: [fixedBed])
        for layout in layouts {
            let desk = try XCTUnwrap(layout.items.first { $0.furniture.id == furniture[1].id })
            XCTAssertFalse(desk.footprint.intersects(fixedBed.footprint))
        }
    }

    func testInvalidFixedPlacementIsReported() {
        let bed = FurniturePresets.preset(named: "シングルベッド")!
        // 部屋の外にはみ出した位置。
        let outside = PlacedFurniture(furniture: bed, center: Point(x: 0, y: 0), quarterTurns: 0)
        let evaluator = LayoutEvaluator(room: room(), conditions: LayoutConditions())
        let layout = evaluator.evaluate(items: [outside], unplaced: [])
        XCTAssertTrue(layout.issues.contains { $0.kind == .invalid })
    }
}

final class LayoutEditingTests: XCTestCase {
    private let room = Room.rectangle(width: 300, depth: 400)
    private let bed = Furniture(name: "bed", category: .bed, width: 100, depth: 200, height: 40)

    func testSnapsToNearbyWall() {
        // 左の壁から 10cm 離れている（幅 100 の中心 60 → 左端 10）。
        let p = PlacedFurniture(furniture: bed, center: Point(x: 60, y: 200), quarterTurns: 0)
        let snapped = LayoutEditing.snapped(p, in: room)
        XCTAssertEqual(snapped.center.x, 50, accuracy: 0.001)
        XCTAssertEqual(snapped.center.y, 200, accuracy: 0.001)
    }

    func testDoesNotSnapWhenFarFromWalls() {
        let p = PlacedFurniture(furniture: bed, center: Point(x: 150, y: 200), quarterTurns: 0)
        XCTAssertEqual(LayoutEditing.snapped(p, in: room), p)
    }

    func testRotationWrapsAround() {
        var p = PlacedFurniture(furniture: bed, center: Point(x: 150, y: 200), quarterTurns: 3)
        p = LayoutEditing.rotated(p)
        XCTAssertEqual(p.quarterTurns, 0)
        XCTAssertEqual(p.center, Point(x: 150, y: 200))
    }

    func testPlacedAtCenter() {
        let p = LayoutEditing.placedAtCenter(bed, in: room)
        XCTAssertEqual(p.center, Point(x: 150, y: 200))
    }
}
