import Foundation

/// 同じ seed なら同じ結果になる乱数生成器 (SplitMix64)。
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// 条件に合う配置案を複数作る。
///
/// 大きい家具から順に、壁沿いなどの候補位置へ乱数を交えて 1 つずつ置く。
/// これを何度も繰り返し、評価の高い順に、互いに似ていない案を選ぶ。
public struct LayoutGenerator: Sendable {
    public let room: Room
    public let furniture: [Furniture]
    public let conditions: LayoutConditions

    public init(room: Room, furniture: [Furniture], conditions: LayoutConditions = LayoutConditions()) {
        self.room = room
        self.furniture = furniture
        self.conditions = conditions
    }

    /// - Parameters:
    ///   - count: 欲しい案の数。似た案しかできなければ、これより少なくなる。
    ///   - minDifference: 案どうしの平均移動量 (cm) がこれ以上なら別の案とみなす。
    ///   - fixed: 位置を固定する家具。どの案でもそのまま置き、残りの家具をその周りに置く。
    public func generate(count: Int = 3, seed: UInt64 = 1, attempts: Int = 200,
                         minDifference: Double = 60, fixed: [PlacedFurniture] = []) -> [Layout] {
        let evaluator = LayoutEvaluator(room: room, conditions: conditions)
        var rng = SeededGenerator(seed: seed)

        var results: [Layout] = []
        for _ in 0..<attempts {
            results.append(attempt(evaluator: evaluator, fixed: fixed, rng: &rng))
        }
        // 問題が少ない順、次にスコアが高い順。
        results.sort {
            $0.issues.count != $1.issues.count ? $0.issues.count < $1.issues.count : $0.score > $1.score
        }

        // 固定した家具は、どの案でも同じなので、案どうしの違いには数えない。
        let fixedIDs = Set(fixed.map { $0.furniture.id })
        var selected: [Layout] = []
        for layout in results {
            guard selected.count < count else { break }
            if selected.allSatisfy({ Self.difference($0, layout, excluding: fixedIDs) >= minDifference }) {
                selected.append(layout)
            }
        }
        return selected
    }

    private func attempt(evaluator: LayoutEvaluator, fixed: [PlacedFurniture],
                         rng: inout SeededGenerator) -> Layout {
        let fixedIDs = Set(fixed.map { $0.furniture.id })
        var keyed: [(Furniture, Double)] = []
        for f in furniture where !fixedIDs.contains(f.id) {
            keyed.append((f, f.width * f.depth * Double.random(in: 0.6...1.4, using: &rng)))
        }
        let order = keyed.sorted { $0.1 > $1.1 }.map { $0.0 }

        var placed: [PlacedFurniture] = fixed
        var unplaced: [Furniture] = []
        for f in order {
            var scored: [(PlacedFurniture, Double)] = []
            for c in candidates(for: f) where evaluator.isPlacementValid(c, others: placed) {
                scored.append((c, evaluator.softScore(c, others: placed)))
            }
            scored.sort { $0.1 > $1.1 }
            if let pick = scored.prefix(5).randomElement(using: &rng) {
                placed.append(pick.0)
            } else {
                unplaced.append(f)
            }
        }
        return evaluator.evaluate(items: placed, unplaced: unplaced)
    }

    /// 壁沿いの候補と、（壁際を好まない家具のみ）部屋の内側の格子状の候補。
    private func candidates(for f: Furniture) -> [PlacedFurniture] {
        var result: [PlacedFurniture] = []

        for i in room.corners.indices {
            let wall = room.wall(i)
            let n = wall.inwardNormal
            let t = wall.tangent
            // 正面の向き, 壁に沿う方向の長さ, 壁から垂直方向の長さ
            var variants: [(Point, Double, Double)] = [(n, f.width, f.depth)]
            if f.canSitSideAgainstWall {
                variants.append((t, f.depth, f.width))
                variants.append((t * -1, f.depth, f.width))
            }
            for (front, along, out) in variants where wall.length >= along {
                let q = PlacedFurniture.quarterTurns(facing: front)
                var offsets: [Double] = []
                var s = along / 2
                while s <= wall.length - along / 2 + 0.001 {
                    offsets.append(s)
                    s += 20
                }
                offsets.append(wall.length - along / 2)
                for s in offsets {
                    let c = wall.start + t * s + n * (out / 2)
                    result.append(PlacedFurniture(furniture: f, center: c, quarterTurns: q))
                }
            }
        }

        if !f.prefersWall {
            let b = room.bounds
            var x = b.minX + 25
            while x < b.maxX {
                var y = b.minY + 25
                while y < b.maxY {
                    for q in 0..<4 {
                        result.append(PlacedFurniture(furniture: f, center: Point(x: x, y: y), quarterTurns: q))
                    }
                    y += 50
                }
                x += 50
            }
        }
        return result
    }

    /// 2 つの案で、同じ家具がどれだけ動いたかの平均 (cm)。向きが違えば 100 を足す。
    static func difference(_ a: Layout, _ b: Layout, excluding: Set<UUID> = []) -> Double {
        var total = 0.0
        var count = 0
        for x in a.items where !excluding.contains(x.furniture.id) {
            count += 1
            guard let y = b.items.first(where: { $0.furniture.id == x.furniture.id }) else { continue }
            total += x.center.distance(to: y.center)
            if x.quarterTurns != y.quarterTurns { total += 100 }
        }
        return total / Double(max(count, 1))
    }
}
