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
    private let notices: [String]
    private let onSave: (Room) -> Void

    /// - Parameter notices: スキャン結果の近似など、最初に見てほしい注意書き。
    public init(draft: RoomDraft = RoomDraft(), notices: [String] = [],
                onSave: @escaping (Room) -> Void) {
        _draft = State(initialValue: draft)
        self.notices = notices
        self.onSave = onSave
    }

    public var body: some View {
        Form {
            if !notices.isEmpty {
                Section("スキャン結果について") {
                    ForEach(notices, id: \.self) { notice in
                        Label(notice, systemImage: "info.circle")
                    }
                }
            }
            Section("部屋") {
                RoomNameField(name: $draft.name)
                NumberField(title: "幅 (cm)", value: $draft.width, measures: true)
                NumberField(title: "奥行き (cm)", value: $draft.depth, measures: true)
                if draft.isSizeValid {
                    Text(String(format: "約 %.1f 畳（1畳 = 1.62㎡）", draft.areaInTatami))
                        .foregroundStyle(.secondary)
                }
            }

            if !draft.hasDoor && draft.isSizeValid {
                Section {
                    Text("ドアを追加すると、通路が確保できるかも確認できます")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("ドア・窓") {
                ForEach($draft.openings) { $opening in
                    let id = opening.id
                    OpeningRow(opening: $opening) {
                        draft.openings.removeAll { $0.id == id }
                    }
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
        .madoriBackground()
        .safeAreaInset(edge: .top, spacing: 0) {
            if draft.isSizeValid {
                EditorPreviewPane(draft: $draft)
            }
        }
    }
}

/// 編集画面の上に固定する、部屋のプレビュー。3D では印をつかんで寸法を動かせる。
private struct EditorPreviewPane: View {
    enum Mode: String, CaseIterable {
        case threeD = "3D"
        case plan = "平面図"
    }

    @Binding var draft: RoomDraft
    @State private var mode: Mode = .threeD

    var body: some View {
        VStack(spacing: 6) {
            Picker("表示", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            Group {
                switch mode {
                case .threeD:
                    RoomEditor3DView(draft: $draft)
                        .frame(height: 260)
                case .plan:
                    LayoutPlanView(room: draft.makeRoom(), showsClearance: false, showsLabels: false)
                        .frame(height: 260)
                }
            }
            if mode == .threeD {
                Text("丸い印をドラッグして、幅・奥行き・高さ・ドアや窓の位置を変えられます")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .background(.bar)
    }
}

/// 部屋の名前の入力欄。よくある名前を、ワンタップで選べる。
public struct RoomNameField: View {
    @Binding var name: String

    public init(name: Binding<String>) {
        _name = name
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("名前（例: 寝室）", text: $name)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RoomNaming.suggestions, id: \.self) { suggestion in
                        Button(suggestion) { name = suggestion }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(name == suggestion ? .accentColor : .secondary)
                    }
                }
            }
        }
    }
}

struct OpeningRow: View {
    @Binding var opening: OpeningDraft
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(opening.kind == .door ? "ドア" : "窓",
                      systemImage: opening.kind == .door ? "door.left.hand.closed" : "window.horizontal")
                    .font(.headline)
                Spacer()
                Button("削除", systemImage: "trash", role: .destructive, action: onDelete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
            }
            Picker("種類", selection: $opening.kind) {
                Text("ドア").tag(Opening.Kind.door)
                Text("窓").tag(Opening.Kind.window)
            }
            .pickerStyle(.segmented)
            Picker("壁", selection: $opening.side) {
                ForEach(WallSide.allCases, id: \.self) { side in
                    Text(side.label).tag(side)
                }
            }
            .pickerStyle(.segmented)
            NumberField(title: opening.side.offsetTitle, value: $opening.offset, measures: true)
            NumberField(title: "幅 (cm)", value: $opening.width, measures: true)
        }
        .padding(.vertical, 4)
    }
}

public struct NumberField: View {
    let title: String
    @Binding var value: Double
    let measures: Bool
    #if os(iOS)
    @State private var isMeasuring = false
    #endif

    /// - Parameter measures: true なら、AR で測って入れるボタンを、横に出す（対応した端末のみ）。
    public init(title: String, value: Binding<Double>, measures: Bool = false) {
        self.title = title
        _value = value
        self.measures = measures
    }

    public var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .frame(maxWidth: 100)
            #if os(iOS)
            if measures && ARSupport.isAvailable {
                Button {
                    isMeasuring = true
                } label: {
                    Image(systemName: "ruler")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("ARで測る")
            }
            #endif
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isMeasuring) {
            ARMeasureScreen(title: title, onResult: { cm in
                value = cm
                isMeasuring = false
            }, onClose: { isMeasuring = false })
        }
        #endif
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
