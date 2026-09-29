import SwiftUI
import MadoriCore
import MadoriUI

/// 家具が、玄関・廊下・エレベーターなどを通って運び込めるかを確認する。
struct DeliveryCheckView: View {
    @Bindable var record: RoomRecord
    @State private var editing: Passage?

    var body: some View {
        List {
            passagesSection
            resultsSection
        }
        .navigationTitle("搬入チェック")
        .sheet(item: $editing) { passage in
            NavigationStack {
                PassageEditor(passage: passage) { save($0) }
            }
        }
    }

    // MARK: 通り道

    private var passagesSection: some View {
        Section {
            ForEach(record.passages) { passage in
                Button {
                    editing = passage
                } label: {
                    PassageRow(passage: passage)
                }
                .foregroundStyle(.primary)
            }
            .onDelete { offsets in
                var list = record.passages
                list.remove(atOffsets: offsets)
                record.passages = list
            }
            ForEach(record.deliveryRoute.suffix(from: record.passages.count)) { passage in
                PassageRow(passage: passage)
                    .foregroundStyle(.secondary)
            }
            Menu("通り道を追加", systemImage: "plus") {
                Button("玄関のドア", systemImage: "door.left.hand.closed") {
                    editing = .doorway(name: "玄関のドア", width: 75, height: 195)
                }
                Button("廊下の曲がり角", systemImage: "arrow.turn.up.right") {
                    editing = .corner(name: "廊下の曲がり角", width1: 90, width2: 90, ceiling: 240)
                }
                Button("階段の踊り場", systemImage: "stairs") {
                    editing = .corner(name: "階段の踊り場", width1: 80, width2: 80, ceiling: 220)
                }
                Button("エレベーター", systemImage: "arrow.up.and.down.square") {
                    editing = .elevator(name: "エレベーター", doorWidth: 80, doorHeight: 200,
                                        cabinWidth: 100, cabinDepth: 130, cabinHeight: 220)
                }
            }
        } header: {
            Text("通り道")
        } footer: {
            Text("運び込むときに通る場所の寸法です。初期値は目安なので、実際の寸法に直してください。この部屋のドアは、自動で入ります。")
        }
    }

    // MARK: 結果

    private var resultsSection: some View {
        Section {
            if record.furniture.isEmpty {
                Text("家具を追加すると判定します").foregroundStyle(.secondary)
            }
            ForEach(record.furniture) { furniture in
                result(for: furniture)
            }
        } header: {
            Text("家具ごとの結果")
        } footer: {
            Text("家具は箱として、立てる・寝かせるなど向きを変えて通せるものとして判定します。斜めにして通す、分解する、といったことは考えていません。実際には、搬入業者にも確認してください。")
        }
    }

    private func result(for furniture: Furniture) -> some View {
        let route = record.deliveryRoute
        let worst = DeliveryChecker.worst(DeliveryChecker.check(furniture, route: route))
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(worst?.status))
                .foregroundStyle(color(worst?.status))
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(furniture.name)
                Text(summary(worst))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.0f × %.0f × %.0f cm", furniture.width, furniture.depth, furniture.height))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func icon(_ status: DeliveryStatus?) -> String {
        switch status {
        case .ok: return "checkmark.circle.fill"
        case .tight: return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        case nil: return "questionmark.circle"
        }
    }

    private func color(_ status: DeliveryStatus?) -> Color {
        switch status {
        case .ok: return .green
        case .tight: return .orange
        case .blocked: return .red
        case nil: return .secondary
        }
    }

    private func summary(_ worst: DeliveryResult?) -> String {
        guard let worst else { return "通り道を追加すると判定します" }
        switch worst.status {
        case .ok:
            return "問題なく通れます（いちばん狭い「\(worst.passageName)」で、余裕 \(Int(worst.margin)) cm）"
        case .tight:
            return "「\(worst.passageName)」で、余裕は \(Int(worst.margin)) cm です。ぎりぎりです"
        case .blocked:
            return "「\(worst.passageName)」を通れません（\(Int(-worst.margin.rounded(.up))) cm 足りません）"
        }
    }

    private func save(_ passage: Passage) {
        var list = record.passages
        if let i = list.firstIndex(where: { $0.id == passage.id }) {
            list[i] = passage
        } else {
            list.append(passage)
        }
        record.passages = list
    }
}

private struct PassageRow: View {
    let passage: Passage

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(passage.name)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var detail: String {
        switch passage.kind {
        case .doorway:
            return "幅 \(Int(passage.openingWidth)) × 高さ \(Int(passage.openingHeight)) cm"
        case .corner:
            return "廊下の幅 \(Int(passage.corridorWidth1)) / \(Int(passage.corridorWidth2)) cm・天井 \(Int(passage.ceilingHeight)) cm"
        case .elevator:
            return "扉 \(Int(passage.openingWidth)) × \(Int(passage.openingHeight))・かご \(Int(passage.cabinWidth)) × \(Int(passage.cabinDepth)) × \(Int(passage.cabinHeight)) cm"
        }
    }
}

private struct PassageEditor: View {
    @State private var passage: Passage
    let onSave: (Passage) -> Void
    @Environment(\.dismiss) private var dismiss

    init(passage: Passage, onSave: @escaping (Passage) -> Void) {
        _passage = State(initialValue: passage)
        self.onSave = onSave
    }

    private var isValid: Bool {
        let values: [Double]
        switch passage.kind {
        case .doorway: values = [passage.openingWidth, passage.openingHeight]
        case .corner: values = [passage.corridorWidth1, passage.corridorWidth2, passage.ceilingHeight]
        case .elevator: values = [passage.openingWidth, passage.openingHeight, passage.cabinWidth,
                                  passage.cabinDepth, passage.cabinHeight]
        }
        return !passage.name.isEmpty && values.allSatisfy { $0 > 0 && $0 <= 1000 }
    }

    var body: some View {
        Form {
            Section {
                TextField("名前", text: $passage.name)
            }
            switch passage.kind {
            case .doorway:
                Section("開口") {
                    NumberField(title: "幅 (cm)", value: $passage.openingWidth)
                    NumberField(title: "高さ (cm)", value: $passage.openingHeight)
                }
            case .corner:
                Section("廊下・階段") {
                    NumberField(title: "手前の幅 (cm)", value: $passage.corridorWidth1)
                    NumberField(title: "先の幅 (cm)", value: $passage.corridorWidth2)
                    NumberField(title: "天井の高さ (cm)", value: $passage.ceilingHeight)
                }
            case .elevator:
                Section("扉") {
                    NumberField(title: "幅 (cm)", value: $passage.openingWidth)
                    NumberField(title: "高さ (cm)", value: $passage.openingHeight)
                }
                Section("かごの内側") {
                    NumberField(title: "幅 (cm)", value: $passage.cabinWidth)
                    NumberField(title: "奥行き (cm)", value: $passage.cabinDepth)
                    NumberField(title: "高さ (cm)", value: $passage.cabinHeight)
                }
            }
            if !isValid {
                Text("名前を入力し、寸法は 0 より大きく 1000cm 以下で入力してください")
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle(passage.name.isEmpty ? "通り道" : passage.name)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    onSave(passage)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}
