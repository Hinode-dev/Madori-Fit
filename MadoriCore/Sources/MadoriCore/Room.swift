import Foundation

/// 壁 1 枚。`inwardNormal` は部屋の内側を向く単位ベクトル。
public struct Wall: Sendable {
    public let start: Point
    public let end: Point

    public var length: Double { start.distance(to: end) }

    public var tangent: Point {
        let l = length
        return Point(x: (end.x - start.x) / l, y: (end.y - start.y) / l)
    }

    /// 反時計回りの多角形では、進行方向の左側が内側になる。
    public var inwardNormal: Point {
        let t = tangent
        return Point(x: -t.y, y: t.x)
    }
}

/// ドアまたは窓。
public struct Opening: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case door
        case window
    }

    public var id: UUID
    public var kind: Kind
    /// `Room.corners` の何番目の頂点から始まる壁か。
    public var wallIndex: Int
    /// 壁の始点から開口部の端までの距離 (cm)。
    public var offset: Double
    public var width: Double
    /// 窓の下端の高さ (cm)。これより高い家具は窓の前に置けない。
    public var sillHeight: Double

    public init(id: UUID = UUID(), kind: Kind, wallIndex: Int, offset: Double,
                width: Double, sillHeight: Double = 90) {
        self.id = id
        self.kind = kind
        self.wallIndex = wallIndex
        self.offset = offset
        self.width = width
        self.sillHeight = sillHeight
    }
}

/// 1 部屋分の間取り。
///
/// - 頂点は反時計回り（y が上向き）で並べる。壁 i は `corners[i]` から `corners[i + 1]`。
/// - 壁は軸に平行（直角の部屋）であることを前提にしている。
public struct Room: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var corners: [Point]
    public var openings: [Opening]
    public var ceilingHeight: Double

    public init(id: UUID = UUID(), name: String = "", corners: [Point],
                openings: [Opening] = [], ceilingHeight: Double = 240) {
        self.id = id
        self.name = name
        self.corners = corners
        self.openings = openings
        self.ceilingHeight = ceilingHeight
    }

    public static func rectangle(name: String = "", width: Double, depth: Double,
                                 openings: [Opening] = []) -> Room {
        Room(name: name,
             corners: [Point(x: 0, y: 0), Point(x: width, y: 0),
                       Point(x: width, y: depth), Point(x: 0, y: depth)],
             openings: openings)
    }

    public var bounds: Rect { Rect(covering: corners) }
    public var area: Double { abs(Polygon.signedArea(corners)) }
    public var isCounterClockwise: Bool { Polygon.signedArea(corners) > 0 }

    public func wall(_ index: Int) -> Wall {
        Wall(start: corners[index], end: corners[(index + 1) % corners.count])
    }

    /// 開口部の前に空けておく領域。ドアは開閉スペース（幅×幅）、窓は 20cm の帯。
    public func zone(for opening: Opening) -> Rect {
        let w = wall(opening.wallIndex)
        let a = w.start + w.tangent * opening.offset
        let b = a + w.tangent * opening.width
        let depth = opening.kind == .door ? opening.width : 20.0
        let n = w.inwardNormal * depth
        return Rect(covering: [a, b, a + n, b + n])
    }

    public func contains(_ point: Point) -> Bool {
        Polygon.contains(point, in: corners)
    }

    /// 長方形が部屋の内側に収まっているか。壁に接するのは可。
    public func contains(_ rect: Rect) -> Bool {
        let r = rect.expanded(by: -0.01)
        guard r.width > 0, r.height > 0 else { return false }
        for c in r.corners where !contains(c) { return false }
        for v in corners where r.strictlyContains(v) { return false }
        return true
    }
}
