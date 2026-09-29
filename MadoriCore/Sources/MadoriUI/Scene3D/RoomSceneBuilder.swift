import SceneKit
import MadoriCore

/// 部屋と家具から SceneKit のノードを作る。
///
/// 座標は cm。平面図の (x, y) は、シーンの (x, -z) に対応し、高さがシーンの y になる。
/// 壁は部屋の外側へ厚みを持たせるので、内側の寸法はそのまま入力値になる。
enum RoomSceneBuilder {
    static let wallThickness = 10.0
    static let doorHeight = 200.0
    static let windowHeight = 110.0

    /// - Parameter includesShell: 床・壁・ドアの空けておく場所も作る。AR で家具だけ重ねるときは false。
    static func contentNode(room: Room, items: [PlacedFurniture], includesShell: Bool = true) -> SCNNode {
        let root = SCNNode()
        root.name = "room"
        let ceiling = room.ceilingHeight

        if includesShell {
            // 床
            let bounds = room.bounds
            let floor = SCNBox(width: CGFloat(bounds.width), height: 2, length: CGFloat(bounds.height), chamferRadius: 0)
            floor.materials = [material(0.86, 0.84, 0.80)]
            let floorNode = SCNNode(geometry: floor)
            floorNode.name = "floor"
            floorNode.position = vector(bounds.center.x, -1, -bounds.center.y)
            root.addChildNode(floorNode)

            // ドアの前の空けておく領域
            for opening in room.openings where opening.kind == .door {
                let zone = room.zone(for: opening)
                let mark = SCNBox(width: CGFloat(zone.width), height: 0.5, length: CGFloat(zone.height), chamferRadius: 0)
                mark.materials = [material(1.0, 0.6, 0.2, alpha: 0.35)]
                let node = SCNNode(geometry: mark)
                node.name = "doorZone"
                node.position = vector(zone.center.x, 0.3, -zone.center.y)
                root.addChildNode(node)
            }

            for i in room.corners.indices {
                for node in wallNodes(room: room, wallIndex: i, ceiling: ceiling) { root.addChildNode(node) }
            }

            // 外側から見たときに、壁の角が欠けないようにする。
            for i in room.corners.indices {
                let previous = room.wall((i + room.corners.count - 1) % room.corners.count).inwardNormal
                let next = room.wall(i).inwardNormal
                let corner = room.corners[i]
                let size = CGFloat(wallThickness)
                let post = SCNBox(width: size, height: CGFloat(ceiling), length: size, chamferRadius: 0)
                post.materials = [wallMaterial()]
                let node = SCNNode(geometry: post)
                node.name = "corner"
                node.position = vector(corner.x - (previous.x + next.x) * wallThickness / 2, ceiling / 2,
                                       -(corner.y - (previous.y + next.y) * wallThickness / 2))
                root.addChildNode(node)
            }
        }

        for item in items {
            root.addChildNode(FurnitureModelBuilder.node(for: item))
        }
        return root
    }

    // MARK: 壁

    private static func wallNodes(room: Room, wallIndex: Int, ceiling: Double) -> [SCNNode] {
        let wall = room.wall(wallIndex)
        let t = wall.tangent
        let n = wall.inwardNormal
        let length = wall.length
        var nodes: [SCNNode] = []

        func add(from a: Double, to b: Double, bottom: Double, top: Double, glass: Bool = false) {
            guard b - a > 0.5, top - bottom > 0.5 else { return }
            let thickness = glass ? 2.0 : wallThickness
            let box = SCNBox(width: CGFloat(b - a), height: CGFloat(top - bottom),
                             length: CGFloat(thickness), chamferRadius: 0)
            box.materials = [glass ? glassMaterial() : wallMaterial()]
            let node = SCNNode(geometry: box)
            node.name = glass ? "glass" : "wall"
            let mid = (a + b) / 2
            let outward = glass ? 0.0 : wallThickness / 2
            let px = wall.start.x + t.x * mid - n.x * outward
            let py = wall.start.y + t.y * mid - n.y * outward
            node.position = vector(px, (bottom + top) / 2, -py)
            node.eulerAngles = SCNVector3(x: 0, y: SCNFloat(atan2(t.y, t.x)), z: 0)
            nodes.append(node)
        }

        var cursor = 0.0
        let openings = room.openings.filter { $0.wallIndex == wallIndex }.sorted { $0.offset < $1.offset }
        for o in openings {
            let a = min(max(o.offset, cursor), length)
            let b = min(o.offset + o.width, length)
            guard b > a else { continue }
            add(from: cursor, to: a, bottom: 0, top: ceiling)
            switch o.kind {
            case .door:
                add(from: a, to: b, bottom: doorHeight, top: ceiling)
            case .window:
                add(from: a, to: b, bottom: 0, top: o.sillHeight)
                add(from: a, to: b, bottom: o.sillHeight, top: o.sillHeight + windowHeight, glass: true)
                add(from: a, to: b, bottom: o.sillHeight + windowHeight, top: ceiling)
            }
            cursor = b
        }
        add(from: cursor, to: length, bottom: 0, top: ceiling)
        return nodes
    }

    // MARK: 材質

    private static func vector(_ x: Double, _ y: Double, _ z: Double) -> SCNVector3 {
        SCNVector3(x: SCNFloat(x), y: SCNFloat(y), z: SCNFloat(z))
    }

    static func material(_ r: Double, _ g: Double, _ b: Double, alpha: Double = 1) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = CGColor(red: r, green: g, blue: b, alpha: 1)
        m.transparency = CGFloat(alpha)
        m.isDoubleSided = true
        if alpha < 1 { m.writesToDepthBuffer = false }
        return m
    }

    /// 内側が見えるように、壁は半透明にする。
    private static func wallMaterial() -> SCNMaterial { material(0.97, 0.97, 0.98, alpha: 0.5) }
    private static func glassMaterial() -> SCNMaterial { material(0.55, 0.85, 1.0, alpha: 0.35) }

    static func categoryColor(_ category: FurnitureCategory) -> (r: Double, g: Double, b: Double) {
        switch category {
        case .bed: return (0.35, 0.36, 0.85)
        case .sofa: return (0.20, 0.65, 0.65)
        case .table: return (0.62, 0.45, 0.30)
        case .desk: return (0.25, 0.50, 0.90)
        case .storage: return (0.30, 0.70, 0.40)
        case .tv: return (0.60, 0.35, 0.75)
        case .appliance: return (0.60, 0.62, 0.65)
        case .other: return (0.90, 0.45, 0.65)
        }
    }
}
