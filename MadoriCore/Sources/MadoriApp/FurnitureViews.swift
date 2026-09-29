import SwiftUI
import MadoriCore
import MadoriUI

/// プリセットから家具を選ぶ。選んだ家具は何個でも追加できる。
struct FurniturePickerView: View {
    let addedCount: Int
    let onAdd: (Furniture) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                NavigationLink("自分で寸法を入力") {
                    FurnitureEditView(
                        furniture: Furniture(name: "", category: .other, width: 100, depth: 50, height: 70)
                    ) { onAdd($0) }
                }
            } footer: {
                Text("追加済み: \(addedCount) 点")
            }
            ForEach(FurnitureCategory.allCases, id: \.self) { category in
                let items = FurniturePresets.all.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.label) {
                        ForEach(items) { item in
                            Button {
                                onAdd(item)
                            } label: {
                                HStack {
                                    Text(item.name)
                                    Spacer()
                                    Text(String(format: "%.0f × %.0f × %.0f", item.width, item.depth, item.height))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("家具を追加")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了") { dismiss() }
            }
        }
    }
}

/// 家具の名前・寸法を編集する。
struct FurnitureEditView: View {
    @State private var furniture: Furniture
    private let onSave: (Furniture) -> Void
    @Environment(\.dismiss) private var dismiss

    init(furniture: Furniture, onSave: @escaping (Furniture) -> Void) {
        _furniture = State(initialValue: furniture)
        self.onSave = onSave
    }

    private static let sizeRange: ClosedRange<Double> = 10...500

    private var isValid: Bool {
        [furniture.width, furniture.depth, furniture.height].allSatisfy { Self.sizeRange.contains($0) }
            && !furniture.name.isEmpty
    }

    var body: some View {
        Form {
            Section("家具") {
                TextField("名前", text: $furniture.name)
                Picker("種類", selection: $furniture.category) {
                    ForEach(FurnitureCategory.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Section("寸法（正面から見た向き）") {
                NumberField(title: "幅 (cm)", value: $furniture.width)
                NumberField(title: "奥行き (cm)", value: $furniture.depth)
                NumberField(title: "高さ (cm)", value: $furniture.height)
            }
            Section {
                NumberField(title: "正面に空けたい距離 (cm)", value: $furniture.frontClearance)
                Toggle("壁際に置きたい", isOn: $furniture.prefersWall)
            } footer: {
                Text("引き出しや椅子を引く分など、家具の前に空けておきたい距離です")
            }
            if !isValid {
                Text("名前を入力し、寸法は 10〜500cm で入力してください")
                    .foregroundStyle(.red)
            }
            Section {
                Button("保存") {
                    onSave(furniture)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
        .navigationTitle(furniture.name.isEmpty ? "家具" : furniture.name)
    }
}
