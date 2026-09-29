import SceneKit
import MadoriCore

/// 家具を、種類ごとの形の 3D モデルにする。
///
/// 箱や円柱を組み合わせて作る。座標は、家具の中心の真下を原点にして、
/// x が幅、y が高さ、z が奥行き。正面は -z 側。全体を `quarterTurns` の分だけ回して置く。
enum FurnitureModelBuilder {
    typealias RGB = (r: Double, g: Double, b: Double)

    static func node(for item: PlacedFurniture) -> SCNNode {
        let f = item.furniture
        let root = SCNNode()
        root.name = "furniture"
        let center = item.footprint.center
        root.position = SCNVector3(x: SCNFloat(center.x), y: 0, z: SCNFloat(-center.y))
        root.eulerAngles = SCNVector3(x: 0, y: SCNFloat(Double(item.quarterTurns) * Double.pi / 2), z: 0)

        let parts = Parts(root: root, w: f.width, d: f.depth, h: f.height,
                          base: RoomSceneBuilder.categoryColor(f.category))
        switch FurnitureModelKind.of(f) {
        case .bed: parts.bed()
        case .sofa: parts.sofa()
        case .table: parts.table(topThickness: 4, legSize: 5)
        case .lowTable: parts.table(topThickness: 3, legSize: 4)
        case .desk: parts.desk()
        case .bookshelf: parts.bookshelf()
        case .wardrobe: parts.wardrobe()
        case .chest: parts.chest()
        case .tvStand: parts.tvStand()
        case .fridge: parts.fridge()
        case .washer: parts.washer()
        case .generic: parts.generic()
        }
        return root
    }

    private static let wood: RGB = (0.66, 0.48, 0.32)
    private static let lightWood: RGB = (0.86, 0.74, 0.57)
    private static let white: RGB = (0.96, 0.96, 0.95)
    private static let dark: RGB = (0.16, 0.16, 0.18)

    private static func shade(_ c: RGB, _ k: Double) -> RGB {
        (min(c.r * k, 1), min(c.g * k, 1), min(c.b * k, 1))
    }

    /// 部品を、同じ根元のノードに並べていく。`y` は、部品の下端の高さ。
    private struct Parts {
        let root: SCNNode
        let w: Double
        let d: Double
        let h: Double
        let base: RGB

        @discardableResult
        func box(_ bw: Double, _ bh: Double, _ bl: Double, x: Double = 0, y: Double = 0, z: Double = 0,
                 _ color: RGB, chamfer: Double = 0.6) -> SCNNode {
            let geometry = SCNBox(width: CGFloat(bw), height: CGFloat(bh), length: CGFloat(bl),
                                  chamferRadius: CGFloat(min(chamfer, min(bw, bh, bl) / 2)))
            geometry.materials = [RoomSceneBuilder.material(color.r, color.g, color.b)]
            let node = SCNNode(geometry: geometry)
            node.name = "furniturePart"
            node.position = SCNVector3(x: SCNFloat(x), y: SCNFloat(y + bh / 2), z: SCNFloat(z))
            root.addChildNode(node)
            return node
        }

        // MARK: 寝る・座る

        func bed() {
            let mattressBottom = 0.33 * h
            box(w, mattressBottom, d, wood)                                           // 台
            box(w - 6, h - mattressBottom, d - 10, y: mattressBottom, z: -3, white, chamfer: 3)  // マットレス
            box(w, 1.7 * h, 6, z: d / 2 - 3, wood)                                    // ヘッドボード
            let pillowLength = 28.0
            let z = d / 2 - 6 - pillowLength / 2 - 2
            if w >= 110 {
                let pw = (w - 14) / 2
                box(pw, 9, pillowLength, x: -(pw / 2 + 2), y: h, z: z, white, chamfer: 3)
                box(pw, 9, pillowLength, x: pw / 2 + 2, y: h, z: z, white, chamfer: 3)
            } else {
                box(w * 0.6, 9, pillowLength, y: h, z: z, white, chamfer: 3)
            }
            let blanketLength = d * 0.55
            box(w - 4, 5, blanketLength, y: h, z: -d / 2 + blanketLength / 2 + 2, base, chamfer: 2)  // 掛け布団
        }

        func sofa() {
            let arm = min(16, w * 0.09)
            let inner = w - 2 * arm
            box(w, 0.42 * h, d, shade(base, 0.85))                                    // 座面の台
            box(inner, 0.58 * h, d * 0.25, y: 0.42 * h, z: d / 2 - d * 0.125, base, chamfer: 3)  // 背もたれ
            for side in [-1.0, 1.0] {
                box(arm, 0.72 * h, d, x: side * (w / 2 - arm / 2), base, chamfer: 3)  // 肘掛け
            }
            let count = w >= 190 ? 3 : 2
            let cw = inner / Double(count)
            for i in 0..<count {
                let x = -inner / 2 + cw * (Double(i) + 0.5)
                box(cw - 2, 0.13 * h, d * 0.72, x: x, y: 0.42 * h, z: -d / 2 + d * 0.36 + 1,
                    shade(base, 1.15), chamfer: 3)                                    // 座面クッション
                box(cw - 4, 0.35 * h, d * 0.15, x: x, y: 0.55 * h, z: d / 2 - d * 0.25 - d * 0.075,
                    shade(base, 1.15), chamfer: 3)                                    // 背もたれのクッション
            }
        }

        // MARK: 机・テーブル

        func table(topThickness: Double, legSize: Double) {
            box(w, topThickness, d, y: h - topThickness, lightWood, chamfer: 1)
            let dx = w / 2 - legSize / 2 - 4
            let dz = d / 2 - legSize / 2 - 4
            for sx in [-1.0, 1.0] {
                for sz in [-1.0, 1.0] {
                    box(legSize, h - topThickness, legSize, x: sx * dx, z: sz * dz, wood, chamfer: 0.4)
                }
            }
        }

        func desk() {
            box(w, 3, d, y: h - 3, lightWood, chamfer: 1)                             // 天板
            box(3, h - 3, d - 4, x: -(w / 2 - 1.5), z: 2, wood)                       // 左の側板
            let unit = w * 0.28
            box(unit, h - 3, d - 4, x: w / 2 - unit / 2, z: 2, wood)                  // 右の引き出しユニット
            for k in 1...2 {                                                          // 引き出しの境目
                box(unit - 2, 0.6, 1, x: w / 2 - unit / 2, y: (h - 3) * Double(k) / 3,
                    z: -d / 2 + 2.5, dark, chamfer: 0)
            }
            box(w - 6, (h - 3) * 0.45, 2, y: (h - 3) * 0.4, z: d / 2 - 1, wood)       // 背板
            if w >= 90 && d >= 45 {                                                   // モニター
                let z = d / 2 - 14
                box(12, 1.5, 10, y: h, z: z, dark)
                box(3, 9, 3, y: h + 1.5, z: z, dark)
                box(46, 27, 2, y: h + 10, z: z, dark, chamfer: 0.5)
            }
        }

        // MARK: 収納

        func bookshelf() {
            let plinth = 5.0
            box(2.5, h, d, x: -(w / 2 - 1.25), wood)
            box(2.5, h, d, x: w / 2 - 1.25, wood)
            box(w - 5, 2.5, d, y: h - 2.5, wood)
            box(w - 5, plinth, d - 2, z: -1, wood)
            box(w - 5, h - plinth, 1.5, y: plinth, z: d / 2 - 0.75, shade(wood, 0.85))
            let shelves = max(3, Int(h / 32))
            let step = (h - plinth - 2.5) / Double(shelves)
            let bookColors: [RGB] = [(0.75, 0.25, 0.25), (0.25, 0.45, 0.75), (0.85, 0.7, 0.25),
                                     (0.3, 0.6, 0.4), (0.55, 0.35, 0.65)]
            let innerLeft = -(w / 2 - 2.5)
            let innerWidth = w - 5
            for i in 0..<shelves {
                let bottom = plinth + step * Double(i)
                if i > 0 { box(innerWidth, 2, d - 3, y: bottom, z: -0.5, wood) }
                // 本を、左から並べる（下 2 段のみ、右の 4 割は空ける）。
                guard i < shelves - 1 || shelves <= 3 else { continue }
                var x = innerLeft + 1
                var j = 0
                while x < innerLeft + innerWidth * 0.6 {
                    let bw = 3.0 + Double((i * 7 + j * 3) % 3)
                    let bh = step * (0.55 + 0.05 * Double((i + j * 5) % 6))
                    box(bw, bh, d * 0.65, x: x + bw / 2, y: bottom + 2, z: 2,
                        bookColors[(i + j) % bookColors.count], chamfer: 0.2)
                    x += bw + 0.3
                    j += 1
                }
            }
        }

        func wardrobe() {
            box(w, h, d, lightWood, chamfer: 1)
            let doorWidth = w / 2 - 1.5
            for side in [-1.0, 1.0] {
                box(doorWidth, h - 6, 1.5, x: side * (w / 4), y: 3, z: -d / 2 + 0.75, shade(white, 0.97), chamfer: 0.3)
                box(1.6, 14, 2, x: side * 3, y: h * 0.5, z: -d / 2 + 1, dark, chamfer: 0.3)   // 取っ手
            }
        }

        func chest() {
            box(w, h, d, wood, chamfer: 1)
            let rows = 4
            for k in 0..<rows {
                let y = h * Double(k) / Double(rows)
                if k > 0 { box(w - 2, 0.6, 1, y: y, z: -d / 2 + 0.5, dark, chamfer: 0) }   // 引き出しの境目
                box(12, 1.6, 2, y: y + h / Double(rows) / 2 - 0.8, z: -d / 2 + 1, dark, chamfer: 0.3)  // 取っ手
            }
        }

        // MARK: テレビ台・家電

        func tvStand() {
            box(w, h, d, wood, chamfer: 1)
            box(0.8, h - 4, 1, y: 2, z: -d / 2 + 0.5, dark, chamfer: 0)               // 扉の境目
            box(w * 0.3, 2, min(18, d * 0.6), y: h, z: d * 0.15, dark)                // スタンド
            box(4, 7, 3, y: h + 2, z: d * 0.15 + 4, dark)
            let sw = w * 0.85
            let screen = box(sw, sw * 0.5625, 3, y: h + 8, z: d * 0.15 + 4, dark, chamfer: 0.5)
            screen.geometry?.firstMaterial?.emission.contents = CGColor(red: 0.05, green: 0.08, blue: 0.16, alpha: 1)
        }

        func fridge() {
            let body: RGB = (0.86, 0.87, 0.89)
            box(w, h, d, body, chamfer: 1.5)
            box(w - 1, 0.8, 1, y: h * 0.65, z: -d / 2 + 0.5, dark, chamfer: 0)        // 冷凍室と冷蔵室の境目
            box(2, 24, 2, x: -w / 2 + 6, y: h * 0.72, z: -d / 2 + 1, shade(body, 0.6), chamfer: 0.5)
            box(2, 30, 2, x: -w / 2 + 6, y: h * 0.28, z: -d / 2 + 1, shade(body, 0.6), chamfer: 0.5)
        }

        func washer() {
            box(w, h, d, white, chamfer: 1.5)
            box(w - 6, 8, 1.5, y: h - 12, z: -d / 2 + 0.75, (0.55, 0.57, 0.6))        // 操作パネル
            let radius = w * 0.3
            for (r, color) in [(radius, (0.7, 0.72, 0.75)), (radius * 0.78, (0.2, 0.28, 0.36))] as [(Double, RGB)] {
                let drum = SCNCylinder(radius: CGFloat(r), height: 1)
                drum.materials = [RoomSceneBuilder.material(color.r, color.g, color.b)]
                let node = SCNNode(geometry: drum)
                node.name = "furniturePart"
                node.eulerAngles = SCNVector3(x: SCNFloat(Double.pi / 2), y: 0, z: 0)
                node.position = SCNVector3(x: 0, y: SCNFloat(h * 0.45), z: SCNFloat(-d / 2 + 0.5))
                root.addChildNode(node)
            }
        }

        func generic() {
            box(w, h, d, base, chamfer: 1.5)
        }
    }
}
