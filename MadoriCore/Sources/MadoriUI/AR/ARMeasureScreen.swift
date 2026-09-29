#if os(iOS)
import ARKit
import SceneKit
import SwiftUI
import UIKit

/// カメラ越しに、2 点の間の距離を測る。
///
/// 画面中央の十字を、測りたい場所に合わせて「＋」を押す。1 点目を置くと、
/// 十字までの距離が、リアルタイムに出る。2 点目を置くと確定し、「この値を使う」で値を返す。
public struct ARMeasureScreen: View {
    private let title: String
    private let onResult: (Double) -> Void
    private let onClose: () -> Void
    @StateObject private var model = ARMeasureModel()

    /// - Parameters:
    ///   - title: 何を測るか（例: 「幅 (cm)」）。
    ///   - onResult: 測った距離 (cm、整数に丸めたもの)。
    public init(title: String, onResult: @escaping (Double) -> Void, onClose: @escaping () -> Void) {
        self.title = title
        self.onResult = onResult
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            ARMeasureSceneView(model: model).ignoresSafeArea()
            Image(systemName: "plus")
                .font(.system(size: 34, weight: .thin))
                .foregroundStyle(.white)
                .shadow(color: .black, radius: 2)
                .allowsHitTesting(false)
            VStack(spacing: 12) {
                HStack(alignment: .top) {
                    Button("閉じる", systemImage: "xmark.circle.fill", action: onClose)
                        .labelStyle(.iconOnly)
                        .font(.title)
                        .foregroundStyle(.white, .black.opacity(0.5))
                    Spacer()
                }
                Text("「\(title)」を測ります")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(model.hint)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.65), in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                if let cm = model.finalCM ?? model.liveCM {
                    Text(String(format: "%.1f cm", cm))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(model.finalCM == nil ? Color.yellow : Color.green)
                }
                HStack(spacing: 20) {
                    Button("やり直す") { model.reset() }
                        .buttonStyle(.bordered)
                        .tint(.white)
                    Button {
                        model.addPoint()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.white, .blue)
                    }
                    .accessibilityLabel("点を置く")
                    Button("この値を使う") {
                        if let cm = model.finalCM { onResult(cm.rounded()) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.finalCM == nil)
                }
            }
            .padding()
        }
    }
}

final class ARMeasureModel: ObservableObject {
    @Published var hint = "測りたい場所に十字を合わせて、＋を押してください（1 点目）"
    /// 1 点目から、十字までの距離 (cm)。
    @Published var liveCM: Double?
    /// 2 点が決まったときの距離 (cm)。
    @Published var finalCM: Double?

    weak var view: ARSCNView?
    private var points: [SCNVector3] = []
    private var fixedNodes: [SCNNode] = []
    private var previewLine: SCNNode?
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func addPoint() {
        guard let hit = centerHit() else {
            hint = "面が見つかりません。カメラをゆっくり動かして、測りたい場所を映してください"
            return
        }
        if points.count >= 2 { reset() }
        points.append(hit)
        addMarker(at: hit)
        if points.count == 1 {
            hint = "もう 1 点に十字を合わせて、＋を押してください"
        } else {
            previewLine?.removeFromParentNode()
            previewLine = nil
            liveCM = nil
            finalCM = Double(Self.distance(points[0], points[1])) * 100
            fixedNodes.append(lineNode(from: points[0], to: points[1], color: .systemGreen))
            view?.scene.rootNode.addChildNode(fixedNodes.last!)
            hint = "測れました。違っていたら「やり直す」を押してください"
        }
    }

    func reset() {
        points = []
        fixedNodes.forEach { $0.removeFromParentNode() }
        fixedNodes = []
        previewLine?.removeFromParentNode()
        previewLine = nil
        liveCM = nil
        finalCM = nil
        hint = "測りたい場所に十字を合わせて、＋を押してください（1 点目）"
    }

    // MARK: 内部

    /// 1 点目があるとき、十字までの距離と、仮の線を更新する。
    private func tick() {
        guard points.count == 1, let hit = centerHit() else { return }
        liveCM = Double(Self.distance(points[0], hit)) * 100
        previewLine?.removeFromParentNode()
        let line = lineNode(from: points[0], to: hit, color: .systemYellow)
        view?.scene.rootNode.addChildNode(line)
        previewLine = line
    }

    /// 画面の中央にある、面までの位置。LiDAR があれば、メッシュにも当たる。
    private func centerHit() -> SCNVector3? {
        guard let view else { return nil }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        for target in [ARRaycastQuery.Target.existingPlaneGeometry, .estimatedPlane] {
            if let query = view.raycastQuery(from: center, allowing: target, alignment: .any),
               let result = view.session.raycast(query).first {
                let c = result.worldTransform.columns.3
                return SCNVector3(c.x, c.y, c.z)
            }
        }
        return nil
    }

    private func addMarker(at position: SCNVector3) {
        let sphere = SCNSphere(radius: 0.008)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemGreen
        let node = SCNNode(geometry: sphere)
        node.position = position
        view?.scene.rootNode.addChildNode(node)
        fixedNodes.append(node)
    }

    private func lineNode(from a: SCNVector3, to b: SCNVector3, color: UIColor) -> SCNNode {
        let box = SCNBox(width: 0.004, height: 0.004, length: CGFloat(Self.distance(a, b)), chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = color
        let node = SCNNode(geometry: box)
        node.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        node.look(at: b)
        return node
    }

    static func distance(_ a: SCNVector3, _ b: SCNVector3) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }
}

struct ARMeasureSceneView: UIViewRepresentable {
    let model: ARMeasureModel

    func makeCoordinator() -> ARMeasureCoordinator {
        ARMeasureCoordinator(model: model)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.autoenablesDefaultLighting = true
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        view.session.run(configuration)
        model.view = view
        model.start()
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {}

    static func dismantleUIView(_ uiView: ARSCNView, coordinator: ARMeasureCoordinator) {
        coordinator.model.stop()
        uiView.session.pause()
    }
}

final class ARMeasureCoordinator {
    let model: ARMeasureModel

    init(model: ARMeasureModel) {
        self.model = model
    }
}
#endif
