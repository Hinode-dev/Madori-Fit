#if os(iOS)
import ARKit
import SceneKit
import SwiftUI
import UIKit
import MadoriCore

/// この端末で AR が使えるか。
public enum ARSupport {
    public static var isAvailable: Bool { ARWorldTrackingConfiguration.isSupported }
}

/// AR で見るもの。
enum ARContent {
    /// 配置案。実際の部屋の隅を 2 か所タップして、間取りと合わせる。
    case layout(Room, [PlacedFurniture])
    /// 家具 1 つ。床をタップして置く。
    case furniture(Furniture)
}

/// カメラの映像に、家具を実寸で重ねる。
public struct ARPlacementScreen: View {
    private let onClose: () -> Void
    private let room: Room?
    @StateObject private var model: ARPlacementModel

    /// 配置案を、実際の部屋に重ねる。
    public init(room: Room, items: [PlacedFurniture], onClose: @escaping () -> Void) {
        self.room = room
        self.onClose = onClose
        _model = StateObject(wrappedValue: ARPlacementModel(content: .layout(room, items)))
    }

    /// 家具 1 つを、実寸で置いてみる。
    public init(furniture: Furniture, onClose: @escaping () -> Void) {
        self.room = nil
        self.onClose = onClose
        _model = StateObject(wrappedValue: ARPlacementModel(content: .furniture(furniture)))
    }

    public var body: some View {
        ZStack {
            ARSceneView(model: model).ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Button("閉じる", systemImage: "xmark.circle.fill", action: onClose)
                        .labelStyle(.iconOnly)
                        .font(.title)
                        .foregroundStyle(.white, .black.opacity(0.5))
                    Spacer()
                    if let room, model.step == .pickOrigin || model.step == .pickDirection {
                        LayoutPlanView(room: room, showsClearance: false, showsLabels: false)
                            .frame(width: 120)
                            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                Text(model.hint)
                    .font(.callout.bold())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.65), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                controls
            }
            .padding()
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.step {
        case .aligned:
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    control("arrow.counterclockwise", "左回り") { model.rotate(degrees: 1) }
                    control("arrow.clockwise", "右回り") { model.rotate(degrees: -1) }
                    control("arrow.left", "左へ") { model.nudge(dx: -2, dy: 0) }
                    control("arrow.right", "右へ") { model.nudge(dx: 2, dy: 0) }
                    control("arrow.up", "奥へ") { model.nudge(dx: 0, dy: 2) }
                    control("arrow.down", "手前へ") { model.nudge(dx: 0, dy: -2) }
                }
                Button("合わせ直す", systemImage: "arrow.uturn.backward") { model.reset() }
                    .buttonStyle(.borderedProminent)
            }
        case .furniturePlaced:
            HStack(spacing: 12) {
                Button("90°回す", systemImage: "rotate.right") { model.rotateFurniture() }
                    .buttonStyle(.borderedProminent)
                Button("置き直す", systemImage: "arrow.uturn.backward") { model.reset() }
                    .buttonStyle(.bordered)
            }
        default:
            EmptyView()
        }
    }

    private func control(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.6), in: Circle())
                .foregroundStyle(.white)
        }
        .accessibilityLabel(label)
    }
}

/// AR の操作の状態と、置いたものの管理。
final class ARPlacementModel: ObservableObject {
    enum Step {
        case pickOrigin, pickDirection, aligned
        case placeFurniture, furniturePlaced
    }

    let content: ARContent
    @Published var step: Step
    @Published var hint: String
    weak var view: ARSCNView?

    private var originPoint: SCNVector3?
    private var markers: [SCNNode] = []
    private var placedNode: SCNNode?

    init(content: ARContent) {
        self.content = content
        switch content {
        case .layout:
            step = .pickOrigin
            hint = "床を映してゆっくり動かし、図の左下の角の床をタップしてください"
        case .furniture:
            step = .placeFurniture
            hint = "床を映してゆっくり動かし、置きたい場所をタップしてください"
        }
    }

    func handleTap(_ point: CGPoint) {
        guard let view, let position = floorPosition(at: point, in: view) else {
            hint = "床が見つかりません。カメラをゆっくり動かして、床を映してください"
            return
        }
        switch (content, step) {
        case (.layout, .pickOrigin):
            originPoint = position
            addMarker(at: position, color: .green, in: view)
            step = .pickDirection
            hint = "次に、図の右下の角（同じ壁に沿った、離れた場所）の床をタップしてください"
        case (.layout(let room, let items), .pickDirection):
            guard let origin = originPoint else { return }
            let dx = position.x - origin.x
            let dz = position.z - origin.z
            guard hypot(dx, dz) > 0.3 else {
                hint = "1 か所目から、もう少し離れた場所をタップしてください"
                return
            }
            buildLayout(room: room, items: items, origin: origin, yaw: atan2(-dz, dx), in: view)
        case (.furniture(let furniture), .placeFurniture), (.furniture(let furniture), .furniturePlaced):
            placeFurniture(furniture, at: position, in: view)
        default:
            break
        }
    }

    /// 合わせ位置を、間取りの座標 (cm) の向きに、少しずらす。
    func nudge(dx: Float, dy: Float) {
        guard let node = placedNode else { return }
        let yaw = node.eulerAngles.y
        // 間取りの x は、ノードの +x。間取りの y は、ノードの -z。
        node.position.x += (dx * cos(yaw) - dy * sin(yaw)) * 0.01
        node.position.z += (-dx * sin(yaw) - dy * cos(yaw)) * 0.01
    }

    func rotate(degrees: Float) {
        placedNode?.eulerAngles.y += degrees * .pi / 180
    }

    func rotateFurniture() {
        placedNode?.eulerAngles.y += .pi / 2
    }

    func reset() {
        placedNode?.removeFromParentNode()
        placedNode = nil
        markers.forEach { $0.removeFromParentNode() }
        markers = []
        originPoint = nil
        switch content {
        case .layout:
            step = .pickOrigin
            hint = "図の左下の角の床をタップしてください"
        case .furniture:
            step = .placeFurniture
            hint = "置きたい場所をタップしてください"
        }
    }

    // MARK: 配置

    private func floorPosition(at point: CGPoint, in view: ARSCNView) -> SCNVector3? {
        guard let query = view.raycastQuery(from: point, allowing: .estimatedPlane, alignment: .horizontal),
              let result = view.session.raycast(query).first else { return nil }
        let c = result.worldTransform.columns.3
        return SCNVector3(c.x, c.y, c.z)
    }

    private func addMarker(at position: SCNVector3, color: UIColor, in view: ARSCNView) {
        let sphere = SCNSphere(radius: 0.03)
        sphere.firstMaterial?.diffuse.contents = color
        let node = SCNNode(geometry: sphere)
        node.position = position
        view.scene.rootNode.addChildNode(node)
        markers.append(node)
    }

    private func buildLayout(room: Room, items: [PlacedFurniture], origin: SCNVector3, yaw: Float,
                             in view: ARSCNView) {
        let anchor = SCNNode()
        anchor.name = "arLayout"
        anchor.position = origin
        anchor.eulerAngles.y = yaw

        // モデルは cm、AR は m。図の左下の角が、1 か所目のタップの位置になるようにずらす。
        let b = room.bounds
        let content = RoomSceneBuilder.contentNode(room: room, items: items, includesShell: false)
        content.scale = SCNVector3(0.01, 0.01, 0.01)
        content.position = SCNVector3(Float(-b.minX * 0.01), 0, Float(b.minY * 0.01))
        anchor.addChildNode(content)
        view.scene.rootNode.addChildNode(anchor)

        markers.forEach { $0.removeFromParentNode() }
        markers = []
        placedNode = anchor
        step = .aligned
        hint = "家具が実寸で重なっています。ずれていたら、下のボタンで合わせてください"
    }

    private func placeFurniture(_ furniture: Furniture, at position: SCNVector3, in view: ARSCNView) {
        if placedNode == nil {
            let placed = PlacedFurniture(furniture: furniture, center: Point(x: 0, y: 0), quarterTurns: 0)
            let node = FurnitureModelBuilder.node(for: placed)
            node.scale = SCNVector3(0.01, 0.01, 0.01)
            view.scene.rootNode.addChildNode(node)
            placedNode = node
        }
        placedNode?.position = position
        step = .furniturePlaced
        hint = String(format: "%@（%.0f × %.0f × %.0f cm）タップで移動できます",
                      furniture.name, furniture.width, furniture.depth, furniture.height)
    }
}

/// AR のカメラ映像を出し、タップを `ARPlacementModel` に渡す。
struct ARSceneView: UIViewRepresentable {
    let model: ARPlacementModel

    func makeCoordinator() -> ARTapCoordinator {
        ARTapCoordinator(model: model)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.autoenablesDefaultLighting = true
        view.automaticallyUpdatesLighting = true
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        view.session.run(configuration)
        model.view = view
        view.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator,
                                                         action: #selector(ARTapCoordinator.tapped(_:))))
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ARTapCoordinator) {
        uiView.session.pause()
    }
}

final class ARTapCoordinator: NSObject {
    private let model: ARPlacementModel

    init(model: ARPlacementModel) {
        self.model = model
    }

    @objc func tapped(_ gesture: UITapGestureRecognizer) {
        model.handleTap(gesture.location(in: gesture.view))
    }
}
#endif
