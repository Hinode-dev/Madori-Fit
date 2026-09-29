import SwiftUI
import SwiftData
import MadoriCore
import MadoriUI

/// 保存した配置案を見返す。手で直す・書き出す・名前を変える・削除する。
struct SavedLayoutView: View {
    @Bindable var saved: SavedLayout
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isThreeD = false
    @State private var isShowingAR = false
    @State private var isEditing = false
    @State private var isExporting = false
    @State private var isRenaming = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var draftName = ""

    var body: some View {
        Group {
            if isDeleting {
                Color.clear
            } else {
                content
            }
        }
        .navigationTitle(isDeleting ? "" : saved.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("手で直す", systemImage: "hand.draw") { isEditing = true }
                    Button("画像・PDF に書き出す", systemImage: "square.and.arrow.up") { isExporting = true }
                    #if os(iOS)
                    if ARSupport.isAvailable {
                        Button("ARで実寸表示", systemImage: "arkit") { isShowingAR = true }
                    }
                    #endif
                    Button("名前を変える", systemImage: "pencil") {
                        draftName = saved.name
                        isRenaming = true
                    }
                    Button("削除", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("名前を変える", isPresented: $isRenaming) {
            TextField("名前", text: $draftName)
            Button("保存") {
                let name = draftName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { saved.name = name }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .confirmationDialog("この配置案を削除しますか？", isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("削除", role: .destructive) { delete() }
        } message: {
            Text("元に戻せません。")
        }
    }

    private var content: some View {
        let layout = saved.layout
        let room = saved.room
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("表示", selection: $isThreeD) {
                    Text("平面図").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                if isThreeD {
                    Layout3DView(room: room, layout: layout)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    LayoutPlanView(room: room, layout: layout, pinnedIDs: saved.pinned)
                }
                if layout.issues.isEmpty {
                    Label("問題なし", systemImage: "checkmark.circle").foregroundStyle(.green)
                } else {
                    ForEach(layout.issues, id: \.self) { issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                    }
                }
                Text("保存日: \(saved.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(layout.items, id: \.furniture.id) { item in
                    HStack {
                        Text(item.furniture.name)
                        Spacer()
                        Text(String(format: "%.0f × %.0f × %.0f cm", item.furniture.width,
                                    item.furniture.depth, item.furniture.height))
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
            .padding(16)
        }
        .navigationDestination(isPresented: $isEditing) {
            if let record = saved.owner {
                LayoutEditorView(record: record, room: room, furniture: record.furniture,
                                 conditions: saved.conditions, items: saved.items, pinned: saved.pinned,
                                 saveLabel: "上書き保存") { items, pinned in
                    saved.items = items
                    saved.pinned = pinned
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingAR) {
            ARPlacementScreen(room: room, items: saved.items) { isShowingAR = false }
        }
        #endif
        .sheet(isPresented: $isExporting) {
            LayoutExportSheet(title: "\(room.name.isEmpty ? "部屋" : room.name) \(saved.name)",
                              room: room, layout: layout)
        }
    }

    /// 画面を消してから、少し待って削除する。消えかけの画面が、削除済みのデータを読まないようにするため。
    private func delete() {
        isDeleting = true
        dismiss()
        let target = saved
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            context.delete(target)
        }
    }
}
