import SwiftUI
import MadoriCore

/// 配置案を上から見た図で表示し、家具をドラッグで動かせるようにする。
///
/// 家具のタップで選択、ドラッグで移動。部屋の壁に近づくと、ぴったり付く。
public struct EditableLayoutPlanView: View {
    public let room: Room
    @Binding public var items: [PlacedFurniture]
    /// `items` を評価した結果。はみ出しや通路の問題を赤で示すのに使う。
    public let layout: MadoriCore.Layout
    @Binding public var selectedID: UUID?
    public let pinnedIDs: Set<UUID>
    /// ドラッグを始める直前に呼ぶ。やり直しの履歴に、変更前の状態を残すのに使う。
    private let onEditStart: () -> Void
    /// ドラッグが終わったときに呼ぶ。
    private let onEditEnd: () -> Void
    @State private var dragStarts: [UUID: Point] = [:]

    public init(room: Room, items: Binding<[PlacedFurniture]>, layout: MadoriCore.Layout,
                selectedID: Binding<UUID?>, pinnedIDs: Set<UUID>,
                onEditStart: @escaping () -> Void = {}, onEditEnd: @escaping () -> Void = {}) {
        self.onEditStart = onEditStart
        self.onEditEnd = onEditEnd
        self.room = room
        _items = items
        self.layout = layout
        _selectedID = selectedID
        self.pinnedIDs = pinnedIDs
    }

    public var body: some View {
        let bounds = room.bounds
        GeometryReader { geo in
            let t = PlanTransform(bounds: bounds, size: geo.size,
                                  padding: LayoutPlanView.padding(showsDimensions: false))
            ZStack {
                LayoutPlanView(room: room, layout: layout, selectedID: selectedID, pinnedIDs: pinnedIDs)
                    .allowsHitTesting(false)
                ForEach(items, id: \.furniture.id) { item in
                    let rect = t.rect(item.footprint)
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: max(rect.width, 24), height: max(rect.height, 24))
                        .gesture(drag(item.furniture.id, scale: t.scale))
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel(item.furniture.name)
                }
            }
        }
        .aspectRatio(max(bounds.width, 1) / max(bounds.height, 1), contentMode: .fit)
    }

    private func drag(_ id: UUID, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                selectedID = id
                if dragStarts[id] == nil { onEditStart() }
                guard let i = items.firstIndex(where: { $0.furniture.id == id }) else { return }
                let start = dragStarts[id] ?? items[i].center
                dragStarts[id] = start
                var moved = items[i]
                // 画面は y が下向き、間取りは y が上向き。
                moved.center = Point(x: start.x + Double(value.translation.width / scale),
                                     y: start.y - Double(value.translation.height / scale))
                items[i] = LayoutEditing.snapped(moved, in: room)
            }
            .onEnded { _ in
                dragStarts[id] = nil
                onEditEnd()
            }
    }
}
