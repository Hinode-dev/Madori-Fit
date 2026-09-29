import SwiftUI
import MadoriCore
import MadoriUI

/// プリセットから家具を選ぶ。選んだ家具は何個でも追加できる。
///
/// 追加したことが分かるように、行に追加済みの個数を出し、触覚と、画面下のメッセージ（取り消せる）で知らせる。
struct FurniturePickerView: View {
    /// 今の部屋にある家具。行ごとの追加済みの個数を数えるのに使う。
    let added: [Furniture]
    let onAdd: (Furniture) -> Void
    /// 同じ名前の家具のうち、最後に追加したものを取り消す。
    let onUndo: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var toast: Toast?
    @State private var flashName: String?

    private struct Toast: Equatable {
        let id = UUID()
        let name: String
    }

    var body: some View {
        List {
            Section {
                NavigationLink("自分で寸法を入力") {
                    FurnitureEditView(
                        furniture: Furniture(name: "", category: .other, width: 100, depth: 50, height: 70)
                    ) { add($0) }
                }
            } footer: {
                Text("追加済み: \(added.count) 点")
            }
            ForEach(FurnitureCategory.allCases, id: \.self) { category in
                let items = FurniturePresets.all.filter { $0.category == category }
                if !items.isEmpty {
                    Section(category.label) {
                        ForEach(items) { item in
                            row(item)
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
        .overlay(alignment: .bottom) {
            if let toast {
                toastView(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: toast)
    }

    private func row(_ item: Furniture) -> some View {
        let count = added.filter { $0.name == item.name }.count
        return Button {
            add(item)
        } label: {
            HStack {
                Text(item.name)
                if count > 0 {
                    Text("×\(count)")
                        .font(.caption.bold())
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .transition(.scale.combined(with: .opacity))
                }
                Spacer()
                Text(String(format: "%.0f × %.0f × %.0f", item.width, item.depth, item.height))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.primary)
        .listRowBackground(flashName == item.name ? Color.accentColor.opacity(0.25) : nil)
        .animation(.spring(duration: 0.3), value: count)
    }

    private func toastView(_ toast: Toast) -> some View {
        HStack(spacing: 12) {
            Label("\(toast.name)を追加しました", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.white)
            Button("取り消す") {
                onUndo(toast.name)
                withAnimation { self.toast = nil }
            }
            .font(.subheadline.bold())
            .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.85), in: Capsule())
        .padding(.bottom, 16)
    }

    private func add(_ furniture: Furniture) {
        onAdd(furniture)
        let current = Toast(name: furniture.name)
        withAnimation(.spring(duration: 0.3)) { toast = current }
        flashName = furniture.name
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            withAnimation { if flashName == furniture.name { flashName = nil } }
            try? await Task.sleep(for: .milliseconds(2400))
            // 後から追加した分のメッセージを消さないように、自分のものだけ消す。
            withAnimation { if toast == current { toast = nil } }
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
