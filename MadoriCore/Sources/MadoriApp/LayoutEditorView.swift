import SwiftUI
import MadoriCore
import MadoriUI

/// 元に戻す・やり直すための、編集中の状態。
struct LayoutEditState: Equatable {
    var items: [PlacedFurniture]
    var pinned: Set<UUID>
}

/// 配置案を手で直す。家具のドラッグ移動、回転、固定、外す・置く。
/// 固定した家具は、「ほかを作り直す」で、その位置を保ったまま残りの配置案を作れる。
struct LayoutEditorView: View {
    let record: RoomRecord
    let room: Room
    let furniture: [Furniture]
    let conditions: LayoutConditions
    let saveLabel: String
    let onSave: ([PlacedFurniture], Set<UUID>) -> Void

    @State private var items: [PlacedFurniture]
    @State private var pinned: Set<UUID>
    @State private var selectedID: UUID?
    @State private var savedNotice = false
    @State private var isShowingAR = false
    @State private var history = EditHistory<LayoutEditState>()
    @State private var pendingDrag: LayoutEditState?

    init(record: RoomRecord, room: Room, furniture: [Furniture], conditions: LayoutConditions,
         items: [PlacedFurniture], pinned: Set<UUID>, saveLabel: String,
         onSave: @escaping ([PlacedFurniture], Set<UUID>) -> Void) {
        self.record = record
        self.room = room
        self.furniture = furniture
        self.conditions = conditions
        self.saveLabel = saveLabel
        self.onSave = onSave
        _items = State(initialValue: items)
        _pinned = State(initialValue: pinned)
    }

    private var unplaced: [Furniture] {
        furniture.filter { f in !items.contains { $0.furniture.id == f.id } }
    }

    private var layout: MadoriCore.Layout {
        LayoutEvaluator(room: room, conditions: conditions).evaluate(items: items, unplaced: [])
    }

    private var selectedIndex: Int? {
        guard let id = selectedID else { return nil }
        return items.firstIndex { $0.furniture.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            EditableLayoutPlanView(
                room: room, items: $items, layout: layout, selectedID: $selectedID, pinnedIDs: pinned,
                onEditStart: { pendingDrag = editState },
                onEditEnd: {
                    // 動かさなかった（タップだけ）ときは、履歴に残さない。
                    if let before = pendingDrag, before != editState { history.record(before) }
                    pendingDrag = nil
                })
                .padding(.horizontal, 12)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    selectionControls
                    issuesList
                    unplacedList
                    regenerateLink
                    #if os(iOS)
                    if ARSupport.isAvailable {
                        Button("ARで実寸表示", systemImage: "arkit") { isShowingAR = true }
                            .buttonStyle(.bordered)
                    }
                    #endif
                }
                .padding(16)
            }
        }
        .navigationTitle("配置を直す")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("元に戻す", systemImage: "arrow.uturn.backward") { undo() }
                    .disabled(!history.canUndo)
                Button("やり直す", systemImage: "arrow.uturn.forward") { redo() }
                    .disabled(!history.canRedo)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveLabel) {
                    onSave(items, pinned)
                    savedNotice = true
                }
            }
        }
        .alert("保存しました", isPresented: $savedNotice) {
            Button("OK", role: .cancel) {}
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingAR) {
            ARPlacementScreen(room: room, items: items) { isShowingAR = false }
        }
        #endif
    }

    // MARK: 元に戻す・やり直す

    private var editState: LayoutEditState {
        LayoutEditState(items: items, pinned: pinned)
    }

    /// 変更する前に呼ぶ。今の状態を、履歴に残す。
    private func commit() {
        history.record(editState)
    }

    private func apply(_ state: LayoutEditState) {
        items = state.items
        pinned = state.pinned
        if let id = selectedID, !items.contains(where: { $0.furniture.id == id }) { selectedID = nil }
    }

    private func undo() {
        if let previous = history.undo(current: editState) { apply(previous) }
    }

    private func redo() {
        if let next = history.redo(current: editState) { apply(next) }
    }

    // MARK: 選んだ家具の操作

    @ViewBuilder
    private var selectionControls: some View {
        if let i = selectedIndex {
            let item = items[i]
            let id = item.furniture.id
            VStack(alignment: .leading, spacing: 8) {
                Text(item.furniture.name).font(.headline)
                Text(String(format: "%.0f × %.0f × %.0f cm・位置 (%.0f, %.0f)",
                            item.furniture.width, item.furniture.depth, item.furniture.height,
                            item.center.x, item.center.y))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("回転", systemImage: "rotate.right") {
                        commit()
                        items[i] = LayoutEditing.snapped(LayoutEditing.rotated(item), in: room)
                    }
                    Button(pinned.contains(id) ? "固定を解除" : "固定",
                           systemImage: pinned.contains(id) ? "pin.slash" : "pin") {
                        commit()
                        if pinned.contains(id) { pinned.remove(id) } else { pinned.insert(id) }
                    }
                    Button("外す", systemImage: "minus.circle", role: .destructive) {
                        commit()
                        items.remove(at: i)
                        pinned.remove(id)
                        selectedID = nil
                    }
                }
                .buttonStyle(.bordered)
                HStack(spacing: 12) {
                    Text("5cm ずつ").font(.footnote).foregroundStyle(.secondary)
                    nudge("arrow.left", dx: -5, dy: 0, index: i)
                    nudge("arrow.right", dx: 5, dy: 0, index: i)
                    nudge("arrow.up", dx: 0, dy: 5, index: i)
                    nudge("arrow.down", dx: 0, dy: -5, index: i)
                }
            }
        } else {
            Text("家具をタップして選び、ドラッグで動かします。壁に近づけると、ぴったり付きます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func nudge(_ symbol: String, dx: Double, dy: Double, index: Int) -> some View {
        Button {
            commit()
            items[index].center = Point(x: items[index].center.x + dx, y: items[index].center.y + dy)
        } label: {
            Image(systemName: symbol)
        }
        .buttonStyle(.bordered)
    }

    // MARK: 状態

    @ViewBuilder
    private var issuesList: some View {
        let issues = layout.issues
        if issues.isEmpty {
            Label("問題なし", systemImage: "checkmark.circle").foregroundStyle(.green)
        } else {
            ForEach(issues, id: \.self) { issue in
                Label(issue.message, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var unplacedList: some View {
        if !unplaced.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("まだ置いていない家具").font(.headline)
                ForEach(unplaced) { f in
                    HStack {
                        Text(f.name)
                        Spacer()
                        Button("部屋の中央に置く") {
                            commit()
                            items.append(LayoutEditing.placedAtCenter(f, in: room))
                            selectedID = f.id
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var regenerateLink: some View {
        VStack(alignment: .leading, spacing: 4) {
            NavigationLink {
                LayoutResultsView(record: record, room: room, furniture: furniture, conditions: conditions,
                                  fixed: items.filter { pinned.contains($0.furniture.id) })
            } label: {
                Label("固定した家具を残して、ほかを作り直す", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.bordered)
            .disabled(pinned.isEmpty)
            Text("家具を「固定」すると、その位置を保ったまま、ほかの家具の配置案を作れます。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
