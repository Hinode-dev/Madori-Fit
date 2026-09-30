import Foundation

/// 初回に試せる、サンプルの部屋。スキャンできない端末でも、ひと通りの機能を試せるようにする。
public struct SampleRoom: Sendable {
    public var room: Room
    public var furniture: [Furniture]
    public var passages: [Passage]
}

public enum SampleData {
    /// 6 畳の洋室（ドアと窓つき）、家具 3 点、搬入の通り道 3 か所。呼ぶたびに、新しい ID になる。
    public static func make() -> SampleRoom {
        var draft = RoomDraft(name: "サンプル: 6畳の洋室", width: 270, depth: 360)
        draft.openings = [
            OpeningDraft(kind: .door, side: .south, offset: 20, width: 80),
            OpeningDraft(kind: .window, side: .north, offset: 60, width: 150)
        ]
        let furniture = ["シングルベッド", "デスク", "ワードローブ"].compactMap { name -> Furniture? in
            guard var f = FurniturePresets.preset(named: name) else { return nil }
            f.id = UUID()
            return f
        }
        let passages: [Passage] = [
            .doorway(name: "玄関のドア", width: 75, height: 195),
            .corner(name: "廊下の曲がり角", width1: 90, width2: 90, ceiling: 240),
            .elevator(name: "エレベーター", doorWidth: 80, doorHeight: 200,
                      cabinWidth: 100, cabinDepth: 130, cabinHeight: 220)
        ]
        return SampleRoom(room: draft.makeRoom(), furniture: furniture, passages: passages)
    }
}
