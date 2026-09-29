import Foundation
import SwiftData
import MadoriCore

/// 保存した配置案。
///
/// 部屋・条件・家具の配置は、保存した時点のものを丸ごと持つ。
/// あとで部屋の寸法や家具を変えても、保存した案は、そのまま見返せる。
@Model
final class SavedLayout {
    var name: String = ""
    var createdAt: Date = Date()
    var roomData: Data = Data()
    var conditionsData: Data = Data()
    var itemsData: Data = Data()
    /// 位置を固定していた家具の ID。
    var pinnedData: Data = Data()
    var owner: RoomRecord?

    init(name: String, room: Room, conditions: LayoutConditions,
         items: [PlacedFurniture], pinned: Set<UUID>) {
        self.name = name
        self.roomData = Self.encode(room) ?? Data()
        self.conditionsData = Self.encode(conditions) ?? Data()
        self.itemsData = Self.encode(items) ?? Data()
        self.pinnedData = Self.encode(Array(pinned)) ?? Data()
    }

    var room: Room {
        Self.decode(Room.self, from: roomData) ?? Room.rectangle(width: 270, depth: 360)
    }

    var conditions: LayoutConditions {
        Self.decode(LayoutConditions.self, from: conditionsData) ?? LayoutConditions()
    }

    var items: [PlacedFurniture] {
        get { Self.decode([PlacedFurniture].self, from: itemsData) ?? [] }
        set { itemsData = Self.encode(newValue) ?? itemsData }
    }

    var pinned: Set<UUID> {
        get { Set(Self.decode([UUID].self, from: pinnedData) ?? []) }
        set { pinnedData = Self.encode(Array(newValue)) ?? pinnedData }
    }

    /// 保存した内容を評価した配置案。
    var layout: MadoriCore.Layout {
        LayoutEvaluator(room: room, conditions: conditions).evaluate(items: items, unplaced: [])
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}
