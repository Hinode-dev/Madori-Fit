import SwiftUI
import MadoriCore

extension LayoutIssue {
    /// 画面に出す説明文。
    public var message: String {
        switch kind {
        case .unplaced: return "\(furnitureName): 置き場所が見つかりません"
        case .inaccessible: return "\(furnitureName): 通路が確保できません"
        case .invalid: return "\(furnitureName): はみ出し、または重なりがあります"
        }
    }
}

/// 配置案の一覧。1 案ごとにカードとして縦に並べる。
public struct LayoutGalleryView<Actions: View>: View {
    public let room: Room
    public let layouts: [MadoriCore.Layout]
    private let actions: (MadoriCore.Layout, Int) -> Actions

    /// - Parameter actions: 案ごとに、カードの下に出すボタンなど。引数は、案と、何番目か。
    public init(room: Room, layouts: [MadoriCore.Layout],
                @ViewBuilder actions: @escaping (MadoriCore.Layout, Int) -> Actions) {
        self.room = room
        self.layouts = layouts
        self.actions = actions
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(layouts.enumerated()), id: \.element.id) { index, layout in
                    LayoutCard(room: room, layout: layout, index: index, actions: actions(layout, index))
                }
            }
            .padding(16)
        }
        .background(MadoriTheme.background.ignoresSafeArea())
    }
}

extension LayoutGalleryView where Actions == EmptyView {
    public init(room: Room, layouts: [MadoriCore.Layout]) {
        self.init(room: room, layouts: layouts) { _, _ in EmptyView() }
    }
}

private struct LayoutCard<Actions: View>: View {
    let room: Room
    let layout: MadoriCore.Layout
    let index: Int
    let actions: Actions
    @State private var isThreeD = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("案 \(index + 1) ✨").font(.headline)
                Spacer()
                Picker("表示", selection: $isThreeD) {
                    Text("平面図").tag(false)
                    Text("3D").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 160)
            }
            if isThreeD {
                Layout3DView(room: room, layout: layout)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                LayoutPlanView(room: room, layout: layout)
            }
            if layout.issues.isEmpty {
                Label("問題なし", systemImage: "checkmark.circle").foregroundStyle(.green)
            } else {
                ForEach(layout.issues, id: \.self) { issue in
                    Label(issue.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
                }
            }
            actions
        }
        .madoriCard(padding: 14)
    }
}

#if DEBUG
struct LayoutGalleryView_Previews: PreviewProvider {
    static var room: Room {
        Room.rectangle(name: "洋室", width: 270, depth: 360, openings: [
            Opening(kind: .door, wallIndex: 0, offset: 20, width: 80),
            Opening(kind: .window, wallIndex: 2, offset: 60, width: 150)
        ])
    }

    static var previews: some View {
        let furniture = ["シングルベッド", "デスク", "ワードローブ", "ローテーブル"]
            .compactMap { FurniturePresets.preset(named: $0) }
        let layouts = LayoutGenerator(room: room, furniture: furniture,
                                      conditions: LayoutConditions(preferences: [.deskNearWindow]))
            .generate(count: 3)
        LayoutGalleryView(room: room, layouts: layouts)
    }
}
#endif
