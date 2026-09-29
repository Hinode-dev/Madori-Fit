import SwiftUI
import MadoriCore

extension WallSide {
    /// 図の上から見た位置での呼び名。
    var label: String {
        switch self {
        case .south: return "下"
        case .east: return "右"
        case .north: return "上"
        case .west: return "左"
        }
    }

    var offsetTitle: String {
        (self == .south || self == .north) ? "左端からの距離 (cm)" : "下端からの距離 (cm)"
    }
}

/// 寸法の手入力で、四角い部屋とドア・窓を作る画面。
public struct RoomEditorView: View {
    @State private var draft: RoomDraft
    private let onSave: (Room) -> Void

    public init(draft: RoomDraft = RoomDraft(), onSave: @escaping (Room) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            Section("部屋") {
                TextField("名前（例: 洋室）", text: $draft.name)
                NumberField(title: "幅 (cm)", value: $draft.width)
                NumberField(title: "奥行き (cm)", value: $draft.depth)
                if draft.isSizeValid {
                    Text(String(format: "約 %.1f 畳（1畳 = 1.62㎡）", draft.areaInTatami))
                        .foregroundStyle(.secondary)
                }
            }

            if draft.isSizeValid {
                Section("プレビュー") {
                    LayoutPlanView(room: draft.makeRoom(), showsClearance: false, showsLabels: false)
                        .frame(maxHeight: 280)
                    if !draft.hasDoor {
                        Text("ドアを追加すると、通路が確保できるかも確認できます")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("ドア・窓") {
                ForEach($draft.openings) { $opening in
                    OpeningRow(opening: $opening)
                }
                .onDelete { draft.openings.remove(atOffsets: $0) }
                Button("ドアを追加") { draft.addOpening(kind: .door) }
                Button("窓を追加") { draft.addOpening(kind: .window) }
            }

            if !draft.issues.isEmpty {
                Section("入力を確認してください") {
                    ForEach(Array(draft.issues.enumerated()), id: \.offset) { _, issue in
                        Label(issue.message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button("保存") { onSave(draft.makeRoom()) }
                    .disabled(!draft.issues.isEmpty)
            }
        }
    }
}

struct OpeningRow: View {
    @Binding var opening: OpeningDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(opening.kind == .door ? "ドア" : "窓",
                  systemImage: opening.kind == .door ? "door.left.hand.closed" : "window.horizontal")
                .font(.headline)
            Picker("壁", selection: $opening.side) {
                ForEach(WallSide.allCases, id: \.self) { side in
                    Text(side.label).tag(side)
                }
            }
            .pickerStyle(.segmented)
            NumberField(title: opening.side.offsetTitle, value: $opening.offset)
            NumberField(title: "幅 (cm)", value: $opening.width)
        }
        .padding(.vertical, 4)
    }
}

struct NumberField: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(maxWidth: 100)
        }
    }
}

#if DEBUG
struct RoomEditorView_Previews: PreviewProvider {
    static var previews: some View {
        var draft = RoomDraft(name: "洋室")
        draft.addOpening(kind: .door)
        draft.addOpening(kind: .window)
        return RoomEditorView(draft: draft) { _ in }
    }
}
#endif
