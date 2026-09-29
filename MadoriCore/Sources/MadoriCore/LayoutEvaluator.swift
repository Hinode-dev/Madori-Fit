import Foundation

/// 配置の妥当性（必須条件）と好ましさ（スコア）を判定する。
public struct LayoutEvaluator: Sendable {
    public let room: Room
    public let conditions: LayoutConditions

    public init(room: Room, conditions: LayoutConditions) {
        self.room = room
        self.conditions = conditions
    }

    // MARK: 必須条件

    /// 部屋に収まり、他の家具・ドアの開閉スペース・窓（背の高い家具のみ）と重ならないか。
    public func isPlacementValid(_ p: PlacedFurniture, others: [PlacedFurniture]) -> Bool {
        let fp = p.footprint
        guard room.contains(fp) else { return false }
        for o in others where fp.intersects(o.footprint) { return false }
        for opening in room.openings {
            let zone = room.zone(for: opening)
            switch opening.kind {
            case .door:
                if fp.intersects(zone) { return false }
            case .window:
                if p.furniture.height > opening.sillHeight && fp.intersects(zone) { return false }
            }
        }
        return true
    }

    /// ドアから通路幅を保ったまま正面に近づけない家具。ドアが無い部屋では常に空。
    public func inaccessibleItems(_ items: [PlacedFurniture]) -> [PlacedFurniture] {
        let doorZones = room.openings.filter { $0.kind == .door }.map { room.zone(for: $0) }
        guard !doorZones.isEmpty, !items.isEmpty else { return [] }

        let cell = 10.0
        let bounds = room.bounds
        let nx = max(Int(ceil(bounds.width / cell)), 1)
        let ny = max(Int(ceil(bounds.height / cell)), 1)
        let half = conditions.minWalkway / 2
        let inflated = items.map { $0.footprint.expanded(by: half) }

        func center(_ i: Int, _ j: Int) -> Point {
            Point(x: bounds.minX + (Double(i) + 0.5) * cell,
                  y: bounds.minY + (Double(j) + 0.5) * cell)
        }

        // 家具から通路幅の半分以内にあるセルは通れない。壁際は通れるものとする。
        var walkable = [Bool](repeating: false, count: nx * ny)
        for j in 0..<ny {
            for i in 0..<nx {
                let p = center(i, j)
                if room.contains(p) && !inflated.contains(where: { $0.contains(p) }) {
                    walkable[j * nx + i] = true
                }
            }
        }

        var visited = [Bool](repeating: false, count: nx * ny)
        var stack: [Int] = []
        let seedZones = doorZones.map { $0.expanded(by: cell) }
        for j in 0..<ny {
            for i in 0..<nx where walkable[j * nx + i] {
                let p = center(i, j)
                if seedZones.contains(where: { $0.contains(p) }) {
                    visited[j * nx + i] = true
                    stack.append(j * nx + i)
                }
            }
        }
        while let k = stack.popLast() {
            let i = k % nx
            let j = k / nx
            for (di, dj) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let ni = i + di
                let nj = j + dj
                guard ni >= 0, ni < nx, nj >= 0, nj < ny else { continue }
                let nk = nj * nx + ni
                if walkable[nk] && !visited[nk] {
                    visited[nk] = true
                    stack.append(nk)
                }
            }
        }

        let reach = half + cell * 1.5
        var reachable: [Point] = []
        for j in 0..<ny {
            for i in 0..<nx where visited[j * nx + i] {
                reachable.append(center(i, j))
            }
        }
        return items.filter { item in
            let access = item.frontFaceCenter
            return !reachable.contains(where: { $0.distance(to: access) <= reach })
        }
    }

    // MARK: スコア

    /// 1 つの家具の好ましさ。`others` はその家具以外の配置済み家具。
    public func softScore(_ p: PlacedFurniture, others: [PlacedFurniture]) -> Double {
        var s = 0.0
        let zone = p.clearanceZone
        if zone.area > 0 {
            if !room.contains(zone) { s -= 30 }
            let overlap = others.reduce(0) { $0 + zone.overlapArea($1.footprint) }
            s -= min(overlap / zone.area, 1) * 40
        }

        let touchesWall = !room.contains(p.footprint.expanded(by: 5))
        if p.furniture.prefersWall && !touchesWall { s -= 20 }
        if conditions.preferences.contains(.openCenter) && !touchesWall { s -= 15 }

        if conditions.preferences.contains(.deskNearWindow), p.furniture.category == .desk {
            let windows = room.openings.filter { $0.kind == .window }
            if let d = windows.map({ room.zone(for: $0).center.distance(to: p.center) }).min() {
                s += max(0, 1 - d / 300) * 30
            }
        }
        if conditions.preferences.contains(.bedAwayFromDoor), p.furniture.category == .bed {
            let doors = room.openings.filter { $0.kind == .door }
            if let d = doors.map({ room.zone(for: $0).center.distance(to: p.center) }).min() {
                s += min(d, 400) / 400 * 20
            }
        }
        return s
    }

    /// 配置案全体を評価する。
    public func evaluate(items: [PlacedFurniture], unplaced: [Furniture]) -> Layout {
        var score = 0.0
        for (i, item) in items.enumerated() {
            var others = items
            others.remove(at: i)
            score += softScore(item, others: others)
        }
        var issues = unplaced.map {
            LayoutIssue(kind: .unplaced, furnitureID: $0.id, furnitureName: $0.name)
        }
        issues += inaccessibleItems(items).map {
            LayoutIssue(kind: .inaccessible, furnitureID: $0.furniture.id, furnitureName: $0.furniture.name)
        }
        return Layout(items: items, issues: issues, score: score)
    }
}
