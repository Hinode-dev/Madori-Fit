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
                    RoomCard(record: record)
                }
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
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
        .listStyle(.plain)
        .madoriBackground()
        .overlay {
            if rooms.isEmpty {
                emptyState
            }
        }
        .navigationTitle("お部屋")
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
                    Label("部屋を追加", systemImage: "plus.circle.fill")
                        .font(.title3)
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
    fileprivate var emptyState: some View {
        VStack(spacing: 12) {
            Text("🏠").font(.system(size: 72))
            Text("まだお部屋がありません").font(.title3.bold())
            Text("お部屋の寸法を入れるか、スキャンして、\n家具の置き方を考えましょう")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("お部屋を追加する", systemImage: "plus") { isAdding = true }
                .buttonStyle(.pill)
                .padding(.top, 8)
        }
        .padding(32)
    }

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

private struct RoomCard: View {
    let record: RoomRecord

    var body: some View {
        let room = record.room
        let name = record.name.isEmpty ? "名称未設定" : record.name
        let tint = MadoriTheme.tint(for: record.name)
        HStack(spacing: 14) {
            Text(RoomNaming.icon(for: record.name))
                .font(.system(size: 34))
                .frame(width: 64, height: 64)
                .background(tint.opacity(0.22), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(.headline)
                HStack(spacing: 6) {
                    InfoChip(String(format: "%.1f 畳", room.area / 16_200), systemImage: "square.grid.2x2",
                             tint: tint)
                    InfoChip("家具 \(record.furniture.count)", systemImage: "chair.lounge", tint: tint)
                    if !record.sortedSavedLayouts.isEmpty {
                        InfoChip("案 \(record.sortedSavedLayouts.count)", systemImage: "heart.fill", tint: tint)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .madoriCard(padding: 12)
    }
}
