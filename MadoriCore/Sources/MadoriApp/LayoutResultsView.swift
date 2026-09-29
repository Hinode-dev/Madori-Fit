import SwiftUI
import MadoriCore
import MadoriUI

/// 配置案を作って表示する。計算はメインスレッドの外で行う。
struct LayoutResultsView: View {
    let room: Room
    let furniture: [Furniture]
    let conditions: LayoutConditions

    @State private var seed: UInt64 = 1
    @State private var layouts: [MadoriCore.Layout]?

    var body: some View {
        Group {
            if let layouts {
                if layouts.isEmpty {
                    ContentUnavailableView("配置案が見つかりません", systemImage: "questionmark.square.dashed",
                                           description: Text("部屋の寸法や家具の大きさを見直してください"))
                } else {
                    LayoutGalleryView(room: room, layouts: layouts)
                }
            } else {
                ProgressView("配置案を作っています…")
            }
        }
        .navigationTitle("配置案")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("別の案を見る") { seed += 1 }
                    .disabled(layouts == nil)
            }
        }
        .task(id: seed) {
            layouts = nil
            let generator = LayoutGenerator(room: room, furniture: furniture, conditions: conditions)
            let currentSeed = seed
            layouts = await Task.detached(priority: .userInitiated) {
                generator.generate(count: 3, seed: currentSeed, attempts: 600)
            }.value
        }
    }
}
