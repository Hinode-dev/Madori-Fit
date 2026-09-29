import Foundation

/// 配置時に守ってほしい条件。
public struct LayoutConditions: Codable, Hashable, Sendable {
    /// 確保したい通路幅 (cm)。
    public var minWalkway: Double
    public var preferences: Set<LayoutPreference>

    public init(minWalkway: Double = 60, preferences: Set<LayoutPreference> = []) {
        self.minWalkway = minWalkway
        self.preferences = preferences
    }
}

public enum LayoutPreference: String, Codable, CaseIterable, Sendable {
    /// デスクを窓の近くに置く。
    case deskNearWindow
    /// ベッドをドアから遠ざける。
    case bedAwayFromDoor
    /// 壁から離れた家具を避け、部屋の中央を空ける。
    case openCenter
}

public struct LayoutIssue: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// 置き場所が見つからなかった。
        case unplaced
        /// ドアから正面までの通路幅が確保できない。
        case inaccessible
    }

    public var kind: Kind
    public var furnitureID: UUID
    public var furnitureName: String
}

/// 1 つの配置案。
public struct Layout: Identifiable, Codable, Sendable {
    public var id: UUID
    public var items: [PlacedFurniture]
    public var issues: [LayoutIssue]
    /// 大きいほど条件に合っている。
    public var score: Double

    public init(id: UUID = UUID(), items: [PlacedFurniture], issues: [LayoutIssue], score: Double) {
        self.id = id
        self.items = items
        self.issues = issues
        self.score = score
    }
}
