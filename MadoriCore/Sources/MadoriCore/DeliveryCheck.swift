import Foundation

/// 家具を運び込むときに通る場所（玄関のドア、廊下の曲がり角、エレベーターなど）。
public struct Passage: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// ドア・開口部。幅と高さを通り抜けられるか。
        case doorway
        /// 廊下・階段の踊り場などの直角の曲がり角。
        case corner
        /// エレベーター。扉を通り、かごに収まるか。
        case elevator
    }

    public var id: UUID
    public var name: String
    public var kind: Kind
    /// doorway / elevator: 開口の幅 (cm)。
    public var openingWidth: Double
    /// doorway / elevator: 開口の高さ (cm)。
    public var openingHeight: Double
    /// corner: 手前・先の廊下の幅 (cm)。
    public var corridorWidth1: Double
    public var corridorWidth2: Double
    /// corner: 天井の高さ (cm)。
    public var ceilingHeight: Double
    /// elevator: かごの内寸 (cm)。
    public var cabinWidth: Double
    public var cabinDepth: Double
    public var cabinHeight: Double

    public init(id: UUID = UUID(), name: String, kind: Kind,
                openingWidth: Double = 0, openingHeight: Double = 0,
                corridorWidth1: Double = 0, corridorWidth2: Double = 0, ceilingHeight: Double = 0,
                cabinWidth: Double = 0, cabinDepth: Double = 0, cabinHeight: Double = 0) {
        self.id = id
        self.name = name
        self.kind = kind
        self.openingWidth = openingWidth
        self.openingHeight = openingHeight
        self.corridorWidth1 = corridorWidth1
        self.corridorWidth2 = corridorWidth2
        self.ceilingHeight = ceilingHeight
        self.cabinWidth = cabinWidth
        self.cabinDepth = cabinDepth
        self.cabinHeight = cabinHeight
    }

    public static func doorway(name: String, width: Double, height: Double) -> Passage {
        Passage(name: name, kind: .doorway, openingWidth: width, openingHeight: height)
    }

    public static func corner(name: String, width1: Double, width2: Double, ceiling: Double) -> Passage {
        Passage(name: name, kind: .corner, corridorWidth1: width1, corridorWidth2: width2, ceilingHeight: ceiling)
    }

    public static func elevator(name: String, doorWidth: Double, doorHeight: Double,
                                cabinWidth: Double, cabinDepth: Double, cabinHeight: Double) -> Passage {
        Passage(name: name, kind: .elevator, openingWidth: doorWidth, openingHeight: doorHeight,
                cabinWidth: cabinWidth, cabinDepth: cabinDepth, cabinHeight: cabinHeight)
    }
}

public enum DeliveryStatus: Int, Comparable, Sendable {
    case ok
    /// 通るが、余裕が少ない。
    case tight
    case blocked

    public static func < (l: DeliveryStatus, r: DeliveryStatus) -> Bool { l.rawValue < r.rawValue }
}

public struct DeliveryResult: Equatable, Sendable {
    public var status: DeliveryStatus
    /// いちばん余裕のない寸法の余り (cm)。負なら、その分だけ足りない。
    public var margin: Double
    public var passageName: String
}

/// 家具が、通り道を通れるかを判定する。
///
/// 家具は箱として扱い、向きは自由に変えられるものとする（立てる・寝かせる・横にする）。
/// 斜めにして通す、分解する、といったことは考えない。実際に通せるかの目安。
public enum DeliveryChecker {
    /// この余裕 (cm) 以上あれば、問題なく通れるとみなす。
    public static let comfortableMargin = 5.0

    public static func check(_ f: Furniture, through p: Passage) -> DeliveryResult {
        let dims = [f.width, f.depth, f.height]
        let margin: Double
        switch p.kind {
        case .doorway:
            margin = doorwayMargin(dims, p.openingWidth, p.openingHeight)
        case .corner:
            margin = cornerMargin(dims, p.corridorWidth1, p.corridorWidth2, p.ceilingHeight)
        case .elevator:
            let door = doorwayMargin(dims, p.openingWidth, p.openingHeight)
            let cabin = boxMargin(dims, [p.cabinWidth, p.cabinDepth, p.cabinHeight])
            margin = min(door, cabin)
        }
        let status: DeliveryStatus = margin < 0 ? .blocked : (margin < comfortableMargin ? .tight : .ok)
        return DeliveryResult(status: status, margin: margin, passageName: p.name)
    }

    public static func check(_ f: Furniture, route: [Passage]) -> [DeliveryResult] {
        route.map { check(f, through: $0) }
    }

    /// いちばん厳しい結果。
    public static func worst(_ results: [DeliveryResult]) -> DeliveryResult? {
        results.min { $0.margin < $1.margin }
    }

    // MARK: 計算

    /// 開口 (幅 × 高さ) に、家具の断面を通せる余り。断面は、家具の 2 つの短い辺。
    static func doorwayMargin(_ dims: [Double], _ width: Double, _ height: Double) -> Double {
        let s = dims.sorted()
        let a = s[0]
        let b = s[1]
        return max(min(width - a, height - b), min(height - a, width - b))
    }

    /// 箱を、別の箱に入れられる余り。両方の辺を短い順に並べて比べる。
    static func boxMargin(_ dims: [Double], _ container: [Double]) -> Double {
        let s = dims.sorted()
        let c = container.sorted()
        return min(c[0] - s[0], c[1] - s[1], c[2] - s[2])
    }

    /// 直角の曲がり角を通る余り。どの辺を縦にするかを選び、いちばん余裕のある向きを採る。
    static func cornerMargin(_ dims: [Double], _ w1: Double, _ w2: Double, _ ceiling: Double) -> Double {
        var best = -Double.infinity
        for vertical in dims.indices {
            let rest = dims.enumerated().filter { $0.offset != vertical }.map(\.element).sorted()
            let thickness = rest[0]
            let length = rest[1]
            let heightMargin = ceiling - dims[vertical]
            let thicknessMargin = min(w1, w2) - thickness
            let lengthMargin = maxTurnableLength(thickness: thickness, w1: w1, w2: w2) - length
            best = max(best, min(heightMargin, thicknessMargin, lengthMargin))
        }
        return best
    }

    /// 厚み `thickness` の板が、幅 `w1`・`w2` の廊下の直角を曲がれる最大の長さ (cm)。
    ///
    /// 太さのない棒なら、角度 θ で `w1/sinθ + w2/cosθ` の最小値。太さの分を各幅から引いた、少し厳しめの目安にしている。
    static func maxTurnableLength(thickness: Double, w1: Double, w2: Double) -> Double {
        let a = w1 - thickness
        let b = w2 - thickness
        guard a > 0, b > 0 else { return -Double.infinity }
        var best = Double.infinity
        var degrees = 1.0
        while degrees < 90 {
            let t = degrees * Double.pi / 180
            best = min(best, a / sin(t) + b / cos(t))
            degrees += 0.5
        }
        return best
    }
}
