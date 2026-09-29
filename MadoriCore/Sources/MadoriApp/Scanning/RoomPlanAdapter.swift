#if canImport(RoomPlan) && os(iOS)
import RoomPlan
import MadoriCore

/// RoomPlan の結果を、プラットフォームに依存しない `ScannedRoom` に変える。
enum RoomPlanAdapter {
    /// RoomPlan の座標 (m, y が上, z が手前) を、平面図の座標 (cm, y が奥) にする。
    static func scan(from room: CapturedRoom) -> ScannedRoom {
        // 床の高さは分からないので、壁の下端の最小値で代用する。
        let floorY = room.walls
            .map { Double($0.transform.columns.3.y) - Double($0.dimensions.y) / 2 }
            .min() ?? 0

        func convert(_ surfaces: [CapturedRoom.Surface], _ kind: ScannedSurface.Kind) -> [ScannedSurface] {
            surfaces.map { s in
                let position = s.transform.columns.3
                let axis = s.transform.columns.0
                return ScannedSurface(
                    kind: kind,
                    center: Point(x: Double(position.x) * 100, y: -Double(position.z) * 100),
                    angle: atan2(-Double(axis.z), Double(axis.x)),
                    width: Double(s.dimensions.x) * 100,
                    bottomHeight: (Double(position.y) - Double(s.dimensions.y) / 2 - floorY) * 100)
            }
        }

        let surfaces = convert(room.walls, .wall)
            + convert(room.doors, .door)
            + convert(room.windows, .window)
            + convert(room.openings, .opening)
        let ceiling = room.walls.map { Double($0.dimensions.y) * 100 }.max()
        return ScannedRoom(surfaces: surfaces, ceilingHeight: ceiling)
    }
}
#endif
