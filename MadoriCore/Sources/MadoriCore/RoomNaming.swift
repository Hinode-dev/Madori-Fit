import Foundation

/// 部屋の名前の候補と、名前がないときの自動の名前。
public enum RoomNaming {
    /// よくある部屋の名前。
    public static let suggestions = [
        "リビング", "ダイニング", "キッチン", "寝室", "洋室", "和室",
        "書斎", "子ども部屋", "玄関", "廊下", "浴室", "トイレ"
    ]

    /// 部屋の名前に合う絵文字。分からなければ家。
    public static func icon(for name: String) -> String {
        let table: [(String, String)] = [
            ("リビング", "🛋️"), ("ダイニング", "🍽️"), ("キッチン", "🍳"), ("寝室", "🛏️"),
            ("和室", "🍵"), ("洋室", "🪑"), ("書斎", "📚"), ("子ども", "🧸"),
            ("玄関", "🚪"), ("廊下", "👣"), ("浴室", "🛁"), ("風呂", "🛁"), ("トイレ", "🚽")
        ]
        return table.first { name.contains($0.0) }?.1 ?? "🏠"
    }

    /// 前後の空白を取った名前。
    public static func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 「部屋 1」「部屋 2」…のうち、まだ使っていない最も小さい番号の名前。
    public static func defaultName(existing: [String]) -> String {
        let used = Set(existing.map { trimmed($0) })
        var n = 1
        while used.contains("部屋 \(n)") { n += 1 }
        return "部屋 \(n)"
    }

    /// 名前が空なら、自動の名前を付けた部屋を返す。
    public static func named(_ room: Room, existing: [String]) -> Room {
        guard trimmed(room.name).isEmpty else { return room }
        var result = room
        result.name = defaultName(existing: existing)
        return result
    }
}
