import Foundation

/// 四角い部屋の 4 つの壁。図の上から見た位置で呼ぶ。
public enum WallSide: String, Codable, CaseIterable, Sendable {
    case south, east, north, west

    /// `Room.corners` の順序に対応する壁の番号。
    public var wallIndex: Int {
        switch self {
        case .south: return 0
        case .east: return 1
        case .north: return 2
        case .west: return 3
        }
    }

    public init?(wallIndex: Int) {
        guard let side = Self.allCases.first(where: { $0.wallIndex == wallIndex }) else { return nil }
        self = side
    }

    /// 壁の始点が図の左端・下端に来る向きか（南・東）。北・西は逆向き。
    var startsAtLeadingEdge: Bool { self == .south || self == .east }
}

/// 手入力中のドア・窓。`offset` は図の左端（上下の壁）または下端（左右の壁）からの距離。
public struct OpeningDraft: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var kind: Opening.Kind
    public var side: WallSide
    public var offset: Double
    public var width: Double
    public var sillHeight: Double

    public init(id: UUID = UUID(), kind: Opening.Kind, side: WallSide,
                offset: Double, width: Double, sillHeight: Double = 90) {
        self.id = id
        self.kind = kind
        self.side = side
        self.offset = offset
        self.width = width
        self.sillHeight = sillHeight
    }
}

public enum RoomDraftIssue: Equatable, Sendable {
    case sizeOutOfRange
    case openingTooNarrow(UUID)
    case openingOutOfWall(UUID)
    case openingsOverlap(UUID)

    public var message: String {
        switch self {
        case .sizeOutOfRange: return "幅と奥行きは 100〜2000cm で入力してください"
        case .openingTooNarrow: return "ドア・窓の幅は 30〜400cm で入力してください"
        case .openingOutOfWall: return "ドア・窓が壁からはみ出しています"
        case .openingsOverlap: return "同じ壁のドア・窓が重なっています"
        }
    }
}

/// 寸法の手入力で四角い部屋を作るための下書き。
public struct RoomDraft: Identifiable, Equatable, Sendable {
    public static let sizeRange: ClosedRange<Double> = 100...2000
    public static let openingWidthRange: ClosedRange<Double> = 30...400
    /// 1 畳 = 1.62㎡ として換算する (cm²)。
    static let squareCentimetersPerTatami = 16_200.0

    public var id: UUID
    public var name: String
    public var width: Double
    public var depth: Double
    public var ceilingHeight: Double
    public var openings: [OpeningDraft]

    public init(id: UUID = UUID(), name: String = "", width: Double = 270, depth: Double = 360,
                ceilingHeight: Double = 240, openings: [OpeningDraft] = []) {
        self.id = id
        self.name = name
        self.width = width
        self.depth = depth
        self.ceilingHeight = ceilingHeight
        self.openings = openings
    }

    /// 四角い部屋から下書きを作る。四角くない部屋なら nil。
    public init?(room: Room) {
        guard room.corners.count == 4 else { return nil }
        let b = room.bounds
        let matches = zip(room.corners, b.corners).allSatisfy {
            abs($0.x - $1.x) < 0.01 && abs($0.y - $1.y) < 0.01
        }
        guard matches else { return nil }

        id = room.id
        name = room.name
        width = b.width
        depth = b.height
        ceilingHeight = room.ceilingHeight
        var drafts: [OpeningDraft] = []
        for o in room.openings {
            guard let side = WallSide(wallIndex: o.wallIndex) else { return nil }
            let length = (side == .south || side == .north) ? b.width : b.height
            let offset = side.startsAtLeadingEdge ? o.offset : length - o.offset - o.width
            drafts.append(OpeningDraft(id: o.id, kind: o.kind, side: side, offset: offset,
                                       width: o.width, sillHeight: o.sillHeight))
        }
        openings = drafts
    }

    public var areaInTatami: Double { width * depth / Self.squareCentimetersPerTatami }
    public var hasDoor: Bool { openings.contains { $0.kind == .door } }
    public var isSizeValid: Bool { Self.sizeRange.contains(width) && Self.sizeRange.contains(depth) }

    public func wallLength(of side: WallSide) -> Double {
        (side == .south || side == .north) ? width : depth
    }

    public var issues: [RoomDraftIssue] {
        var result: [RoomDraftIssue] = []
        if !isSizeValid { result.append(.sizeOutOfRange) }
        for (i, o) in openings.enumerated() {
            if !Self.openingWidthRange.contains(o.width) {
                result.append(.openingTooNarrow(o.id))
            }
            if o.offset < -0.001 || o.offset + o.width > wallLength(of: o.side) + 0.001 {
                result.append(.openingOutOfWall(o.id))
            }
            for other in openings[..<i] where other.side == o.side {
                if o.offset < other.offset + other.width - 0.001 && other.offset < o.offset + o.width - 0.001 {
                    result.append(.openingsOverlap(o.id))
                    break
                }
            }
        }
        return result
    }

    /// ドアは下の壁の左寄り、窓は上の壁の中央を初期位置にして追加する。
    public mutating func addOpening(kind: Opening.Kind) {
        let side: WallSide = kind == .door ? .south : .north
        let length = wallLength(of: side)
        let w = min(kind == .door ? 80.0 : 150.0, max(length - 40, Self.openingWidthRange.lowerBound))
        let offset = kind == .door ? min(20, max(length - w, 0)) : max((length - w) / 2, 0)
        openings.append(OpeningDraft(kind: kind, side: side, offset: offset, width: w))
    }

    public func makeRoom() -> Room {
        let converted = openings.map { o -> Opening in
            let length = wallLength(of: o.side)
            let start = o.side.startsAtLeadingEdge ? o.offset : length - o.offset - o.width
            return Opening(id: o.id, kind: o.kind, wallIndex: o.side.wallIndex,
                           offset: start, width: o.width, sillHeight: o.sillHeight)
        }
        var room = Room.rectangle(name: name, width: width, depth: depth, openings: converted)
        room.id = id
        room.ceilingHeight = ceilingHeight
        return room
    }
}
