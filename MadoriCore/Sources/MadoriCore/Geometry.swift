import Foundation

/// 平面上の点。単位は cm、座標系は y が上向き。
public struct Point: Hashable, Codable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public static func + (l: Point, r: Point) -> Point { Point(x: l.x + r.x, y: l.y + r.y) }
    public static func - (l: Point, r: Point) -> Point { Point(x: l.x - r.x, y: l.y - r.y) }
    public static func * (l: Point, s: Double) -> Point { Point(x: l.x * s, y: l.y * s) }

    public func distance(to other: Point) -> Double {
        hypot(x - other.x, y - other.y)
    }
}

/// 軸に平行な長方形。
public struct Rect: Hashable, Codable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(center: Point, width: Double, height: Double) {
        self.init(minX: center.x - width / 2, minY: center.y - height / 2,
                  maxX: center.x + width / 2, maxY: center.y + height / 2)
    }

    /// 与えた点をすべて含む最小の長方形。
    public init(covering points: [Point]) {
        self.init(minX: points.map(\.x).min() ?? 0, minY: points.map(\.y).min() ?? 0,
                  maxX: points.map(\.x).max() ?? 0, maxY: points.map(\.y).max() ?? 0)
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var area: Double { max(width, 0) * max(height, 0) }
    public var center: Point { Point(x: (minX + maxX) / 2, y: (minY + maxY) / 2) }

    public var corners: [Point] {
        [Point(x: minX, y: minY), Point(x: maxX, y: minY),
         Point(x: maxX, y: maxY), Point(x: minX, y: maxY)]
    }

    /// 全方向に `d` だけ広げる（負なら縮める）。
    public func expanded(by d: Double) -> Rect {
        Rect(minX: minX - d, minY: minY - d, maxX: maxX + d, maxY: maxY + d)
    }

    /// 面積を持って重なるか。辺が接しているだけなら false。
    public func intersects(_ other: Rect, tolerance: Double = 0.01) -> Bool {
        minX < other.maxX - tolerance && other.minX < maxX - tolerance &&
        minY < other.maxY - tolerance && other.minY < maxY - tolerance
    }

    public func overlapArea(_ other: Rect) -> Double {
        let w = min(maxX, other.maxX) - max(minX, other.minX)
        let h = min(maxY, other.maxY) - max(minY, other.minY)
        return w > 0 && h > 0 ? w * h : 0
    }

    /// 境界を含む内側にあるか。
    public func contains(_ p: Point) -> Bool {
        p.x >= minX && p.x <= maxX && p.y >= minY && p.y <= maxY
    }

    /// 境界を含まない内側にあるか。
    public func strictlyContains(_ p: Point) -> Bool {
        p.x > minX && p.x < maxX && p.y > minY && p.y < maxY
    }
}

enum Polygon {
    /// 偶奇則による内外判定。境界上の点の結果は不定。
    static func contains(_ p: Point, in poly: [Point]) -> Bool {
        guard poly.count >= 3 else { return false }
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let pi = poly[i]
            let pj = poly[j]
            if (pi.y > p.y) != (pj.y > p.y),
               p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    static func signedArea(_ poly: [Point]) -> Double {
        var sum = 0.0
        for i in poly.indices {
            let a = poly[i]
            let b = poly[(i + 1) % poly.count]
            sum += a.x * b.y - b.x * a.y
        }
        return sum / 2
    }
}
