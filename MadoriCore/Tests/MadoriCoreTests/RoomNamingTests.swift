import XCTest
@testable import MadoriCore

final class RoomNamingTests: XCTestCase {
    func testDefaultNameUsesTheSmallestFreeNumber() {
        XCTAssertEqual(RoomNaming.defaultName(existing: []), "部屋 1")
        XCTAssertEqual(RoomNaming.defaultName(existing: ["部屋 1", "リビング"]), "部屋 2")
        XCTAssertEqual(RoomNaming.defaultName(existing: ["部屋 2"]), "部屋 1")
        XCTAssertEqual(RoomNaming.defaultName(existing: ["部屋 1", "部屋 2", "部屋 3"]), "部屋 4")
        XCTAssertEqual(RoomNaming.defaultName(existing: [" 部屋 1 "]), "部屋 2")
    }

    func testNamedOnlyFillsEmptyNames() {
        let empty = Room.rectangle(name: "  ", width: 270, depth: 360)
        XCTAssertEqual(RoomNaming.named(empty, existing: ["部屋 1"]).name, "部屋 2")

        let named = Room.rectangle(name: "寝室", width: 270, depth: 360)
        XCTAssertEqual(RoomNaming.named(named, existing: []).name, "寝室")
    }

    func testSuggestionsAreNotEmptyAndUnique() {
        XCTAssertFalse(RoomNaming.suggestions.isEmpty)
        XCTAssertEqual(Set(RoomNaming.suggestions).count, RoomNaming.suggestions.count)
    }
}
