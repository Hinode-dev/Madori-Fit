import XCTest
import SceneKit
import MadoriCore
@testable import MadoriUI

final class RoomHandlesTests: XCTestCase {
    private func draft() -> RoomDraft {
        RoomDraft(name: "洋室", width: 300, depth: 400, openings: [
            OpeningDraft(kind: .door, side: .south, offset: 20, width: 80),
            OpeningDraft(kind: .window, side: .north, offset: 50, width: 100, sillHeight: 90),
            OpeningDraft(kind: .window, side: .east, offset: 30, width: 80, sillHeight: 100)
        ])
    }

    func testSpecsPlaceHandlesOnWalls() throws {
        let d = draft()
        let specs = RoomHandles.specs(for: d)
        func spec(_ kind: HandleKind) throws -> HandleSpec {
            try XCTUnwrap(specs.first { $0.kind == kind })
        }
        XCTAssertEqual(try spec(.width).plan, Point(x: 300, y: 200))
        XCTAssertEqual(try spec(.depth).plan, Point(x: 150, y: 400))
        XCTAssertEqual(try spec(.height).elevation, 240)

        let door = try spec(.opening(d.openings[0].id))
        XCTAssertEqual(door.plan, Point(x: 60, y: 0))            // 20 + 80/2
        XCTAssertEqual(door.axis, Axis3(x: 1, y: 0, z: 0))
        let north = try spec(.opening(d.openings[1].id))
        XCTAssertEqual(north.plan, Point(x: 100, y: 400))
        XCTAssertEqual(north.elevation, 145)                      // 窓の下端 90 + 55
        let east = try spec(.opening(d.openings[2].id))
        XCTAssertEqual(east.plan, Point(x: 300, y: 70))
        XCTAssertEqual(east.axis, Axis3(x: 0, y: 0, z: -1))
    }

    func testDragValueFollowsProjectedAxis() throws {
        // 1cm 進むと右へ 2px 動く。右へ 100px なら 50cm 増える。
        let value = try XCTUnwrap(RoomHandles.dragValue(
            start: 270, translation: CGSize(width: 100, height: 0), pxPerCM: CGVector(dx: 2, dy: 0)))
        XCTAssertEqual(value, 320, accuracy: 0.001)

        // 動かす向きと直角のドラッグでは、値は変わらない。
        let same = try XCTUnwrap(RoomHandles.dragValue(
            start: 270, translation: CGSize(width: 0, height: 80), pxPerCM: CGVector(dx: 2, dy: 0)))
        XCTAssertEqual(same, 270, accuracy: 0.001)

        // 奥へ進む向きが画面の上向き (dy が負) でも、上へドラッグすれば増える。
        let up = try XCTUnwrap(RoomHandles.dragValue(
            start: 400, translation: CGSize(width: 0, height: -30), pxPerCM: CGVector(dx: 0, dy: -1.5)))
        XCTAssertEqual(up, 420, accuracy: 0.001)

        XCTAssertNil(RoomHandles.dragValue(start: 1, translation: .zero, pxPerCM: .zero))
    }

    func testApplySnapsAndClamps() {
        var d = draft()
        RoomHandles.apply(.width, value: 312, to: &d)
        XCTAssertEqual(d.width, 310)
        RoomHandles.apply(.width, value: 5000, to: &d)
        XCTAssertEqual(d.width, 2000)
        RoomHandles.apply(.depth, value: 10, to: &d)
        XCTAssertEqual(d.depth, 100)
        RoomHandles.apply(.height, value: 900, to: &d)
        XCTAssertEqual(d.ceilingHeight, 400)
    }

    func testOpeningStaysOnItsWall() {
        var d = draft()
        let id = d.openings[0].id                                 // 下の壁 (幅 300)、開口 80
        RoomHandles.apply(.opening(id), value: 999, to: &d)
        XCTAssertEqual(d.openings[0].offset, 220)                 // 300 - 80
        RoomHandles.apply(.opening(id), value: -50, to: &d)
        XCTAssertEqual(d.openings[0].offset, 0)
        XCTAssertTrue(d.issues.isEmpty)
    }

    func testValueOfAndLabel() {
        let d = draft()
        XCTAssertEqual(RoomHandles.value(of: .width, in: d), 300)
        XCTAssertEqual(RoomHandles.value(of: .opening(d.openings[1].id), in: d), 50)
        XCTAssertEqual(RoomHandles.label(for: .depth, in: d), "奥行き 400 cm")
        XCTAssertEqual(RoomHandles.label(for: .opening(d.openings[0].id), in: d), "ドア 20 cm")
    }
}

final class RoomSceneBuilderTests: XCTestCase {
    private func names(_ node: SCNNode, _ name: String) -> Int {
        node.childNodes(passingTest: { n, _ in n.name == name }).count
    }

    func testWallsAreSplitAroundOpenings() {
        let room = Room.rectangle(width: 300, depth: 400, openings: [
            Opening(kind: .door, wallIndex: 0, offset: 50, width: 80)
        ])
        let node = RoomSceneBuilder.contentNode(room: room, items: [])
        // 下の壁はドアの左・ドアの上・右の 3 枚、ほかの 3 面は 1 枚ずつ。
        XCTAssertEqual(names(node, "wall"), 6)
        XCTAssertEqual(names(node, "corner"), 4)
        XCTAssertEqual(names(node, "floor"), 1)
        XCTAssertEqual(names(node, "doorZone"), 1)
    }

    func testWindowHasSillHeaderAndGlass() {
        let room = Room.rectangle(width: 300, depth: 400, openings: [
            Opening(kind: .window, wallIndex: 2, offset: 60, width: 150, sillHeight: 90)
        ])
        let node = RoomSceneBuilder.contentNode(room: room, items: [])
        // 上の壁は、窓の左右・窓の下・窓の上の 4 枚。ほかの 3 面と合わせて 7 枚。
        XCTAssertEqual(names(node, "wall"), 7)
        XCTAssertEqual(names(node, "glass"), 1)
    }

    /// 家具は、1 つの箱ではなく、複数の部品でできたモデルになる。
    func testFurnitureIsBuiltFromSeveralParts() throws {
        let bed = try XCTUnwrap(FurniturePresets.preset(named: "シングルベッド"))
        let item = PlacedFurniture(furniture: bed, center: Point(x: 50, y: 100), quarterTurns: 0)
        let room = Room.rectangle(width: 300, depth: 400)
        let node = RoomSceneBuilder.contentNode(room: room, items: [item])

        let furniture = try XCTUnwrap(node.childNodes(passingTest: { n, _ in n.name == "furniture" }).first)
        XCTAssertGreaterThan(furniture.childNodes.count, 3)
        // 平面図の y は、シーンの -z。床の高さに置く。
        XCTAssertEqual(Double(furniture.position.x), 50, accuracy: 0.001)
        XCTAssertEqual(Double(furniture.position.y), 0, accuracy: 0.001)
        XCTAssertEqual(Double(furniture.position.z), -100, accuracy: 0.001)
    }

    func testRotationTurnsTheFrontToTheRightDirection() throws {
        let bed = try XCTUnwrap(FurniturePresets.preset(named: "シングルベッド"))
        let room = Room.rectangle(width: 300, depth: 400)
        // quarterTurns 1: 正面は平面図の -x 向き。シーンでも -x 向き（-z を y 軸まわりに 90° 回した向き）。
        let item = PlacedFurniture(furniture: bed, center: Point(x: 150, y: 200), quarterTurns: 1)
        let node = RoomSceneBuilder.contentNode(room: room, items: [item])
        let furniture = try XCTUnwrap(node.childNodes(passingTest: { n, _ in n.name == "furniture" }).first)
        let angle = Double(furniture.eulerAngles.y)
        XCTAssertEqual(-sin(angle), -1, accuracy: 0.001)   // 正面 (0,0,-1) を回すと x 成分は -sin(angle)
        XCTAssertEqual(-cos(angle), 0, accuracy: 0.001)
    }

    /// すべての部品が、家具の幅・奥行きの中に収まる（高さの飾りと、ドラムなどの円柱は除く）。
    func testPartsStayInsideTheFootprint() throws {
        let room = Room.rectangle(width: 500, depth: 500)
        for preset in FurniturePresets.all {
            let item = PlacedFurniture(furniture: preset, center: Point(x: 250, y: 250), quarterTurns: 0)
            let node = RoomSceneBuilder.contentNode(room: room, items: [item])
            let furniture = try XCTUnwrap(node.childNodes(passingTest: { n, _ in n.name == "furniture" }).first)
            for part in furniture.childNodes {
                guard let box = part.geometry as? SCNBox else { continue }
                let halfW = Double(box.width) / 2
                let halfL = Double(box.length) / 2
                XCTAssertLessThanOrEqual(abs(Double(part.position.x)) + halfW, preset.width / 2 + 0.01,
                                         "\(preset.name): 幅からはみ出している")
                XCTAssertLessThanOrEqual(abs(Double(part.position.z)) + halfL, preset.depth / 2 + 0.01,
                                         "\(preset.name): 奥行きからはみ出している")
            }
        }
    }

    func testEveryPresetGetsASpecificModel() {
        for preset in FurniturePresets.all {
            XCTAssertNotEqual(FurnitureModelKind.of(preset), .generic, "\(preset.name)")
        }
    }

    func testControllerReplacesContentOnUpdate() {
        let controller = RoomSceneController()
        let room = Room.rectangle(width: 300, depth: 400)
        controller.update(room: room)
        controller.update(room: room)
        let count = controller.scene.rootNode.childNodes(passingTest: { n, _ in n.name == "room" }).count
        XCTAssertEqual(count, 1)
    }
}

final class OpeningLabelTests: XCTestCase {
    func testLabelsSitAboveEachOpening() throws {
        let door = Opening(kind: .door, wallIndex: 0, offset: 50, width: 80)
        let window = Opening(kind: .window, wallIndex: 2, offset: 60, width: 150, sillHeight: 90)
        let room = Room.rectangle(width: 300, depth: 400, openings: [door, window])
        let specs = RoomHandles.labelSpecs(for: room)
        XCTAssertEqual(specs.count, 2)

        let d = try XCTUnwrap(specs.first { $0.kind == .opening(door.id) })
        XCTAssertEqual(d.plan.x, 90, accuracy: 0.001)         // 50 + 80/2
        XCTAssertEqual(d.plan.y, 0, accuracy: 0.001)
        XCTAssertEqual(d.elevation, 215, accuracy: 0.001)     // ドアの高さ 200 + 15

        let w = try XCTUnwrap(specs.first { $0.kind == .opening(window.id) })
        XCTAssertEqual(w.plan.x, 165, accuracy: 0.001)        // 上の壁は右から: 300 - (60 + 75)
        XCTAssertEqual(w.plan.y, 400, accuracy: 0.001)
        XCTAssertEqual(w.elevation, 215, accuracy: 0.001)     // 下端 90 + 窓の高さ 110 + 15
    }
}

final class FurnitureModelKindTests: XCTestCase {
    private func kind(_ name: String, _ category: FurnitureCategory, w: Double = 100, d: Double = 50,
                      h: Double = 70) -> FurnitureModelKind {
        FurnitureModelKind.of(Furniture(name: name, category: category, width: w, depth: d, height: h))
    }

    func testNameTakesPriority() {
        XCTAssertEqual(kind("私のベッド", .other), .bed)
        XCTAssertEqual(kind("ローテーブル", .table, h: 40), .lowTable)
        XCTAssertEqual(kind("ダイニングテーブル", .table, h: 72), .table)
        XCTAssertEqual(kind("本棚", .storage, h: 180, d: 30), .bookshelf)
        XCTAssertEqual(kind("ワードローブ", .storage, h: 180, d: 55), .wardrobe)
        XCTAssertEqual(kind("冷蔵庫", .appliance, h: 170), .fridge)
        XCTAssertEqual(kind("洗濯機", .appliance, h: 100), .washer)
    }

    func testFallsBackToCategoryAndSize() {
        XCTAssertEqual(kind("名無し", .table, h: 40), .lowTable)
        XCTAssertEqual(kind("名無し", .table, h: 72), .table)
        XCTAssertEqual(kind("名無し", .storage, h: 180, d: 30), .bookshelf)
        XCTAssertEqual(kind("名無し", .storage, h: 180, d: 60), .wardrobe)
        XCTAssertEqual(kind("名無し", .storage, h: 90), .chest)
        XCTAssertEqual(kind("名無し", .appliance, h: 90), .washer)
        XCTAssertEqual(kind("名無し", .other), .generic)
    }
}
