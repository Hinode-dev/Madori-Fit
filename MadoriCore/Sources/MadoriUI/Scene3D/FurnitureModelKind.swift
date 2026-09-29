import MadoriCore

/// 3D で、どんな形の家具として描くか。名前を優先し、なければ種類と寸法から決める。
enum FurnitureModelKind: Equatable {
    case bed, sofa, table, lowTable, desk
    case bookshelf, wardrobe, chest
    case tvStand, fridge, washer
    case generic

    static func of(_ f: Furniture) -> FurnitureModelKind {
        let n = f.name
        if n.contains("ベッド") { return .bed }
        if n.contains("ソファ") { return .sofa }
        if n.contains("ローテーブル") { return .lowTable }
        if n.contains("ダイニング") { return .table }
        if n.contains("デスク") || n.contains("机") { return .desk }
        if n.contains("本棚") { return .bookshelf }
        if n.contains("ワードローブ") || n.contains("クローゼット") { return .wardrobe }
        if n.contains("チェスト") || n.contains("タンス") { return .chest }
        if n.contains("テレビ") { return .tvStand }
        if n.contains("冷蔵庫") { return .fridge }
        if n.contains("洗濯機") { return .washer }

        switch f.category {
        case .bed: return .bed
        case .sofa: return .sofa
        case .table: return f.height < 50 ? .lowTable : .table
        case .desk: return .desk
        case .storage:
            if f.height >= 150 { return f.depth <= 40 ? .bookshelf : .wardrobe }
            return .chest
        case .tv: return .tvStand
        case .appliance: return f.height >= 140 ? .fridge : .washer
        case .other: return .generic
        }
    }
}
