import Foundation

/// 配置案を手で直すときの操作。
public enum LayoutEditing {
    /// 部屋の外形の辺に近ければ、ぴったり付ける。
    public static func snapped(_ placed: PlacedFurniture, in room: Room, threshold: Double = 15) -> PlacedFurniture {
        let b = room.bounds
        let fp = placed.footprint
        var dx = 0.0
        var dy = 0.0
        if abs(fp.minX - b.minX) <= threshold {
            dx = b.minX - fp.minX
        } else if abs(fp.maxX - b.maxX) <= threshold {
            dx = b.maxX - fp.maxX
        }
        if abs(fp.minY - b.minY) <= threshold {
            dy = b.minY - fp.minY
        } else if abs(fp.maxY - b.maxY) <= threshold {
            dy = b.maxY - fp.maxY
        }
        var result = placed
        result.center = Point(x: placed.center.x + dx, y: placed.center.y + dy)
        return result
    }

    /// 中心はそのままで、90° 回す。
    public static func rotated(_ placed: PlacedFurniture) -> PlacedFurniture {
        var result = placed
        result.quarterTurns = (placed.quarterTurns + 1) % 4
        return result
    }

    /// 部屋の中央に置く。
    public static func placedAtCenter(_ furniture: Furniture, in room: Room) -> PlacedFurniture {
        PlacedFurniture(furniture: furniture, center: room.bounds.center, quarterTurns: 0)
    }
}
