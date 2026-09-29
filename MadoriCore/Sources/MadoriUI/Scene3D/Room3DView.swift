import SceneKit
import SwiftUI
import MadoriCore

/// 部屋を 3D で見る。ドアと窓には名前のラベルを付け、タップできる。
/// 指 1 本で回転、2 本で拡大縮小・移動。
public struct Room3DView: View {
    public let room: Room
    public let items: [PlacedFurniture]
    public let onSelectOpening: ((Opening) -> Void)?
    @StateObject private var controller = RoomSceneController()

    public init(room: Room, items: [PlacedFurniture] = [],
                onSelectOpening: ((Opening) -> Void)? = nil) {
        self.room = room
        self.items = items
        self.onSelectOpening = onSelectOpening
    }

    public var body: some View {
        ZStack {
            SceneView(scene: controller.scene, pointOfView: controller.cameraNode,
                      options: [.allowsCameraControl], delegate: controller)
            ForEach(controller.handles) { handle in
                if case .opening(let id) = handle.id, let opening = room.openings.first(where: { $0.id == id }) {
                    badge(opening)
                        .position(handle.position)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("視点をリセット", systemImage: "arrow.counterclockwise") {
                controller.resetCamera(room: room)
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
        .onAppear { refresh() }
        .onChange(of: room) { _, _ in refresh() }
        .clipped()
    }

    private func refresh() {
        controller.update(room: room, items: items, specs: RoomHandles.labelSpecs(for: room))
    }

    private func badge(_ opening: Opening) -> some View {
        let isDoor = opening.kind == .door
        return Button {
            onSelectOpening?(opening)
        } label: {
            Label("\(isDoor ? "ドア" : "窓") \(Int(opening.width))",
                  systemImage: isDoor ? "door.left.hand.closed" : "window.horizontal")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isDoor ? Color.orange : Color.cyan, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(onSelectOpening == nil)
    }
}
