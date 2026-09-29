import Foundation

public enum FurnitureCategory: String, Codable, CaseIterable, Sendable {
    case bed, sofa, table, desk, storage, tv, appliance, other
}

/// 家具の寸法データ（cm）。`width` は正面から見た幅、`depth` は奥行き。
public struct Furniture: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var category: FurnitureCategory
    public var width: Double
    public var depth: Double
    public var height: Double
    /// 正面に確保したい空間の奥行き（引き出し・椅子・立ち座りの分）。
    public var frontClearance: Double
    public var prefersWall: Bool
    /// 長辺を壁に沿わせる置き方（ベッドなど）を許すか。
    public var canSitSideAgainstWall: Bool

    public init(id: UUID = UUID(), name: String, category: FurnitureCategory,
                width: Double, depth: Double, height: Double,
                frontClearance: Double = 60, prefersWall: Bool = true,
                canSitSideAgainstWall: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.width = width
        self.depth = depth
        self.height = height
        self.frontClearance = frontClearance
        self.prefersWall = prefersWall
        self.canSitSideAgainstWall = canSitSideAgainstWall
    }
}

/// 配置済みの家具。`quarterTurns` は正面の向き (0: +y, 1: -x, 2: -y, 3: +x)。
public struct PlacedFurniture: Codable, Hashable, Sendable {
    public var furniture: Furniture
    public var center: Point
    public var quarterTurns: Int

    static let frontDirections: [Point] = [
        Point(x: 0, y: 1), Point(x: -1, y: 0), Point(x: 0, y: -1), Point(x: 1, y: 0)
    ]

    public init(furniture: Furniture, center: Point, quarterTurns: Int) {
        self.furniture = furniture
        self.center = center
        self.quarterTurns = ((quarterTurns % 4) + 4) % 4
    }

    /// 与えた向きに最も近い正面方向の quarterTurns。
    public static func quarterTurns(facing direction: Point) -> Int {
        var best = 0
        var bestDot = -Double.infinity
        for (i, d) in frontDirections.enumerated() {
            let dot = d.x * direction.x + d.y * direction.y
            if dot > bestDot {
                bestDot = dot
                best = i
            }
        }
        return best
    }

    public var frontDirection: Point { Self.frontDirections[quarterTurns] }

    public var footprint: Rect {
        quarterTurns % 2 == 0
            ? Rect(center: center, width: furniture.width, height: furniture.depth)
            : Rect(center: center, width: furniture.depth, height: furniture.width)
    }

    /// 正面の面の中心。
    public var frontFaceCenter: Point {
        center + frontDirection * (furniture.depth / 2)
    }

    /// 正面に空けておく領域。
    public var clearanceZone: Rect {
        let fp = footprint
        let c = furniture.frontClearance
        let f = frontDirection
        if f.y > 0.5 { return Rect(minX: fp.minX, minY: fp.maxY, maxX: fp.maxX, maxY: fp.maxY + c) }
        if f.y < -0.5 { return Rect(minX: fp.minX, minY: fp.minY - c, maxX: fp.maxX, maxY: fp.minY) }
        if f.x > 0.5 { return Rect(minX: fp.maxX, minY: fp.minY, maxX: fp.maxX + c, maxY: fp.maxY) }
        return Rect(minX: fp.minX - c, minY: fp.minY, maxX: fp.minX, maxY: fp.maxY)
    }
}
