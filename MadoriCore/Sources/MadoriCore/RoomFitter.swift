import Foundation

/// スキャンで得られた壁・ドア・窓・開口部 1 枚分。単位は cm、y が上向きの平面座標。
public struct ScannedSurface: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case wall, door, window
        /// 扉のない出入り口。ドアと同じ扱いにする。
        case opening
    }

    public var kind: Kind
    public var center: Point
    /// 長辺の向き (ラジアン)。
    public var angle: Double
    public var width: Double
    /// 床から下端までの高さ (cm)。窓の下端の高さに使う。
    public var bottomHeight: Double

    public init(kind: Kind, center: Point, angle: Double, width: Double, bottomHeight: Double = 0) {
        self.kind = kind
        self.center = center
        self.angle = angle
        self.width = width
        self.bottomHeight = bottomHeight
    }
}

public struct ScannedRoom: Equatable, Sendable {
    public var surfaces: [ScannedSurface]
    public var ceilingHeight: Double?

    public init(surfaces: [ScannedSurface], ceilingHeight: Double? = nil) {
        self.surfaces = surfaces
        self.ceilingHeight = ceilingHeight
    }
}

public struct RoomFit: Sendable {
    public var draft: RoomDraft
    /// 近似で失われた情報など、確認してほしいこと。
    public var warnings: [String]
}

/// スキャン結果を、手入力と同じ `RoomDraft`（四角い部屋）に当てはめる。
///
/// 壁の向きから部屋の傾きを求めて回転し、壁全体を囲む長方形を部屋とみなす。
/// ドア・窓は最も近い辺に割り当てる。結果は入力画面で補正できる。
public enum RoomFitter {
    /// 壁が長方形の辺からこれ以上離れていたら、四角くない部屋とみなす (cm)。
    static let edgeTolerance = 30.0
    static let minDoorWidth = 50.0
    static let minWindowWidth = 30.0

    public static func fit(_ scan: ScannedRoom, name: String = "") -> RoomFit? {
        let walls = scan.surfaces.filter { $0.kind == .wall && $0.width > 0 }
        guard !walls.isEmpty else { return nil }

        // 壁は 90° ごとに同じ向きなので、角度を 4 倍して平均を取る。
        var sx = 0.0
        var sy = 0.0
        for w in walls {
            sx += w.width * cos(4 * w.angle)
            sy += w.width * sin(4 * w.angle)
        }
        let theta = atan2(sy, sx) / 4

        func rotate(_ p: Point) -> Point {
            Point(x: p.x * cos(theta) + p.y * sin(theta), y: -p.x * sin(theta) + p.y * cos(theta))
        }

        var ends: [Point] = []
        for w in walls {
            let half = Point(x: cos(w.angle), y: sin(w.angle)) * (w.width / 2)
            ends.append(rotate(w.center + half))
            ends.append(rotate(w.center - half))
        }
        let box = Rect(covering: ends)
        guard box.width > 0, box.height > 0 else { return nil }

        var draft = RoomDraft(name: name, width: box.width.rounded(), depth: box.height.rounded())
        if let h = scan.ceilingHeight { draft.ceilingHeight = h.rounded() }

        var warnings: [String] = []

        // 長方形の辺から離れた壁が多ければ、L 字などの可能性がある。
        var onEdge = 0.0
        var total = 0.0
        for w in walls {
            let c = rotate(w.center)
            let a = w.angle - theta
            let distance: Double
            if abs(sin(a)) < abs(cos(a)) {
                distance = min(abs(c.y - box.minY), abs(c.y - box.maxY))
            } else {
                distance = min(abs(c.x - box.minX), abs(c.x - box.maxX))
            }
            total += w.width
            if distance <= edgeTolerance { onEdge += w.width }
        }
        if total > 0 && onEdge / total < 0.9 {
            warnings.append("部屋が四角ではない可能性があります。外周を囲む長方形に近似したので、形を確認してください")
        }

        var mergedCount = 0
        for s in scan.surfaces where s.kind != .wall {
            // 小さすぎる検出は、ドア・窓ではない。
            guard s.width >= (s.kind == .window ? minWindowWidth : minDoorWidth) else { continue }
            let c = rotate(s.center)
            let distances: [(WallSide, Double)] = [
                (.south, abs(c.y - box.minY)), (.north, abs(c.y - box.maxY)),
                (.west, abs(c.x - box.minX)), (.east, abs(c.x - box.maxX))
            ]
            guard let side = distances.min(by: { $0.1 < $1.1 })?.0 else { continue }

            let length = draft.wallLength(of: side)
            let width = min(s.width.rounded(), length)
            let raw = (side == .south || side == .north)
                ? c.x - box.minX - s.width / 2
                : c.y - box.minY - s.width / 2
            let offset = min(max(raw.rounded(), 0), max(length - width, 0))

            // 同じ場所を、ドアと出入り口の両方として検出することがある。先に見つけたほうだけ残す。
            let overlaps = draft.openings.contains { other in
                guard other.side == side else { return false }
                let overlap = min(offset + width, other.offset + other.width) - max(offset, other.offset)
                return overlap > 0.5 * min(width, other.width)
            }
            if overlaps {
                mergedCount += 1
                continue
            }
            draft.openings.append(OpeningDraft(
                kind: s.kind == .window ? .window : .door,
                side: side, offset: offset, width: width,
                sillHeight: s.kind == .window ? max(s.bottomHeight.rounded(), 0) : 90))
        }

        if mergedCount > 0 {
            warnings.append("重なって検出されたドア・窓を \(mergedCount) 件まとめました。違う場合は、部屋の画面から直せます")
        }
        if !draft.hasDoor {
            warnings.append("ドアや出入り口が見つかりませんでした。必要なら追加してください")
        }
        return RoomFit(draft: draft, warnings: warnings)
    }
}
