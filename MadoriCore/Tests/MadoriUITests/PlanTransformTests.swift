import XCTest
import SwiftUI
import MadoriCore
@testable import MadoriUI

final class PlanTransformTests: XCTestCase {
    func testYAxisIsFlipped() {
        let bounds = Rect(minX: 0, minY: 0, maxX: 300, maxY: 400)
        let t = PlanTransform(bounds: bounds, size: CGSize(width: 300, height: 400), padding: 0)
        XCTAssertEqual(t.scale, 1, accuracy: 0.0001)
        // 間取りの左下 (0,0) は画面の左下、右上 (300,400) は画面の右上。
        XCTAssertEqual(t.point(Point(x: 0, y: 0)).y, 400, accuracy: 0.0001)
        XCTAssertEqual(t.point(Point(x: 300, y: 400)).y, 0, accuracy: 0.0001)
        XCTAssertEqual(t.point(Point(x: 300, y: 400)).x, 300, accuracy: 0.0001)
    }

    func testFitsAndCentersWithPadding() {
        let bounds = Rect(minX: 0, minY: 0, maxX: 200, maxY: 100)
        let t = PlanTransform(bounds: bounds, size: CGSize(width: 240, height: 240), padding: 20)
        XCTAssertEqual(t.scale, 1, accuracy: 0.0001)       // 幅 200 が 240-40 に収まる最大倍率
        XCTAssertEqual(t.origin.x, 20, accuracy: 0.0001)
        XCTAssertEqual(t.origin.y, 70, accuracy: 0.0001)   // 縦は中央寄せ
    }

    func testRectConversion() {
        let bounds = Rect(minX: 0, minY: 0, maxX: 300, maxY: 400)
        let t = PlanTransform(bounds: bounds, size: CGSize(width: 300, height: 400), padding: 0)
        let r = t.rect(Rect(minX: 10, minY: 20, maxX: 110, maxY: 70))
        XCTAssertEqual(r, CGRect(x: 10, y: 330, width: 100, height: 50))
    }
}
