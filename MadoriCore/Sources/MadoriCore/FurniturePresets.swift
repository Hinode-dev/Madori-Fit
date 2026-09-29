import Foundation

/// 日本の一般的な寸法の家具プリセット (cm)。
public enum FurniturePresets {
    public static let all: [Furniture] = [
        Furniture(name: "シングルベッド", category: .bed, width: 97, depth: 195, height: 45,
                  frontClearance: 60, canSitSideAgainstWall: true),
        Furniture(name: "セミダブルベッド", category: .bed, width: 120, depth: 195, height: 45,
                  frontClearance: 60, canSitSideAgainstWall: true),
        Furniture(name: "ダブルベッド", category: .bed, width: 140, depth: 195, height: 45,
                  frontClearance: 60, canSitSideAgainstWall: true),
        Furniture(name: "2人掛けソファ", category: .sofa, width: 160, depth: 85, height: 80, frontClearance: 70),
        Furniture(name: "3人掛けソファ", category: .sofa, width: 200, depth: 90, height: 80, frontClearance: 70),
        Furniture(name: "ローテーブル", category: .table, width: 90, depth: 50, height: 40,
                  frontClearance: 0, prefersWall: false),
        Furniture(name: "ダイニングテーブル", category: .table, width: 120, depth: 75, height: 72,
                  frontClearance: 70, prefersWall: false),
        Furniture(name: "デスク", category: .desk, width: 120, depth: 60, height: 72, frontClearance: 70),
        Furniture(name: "本棚", category: .storage, width: 80, depth: 30, height: 180, frontClearance: 60),
        Furniture(name: "チェスト", category: .storage, width: 90, depth: 45, height: 110, frontClearance: 60),
        Furniture(name: "ワードローブ", category: .storage, width: 90, depth: 55, height: 180, frontClearance: 60),
        Furniture(name: "テレビ台", category: .tv, width: 120, depth: 40, height: 50, frontClearance: 60),
        Furniture(name: "冷蔵庫", category: .appliance, width: 60, depth: 65, height: 170, frontClearance: 70),
        Furniture(name: "洗濯機", category: .appliance, width: 60, depth: 60, height: 100, frontClearance: 60)
    ]

    public static func preset(named name: String) -> Furniture? {
        all.first { $0.name == name }
    }
}
