import SwiftUI
import SwiftData
import MadoriCore
import MadoriUI

/// 配置案を作って表示する。計算はメインスレッドの外で行う。
/// `fixed` を渡すと、その家具は位置を固定し、ほかの家具だけを置き直す。
struct LayoutResultsView: View {
    let record: RoomRecord
    let room: Room
    let furniture: [Furniture]
    let conditions: LayoutConditions
    var fixed: [PlacedFurniture] = []

    @Environment(\.modelContext) private var context
    @State private var seed: UInt64 = 1
    @State private var layouts: [MadoriCore.Layout]?
    @State private var savedNotice: String?

    var body: some View {
        Group {
            if let layouts {
                if layouts.isEmpty {
                    ContentUnavailableView("配置案が見つかりません", systemImage: "questionmark.square.dashed",
                                           description: Text("部屋の寸法や家具の大きさを見直してください"))
                } else {
                    LayoutGalleryView(room: room, layouts: layouts) { layout, index in
                        actions(for: layout, index: index)
                    }
                }
            } else {
                ProgressView("配置案を作っています ✨")
            }
        }
        .navigationTitle(fixed.isEmpty ? "配置案" : "固定を残した配置案")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("別の案を見る") { seed += 1 }
                    .disabled(layouts == nil)
            }
        }
        .alert("保存しました", isPresented: Binding(
            get: { savedNotice != nil },
            set: { if !$0 { savedNotice = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(savedNotice ?? "")
        }
        .task(id: seed) {
            layouts = nil
            let generator = LayoutGenerator(room: room, furniture: furniture, conditions: conditions)
            let currentSeed = seed
            let fixed = fixed
            layouts = await Task.detached(priority: .userInitiated) {
                generator.generate(count: 3, seed: currentSeed, attempts: 600, fixed: fixed)
            }.value
        }
    }

    private var fixedIDs: Set<UUID> { Set(fixed.map { $0.furniture.id }) }

    private func actions(for layout: MadoriCore.Layout, index: Int) -> some View {
        HStack {
            NavigationLink {
                LayoutEditorView(record: record, room: room, furniture: furniture, conditions: conditions,
                                 items: layout.items, pinned: fixedIDs, saveLabel: "保存") { items, pinned in
                    save(items: items, pinned: pinned, name: defaultName(index: index))
                }
            } label: {
                Label("手で直す", systemImage: "hand.draw")
            }
            .buttonStyle(.soft)
            Spacer()
            Button {
                save(items: layout.items, pinned: fixedIDs, name: defaultName(index: index))
            } label: {
                Label("この案を保存", systemImage: "heart.fill")
            }
            .buttonStyle(.pill)
        }
    }

    private func defaultName(index: Int) -> String {
        let date = Date().formatted(.dateTime.month().day().hour().minute())
        return "案 \(index + 1)（\(date)）"
    }

    private func save(items: [PlacedFurniture], pinned: Set<UUID>, name: String) {
        let saved = SavedLayout(name: name, room: room, conditions: conditions, items: items, pinned: pinned)
        context.insert(saved)
        saved.owner = record
        savedNotice = "「\(name)」を、部屋の画面の「保存した配置案」に入れました。"
    }
}
