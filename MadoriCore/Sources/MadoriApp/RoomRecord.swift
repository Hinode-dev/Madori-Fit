import Foundation
import SwiftData
import MadoriCore

/// 保存する 1 部屋分のデータ。
///
/// 間取り・家具・条件は JSON にして持つ。将来 iCloud (CloudKit) 同期を有効にできるよう、
/// すべてのプロパティに初期値を付け、一意制約は使わない。
@Model
final class RoomRecord {
    var name: String = ""
    var updatedAt: Date = Date()
    var roomData: Data = Data()
    var furnitureData: Data = Data()
    var conditionsData: Data = Data()

    init(room: Room) {
        self.name = room.name
        self.roomData = Self.encode(room) ?? Data()
    }

    var room: Room {
        get { Self.decode(Room.self, from: roomData) ?? Room.rectangle(width: 270, depth: 360) }
        set {
            roomData = Self.encode(newValue) ?? roomData
            name = newValue.name
            updatedAt = Date()
        }
    }

    var furniture: [Furniture] {
        get { Self.decode([Furniture].self, from: furnitureData) ?? [] }
        set {
            furnitureData = Self.encode(newValue) ?? furnitureData
            updatedAt = Date()
        }
    }

    var conditions: LayoutConditions {
        get { Self.decode(LayoutConditions.self, from: conditionsData) ?? LayoutConditions() }
        set {
            conditionsData = Self.encode(newValue) ?? conditionsData
            updatedAt = Date()
        }
    }

    private static func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        try? JSONDecoder().decode(type, from: data)
    }
}

public enum MadoriStorage {
    /// アプリ全体で使う保存先。iCloud 同期は、いまは無効。
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none)
        return try ModelContainer(for: RoomRecord.self, configurations: configuration)
    }
}
