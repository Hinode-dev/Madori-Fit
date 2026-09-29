import SwiftUI
import MadoriCore

extension LayoutIssue {
    /// 画面に出す説明文。
    public var message: String {
        switch kind {
        case .unplaced: return "\(furnitureName): 置き場所が見つかりません"
        case .inaccessible: return "\(furnitureName): 通路が確保できません"
        }
    }
}

/// 配置案の一覧。1 案ごとにカードとして縦に並べる。
public struct LayoutGalleryView: View {
    public let room: Room
    public let layouts: [MadoriCore.Layout]

    public init(room: Room, layouts: [MadoriCore.Layout]) {
        self.room = room
        self.layouts = layouts
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(Array(layouts.enumerated()), id: \.element.id) { index, layout in
                    LayoutCard(room: room, layout: layout, index: index)
                }
            }
            .padding(16)
        }
    }
}

private struct LayoutCard: View {
    let room: Room
    let layout: MadoriCore.Layout
    let index: Int
    @State private var isThreeD = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("案 \(index + 1)").font(.headline)
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
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))
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
