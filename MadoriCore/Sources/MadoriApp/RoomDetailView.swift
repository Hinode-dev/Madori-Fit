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
    @State private var isEditingRoom = false
    @State private var isAddingFurniture = false

    var body: some View {
        Form {
            roomSection
            furnitureSection
            conditionsSection
            Section {
                NavigationLink("配置案を作る") {
                    LayoutResultsView(room: record.room, furniture: record.furniture,
                                      conditions: record.conditions)
                }
                .disabled(record.furniture.isEmpty)
            } footer: {
                if record.furniture.isEmpty { Text("家具を追加すると、配置案を作れます") }
            }
        }
        .navigationTitle(record.name.isEmpty ? "名称未設定" : record.name)
        .sheet(isPresented: $isEditingRoom) { editRoomSheet }
        .sheet(isPresented: $isAddingFurniture) {
            NavigationStack {
                FurniturePickerView(addedCount: record.furniture.count) { add($0) }
            }
        }
    }

    // MARK: 部屋

    private var roomSection: some View {
        Section("部屋") {
            LayoutPlanView(room: record.room, showsClearance: false, showsLabels: false)
                .frame(maxHeight: 240)
            if RoomDraft(room: record.room) != nil {
                Button("寸法・ドア・窓を編集") { isEditingRoom = true }
            }
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
