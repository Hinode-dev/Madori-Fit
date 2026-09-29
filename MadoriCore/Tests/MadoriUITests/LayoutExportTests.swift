import XCTest
import MadoriCore
@testable import MadoriUI

final class LayoutExportTests: XCTestCase {
    func testFileNamesAreSanitized() {
        XCTAssertEqual(LayoutExporter.safeFileName("洋室 / 案1: 最終?"), "洋室 - 案1- 最終-")
        XCTAssertEqual(LayoutExporter.safeFileName("   "), "配置案")
        XCTAssertEqual(LayoutExporter.safeFileName(String(repeating: "あ", count: 100)).count, 60)
    }

    @MainActor
    func testExportsPNGAndPDF() throws {
        let room = Room.rectangle(name: "洋室", width: 270, depth: 360, openings: [
            Opening(kind: .door, wallIndex: 0, offset: 20, width: 80)
        ])
        let bed = Furniture(name: "ベッド", category: .bed, width: 97, depth: 195, height: 45)
        let item = PlacedFurniture(furniture: bed, center: Point(x: 60, y: 260), quarterTurns: 2)
        let layout = LayoutEvaluator(room: room, conditions: LayoutConditions())
            .evaluate(items: [item], unplaced: [])

        let files = try XCTUnwrap(LayoutExporter.export(title: "洋室 案1", room: room, layout: layout))
        let png = try Data(contentsOf: files.png)
        let pdf = try Data(contentsOf: files.pdf)
        XCTAssertEqual(Array(png.prefix(4)), [0x89, 0x50, 0x4E, 0x47])       // PNG
        XCTAssertEqual(String(decoding: pdf.prefix(5), as: UTF8.self), "%PDF-")
        XCTAssertGreaterThan(png.count, 1000)
    }
}
