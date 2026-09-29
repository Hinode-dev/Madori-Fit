import SwiftUI
import SwiftData
import MadoriCore
import MadoriUI

struct RoomListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RoomRecord.updatedAt, order: .reverse) private var rooms: [RoomRecord]
    @State private var isAdding = false
    @State private var isScanning = false

    var body: some View {
        List {
            ForEach(rooms) { record in
                NavigationLink(value: record) {
                    RoomRow(record: record)
                }
            }
            .onDelete { offsets in
                for i in offsets { context.delete(rooms[i]) }
            }
        }
        .overlay {
            if rooms.isEmpty {
                ContentUnavailableView("部屋がありません", systemImage: "square.dashed",
                                       description: Text("右上の＋から、部屋の寸法を入力してください"))
            }
        }
        .navigationTitle("部屋")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("寸法を入力", systemImage: "ruler") { isAdding = true }
                    #if canImport(RoomPlan) && os(iOS)
                    if RoomScanSupport.isAvailable {
                        Button("スキャンして作成", systemImage: "camera.viewfinder") { isScanning = true }
                    }
                    #endif
                } label: {
                    Label("部屋を追加", systemImage: "plus")
                }
            }
        }
        .navigationDestination(for: RoomRecord.self) { RoomDetailView(record: $0) }
        .sheet(isPresented: $isScanning) {
            #if canImport(RoomPlan) && os(iOS)
            RoomScanFlow(
                onSave: { room in
                    context.insert(RoomRecord(room: room))
                    isScanning = false
                },
                onCancel: { isScanning = false }
            )
            #endif
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                RoomEditorView { room in
                    context.insert(RoomRecord(room: room))
                    isAdding = false
                }
                .navigationTitle("部屋を追加")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { isAdding = false }
                    }
                }
            }
        }
    }
}

private struct RoomRow: View {
    let record: RoomRecord

    var body: some View {
        let room = record.room
        let b = room.bounds
        VStack(alignment: .leading, spacing: 2) {
            Text(record.name.isEmpty ? "名称未設定" : record.name).font(.headline)
            Text(String(format: "%.0f × %.0f cm・約 %.1f 畳・家具 %d 点",
                        b.width, b.height, room.area / 16_200, record.furniture.count))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
