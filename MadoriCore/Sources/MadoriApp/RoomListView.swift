import SwiftUI
import SwiftData
import MadoriCore
import MadoriUI

struct RoomListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RoomRecord.updatedAt, order: .reverse) private var rooms: [RoomRecord]
    @State private var isAdding = false
    @State private var isScanning = false
    @State private var pendingDelete: RoomRecord?
    @State private var renaming: RoomRecord?
    @State private var draftName = ""

    var body: some View {
        List {
            ForEach(rooms) { record in
                NavigationLink(value: record) {
                    RoomRow(record: record)
                }
                .swipeActions(edge: .leading) {
                    Button("名前", systemImage: "pencil") { startRenaming(record) }
                        .tint(.blue)
                }
                .contextMenu {
                    Button("名前を変更", systemImage: "pencil") { startRenaming(record) }
                    Button("削除", systemImage: "trash", role: .destructive) { pendingDelete = record }
                }
            }
            .onDelete { offsets in
                // 確認してから削除する。
                if let i = offsets.first { pendingDelete = rooms[i] }
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
        .alert("部屋の名前", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("名前", text: $draftName)
            Button("保存") { applyRename() }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog(
            "この部屋を削除しますか？",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("削除", role: .destructive) {
                if let target = pendingDelete { context.delete(target) }
                pendingDelete = nil
            }
        } message: {
            Text("家具の設定と、保存した配置案も一緒に削除されます。元に戻せません。")
        }
        .sheet(isPresented: $isScanning) {
            #if canImport(RoomPlan) && os(iOS)
            RoomScanFlow(
                onSave: { room in
                    context.insert(RoomRecord(room: named(room)))
                    isScanning = false
                },
                onCancel: { isScanning = false }
            )
            #endif
        }
        .sheet(isPresented: $isAdding) {
            NavigationStack {
                RoomEditorView { room in
                    context.insert(RoomRecord(room: named(room)))
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

extension RoomListView {
    /// 名前が空なら、「部屋 1」のような名前を付ける。
    fileprivate func named(_ room: Room) -> Room {
        RoomNaming.named(room, existing: rooms.map(\.name))
    }

    fileprivate func startRenaming(_ record: RoomRecord) {
        draftName = record.name
        renaming = record
    }

    fileprivate func applyRename() {
        guard let record = renaming else { return }
        let name = RoomNaming.trimmed(draftName)
        guard !name.isEmpty else { return }
        var room = record.room
        room.name = name
        record.room = room
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
