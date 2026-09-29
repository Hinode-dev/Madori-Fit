import SceneKit
import SwiftUI
import MadoriCore

/// 部屋を 3D で見ながら、印をつかんで幅・奥行き・高さ・ドアと窓の位置を直接動かす。
/// 指 1 本で回転、2 本で拡大縮小・移動。
struct RoomEditor3DView: View {
    @Binding var draft: RoomDraft
    @StateObject private var controller = RoomSceneController()
    @State private var drags: [HandleKind: (start: Double, pxPerCM: CGVector)] = [:]

    var body: some View {
        ZStack {
            SceneView(scene: controller.scene, pointOfView: controller.cameraNode,
                      options: [.allowsCameraControl], delegate: controller)
            ForEach(controller.handles) { handle in
                handleView(handle)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("視点をリセット", systemImage: "arrow.counterclockwise") {
                controller.resetCamera(room: draft.makeRoom())
            }
            .labelStyle(.iconOnly)
            .padding(8)
        }
        .onAppear { refresh() }
        .onChange(of: draft) { _, _ in refresh() }
        .clipped()
    }

    private func refresh() {
        controller.update(room: draft.makeRoom(), specs: RoomHandles.specs(for: draft))
    }

    private func handleView(_ handle: ProjectedHandle) -> some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(color(for: handle.id), lineWidth: 3))
                .shadow(radius: 2)
            Text(RoomHandles.label(for: handle.id, in: draft))
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .offset(y: -24)
                .allowsHitTesting(false)
        }
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    if drags[handle.id] == nil, let start = RoomHandles.value(of: handle.id, in: draft) {
                        drags[handle.id] = (start, handle.pxPerCM)
                    }
                    guard let state = drags[handle.id],
                          let value = RoomHandles.dragValue(start: state.start, translation: drag.translation,
                                                            pxPerCM: state.pxPerCM) else { return }
                    RoomHandles.apply(handle.id, value: value, to: &draft)
                }
                .onEnded { _ in drags[handle.id] = nil }
        )
        .position(handle.position)
        .accessibilityLabel(RoomHandles.label(for: handle.id, in: draft))
    }

    private func color(for kind: HandleKind) -> Color {
        switch kind {
        case .width, .depth: return .blue
        case .height: return .green
        case .opening: return .orange
        }
    }
}

/// 配置案を 3D で見る（操作は回転と拡大縮小のみ）。
public struct Layout3DView: View {
    public let room: Room
    public let layout: MadoriCore.Layout?
    @StateObject private var controller = RoomSceneController()

    public init(room: Room, layout: MadoriCore.Layout? = nil) {
        self.room = room
        self.layout = layout
    }

    public var body: some View {
        SceneView(scene: controller.scene, pointOfView: controller.cameraNode,
                  options: [.allowsCameraControl])
            .onAppear { controller.update(room: room, items: layout?.items ?? []) }
            .clipped()
    }
}
