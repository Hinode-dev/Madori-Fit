import SwiftUI
import MadoriCore
import MadoriUI

extension FurnitureCategory {
    var label: String {
        switch self {
        case .bed: return "ベッド"
        case .sofa: return "ソファ"
        case .table: return "テーブル"
        case .desk: return "デスク"
        case .storage: return "収納"
        case .tv: return "テレビ台"
        case .appliance: return "家電"
        case .other: return "その他"
        }
    }
}

extension LayoutPreference {
    var label: String {
        switch self {
        case .deskNearWindow: return "デスクを窓の近くに置く"
        case .bedAwayFromDoor: return "ベッドをドアから遠ざける"
        case .openCenter: return "部屋の中央を空ける"
        }
    }
}

struct RoomDetailView: View {
    @Bindable var record: RoomRecord
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isEditingRoom = false
    @State private var isAddingFurniture = false
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var showsPlan = false
    @State private var selectedOpening: Opening?

    var body: some View {
        Group {
            if isDeleting {
                Color.clear
            } else {
                form
            }
        }
        .navigationTitle(isDeleting ? "" : (record.name.isEmpty ? "名称未設定" : record.name))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("この部屋を削除", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Label("その他", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("この部屋を削除しますか？", isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("削除", role: .destructive) { deleteRoom() }
        } message: {
            Text("家具の設定と、保存した配置案も一緒に削除されます。元に戻せません。")
        }
    }

    private var form: some View {
        Form {
            roomSection
            furnitureSection
            conditionsSection
            Section {
                NavigationLink("配置案を作る") {
                    LayoutResultsView(record: record, room: record.room, furniture: record.furniture,
                                      conditions: record.conditions)
                }
                .disabled(record.furniture.isEmpty)
            } footer: {
                if record.furniture.isEmpty { Text("家具を追加すると、配置案を作れます") }
            }
            savedLayoutsSection
        }
        .sheet(isPresented: $isEditingRoom) { editRoomSheet }
        .sheet(isPresented: $isAddingFurniture) {
            NavigationStack {
                FurniturePickerView(added: record.furniture, onAdd: { add($0) }, onUndo: { undoAdd(named: $0) })
            }
        }
    }

    /// 画面を消してから、少し待って削除する。消えかけの画面が、削除済みのデータを読まないようにするため。
    private func deleteRoom() {
        isDeleting = true
        dismiss()
        let target = record
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            context.delete(target)
        }
    }

    // MARK: 保存した配置案

    @ViewBuilder
    private var savedLayoutsSection: some View {
        let saved = record.sortedSavedLayouts
        if !saved.isEmpty {
            Section("保存した配置案（\(saved.count)）") {
                ForEach(saved) { layout in
                    NavigationLink {
                        SavedLayoutView(saved: layout)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(layout.name)
                            Text("家具 \(layout.items.count) 点・\(layout.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for i in offsets { context.delete(saved[i]) }
                }
            }
        }
    }

    // MARK: 部屋

    private var roomSection: some View {
        Section {
            Picker("表示", selection: $showsPlan) {
                Text("3D").tag(false)
                Text("平面図").tag(true)
            }
            .pickerStyle(.segmented)
            if showsPlan {
                LayoutPlanView(room: record.room, showsClearance: false, showsLabels: false,
                               showsDimensions: true)
                    .frame(maxHeight: 300)
            } else {
                Room3DView(room: record.room) { selectedOpening = $0 }
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            if RoomDraft(room: record.room) != nil {
                Button("寸法・ドア・窓を編集") { isEditingRoom = true }
            }
        } header: {
            Text("部屋")
        } footer: {
            Text("指で回転・拡大できます。ドアや窓のラベルをタップすると、種類の変更や削除ができます。")
        }
        .confirmationDialog(
            selectedOpening.map { $0.kind == .door ? "ドア（幅 \(Int($0.width)) cm）" : "窓（幅 \(Int($0.width)) cm）" } ?? "",
            isPresented: Binding(get: { selectedOpening != nil }, set: { if !$0 { selectedOpening = nil } }),
            titleVisibility: .visible,
            presenting: selectedOpening
        ) { opening in
            Button(opening.kind == .door ? "窓に変更" : "ドアに変更") {
                var room = record.room
                room.setKind(opening.kind == .door ? .window : .door, ofOpening: opening.id)
                record.room = room
            }
            Button("削除", role: .destructive) {
                var room = record.room
                room.removeOpening(id: opening.id)
                record.room = room
            }
        } message: { _ in
            Text("スキャンで、ドアや窓でない場所が検出されたときに直せます。")
        }
    }

    @ViewBuilder
    private var editRoomSheet: some View {
        if let draft = RoomDraft(room: record.room) {
            NavigationStack {
                RoomEditorView(draft: draft) { room in
                    record.room = room
                    isEditingRoom = false
                }
                .navigationTitle("部屋を編集")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") { isEditingRoom = false }
                    }
                }
            }
        }
    }

    // MARK: 家具

    private var furnitureSection: some View {
        Section("家具（\(record.furniture.count)）") {
            ForEach(record.furniture) { item in
                NavigationLink {
                    FurnitureEditView(furniture: item) { replace($0) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                        Text(String(format: "%.0f × %.0f × %.0f cm", item.width, item.depth, item.height))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                var list = record.furniture
                list.remove(atOffsets: offsets)
                record.furniture = list
            }
            Button("家具を追加") { isAddingFurniture = true }
        }
    }

    private func add(_ furniture: Furniture) {
        var copy = furniture
        copy.id = UUID()   // プリセットは同じ ID を持つので、追加のたびに付け直す
        record.furniture = record.furniture + [copy]
    }

    /// 同じ名前の家具のうち、最後に追加したものを消す。
    private func undoAdd(named name: String) {
        var list = record.furniture
        if let i = list.lastIndex(where: { $0.name == name }) {
            list.remove(at: i)
            record.furniture = list
        }
    }

    private func replace(_ furniture: Furniture) {
        var list = record.furniture
        if let i = list.firstIndex(where: { $0.id == furniture.id }) {
            list[i] = furniture
            record.furniture = list
        }
    }

    // MARK: 条件

    private var conditionsSection: some View {
        Section("条件") {
            Stepper(value: $record.conditions.minWalkway, in: 40...100, step: 5) {
                Text("通路幅 \(Int(record.conditions.minWalkway)) cm 以上")
            }
            ForEach(LayoutPreference.allCases, id: \.self) { preference in
                Toggle(preference.label, isOn: binding(for: preference))
            }
        }
    }

    private func binding(for preference: LayoutPreference) -> Binding<Bool> {
        Binding(
            get: { record.conditions.preferences.contains(preference) },
            set: { isOn in
                var conditions = record.conditions
                if isOn {
                    conditions.preferences.insert(preference)
                } else {
                    conditions.preferences.remove(preference)
                }
                record.conditions = conditions
            }
        )
    }
}
