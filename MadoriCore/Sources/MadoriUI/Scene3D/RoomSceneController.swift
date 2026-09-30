import SceneKit
import SwiftUI
import MadoriCore

/// 3D 上の印を、画面上のどこに描くか。
struct ProjectedHandle: Identifiable, Equatable {
    var id: HandleKind
    var position: CGPoint
    /// 動かす向きに 1cm 進むと、画面上でどれだけ動くか。
    var pxPerCM: CGVector
}

/// 3D のシーン（部屋・照明・カメラ）を持ち、内容の更新と、印の画面位置の計算を受け持つ。
public final class RoomSceneController: NSObject, ObservableObject, SCNSceneRendererDelegate {
    public let scene = SCNScene()
    public let cameraNode = SCNNode()
    private let content = SCNNode()
    private var didFrame = false
    /// 部屋の中心が原点に来るように、最初に決めた位置。動かしている間は変えない。
    private var offset = (x: 0.0, z: 0.0)

    private let lock = NSLock()
    private var anchors: [(kind: HandleKind, point: SCNVector3, axis: SCNVector3)] = []
    private var lastHandles: [ProjectedHandle] = []
    @Published var handles: [ProjectedHandle] = []

    public override init() {
        super.init()
        scene.background.contents = CGColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1)
        scene.rootNode.addChildNode(content)

        let camera = SCNCamera()
        camera.fieldOfView = 45
        camera.zNear = 10
        camera.zFar = 100_000
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 700
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 800
        sun.eulerAngles = SCNVector3(x: SCNFloat(-0.9), y: SCNFloat(0.5), z: 0)
        scene.rootNode.addChildNode(sun)
    }

    func update(room: Room, items: [PlacedFurniture] = [], specs: [HandleSpec] = []) {
        content.childNodes.forEach { $0.removeFromParentNode() }
        if !didFrame {
            resetCamera(room: room)
            didFrame = true
        }
        content.addChildNode(RoomSceneBuilder.contentNode(room: room, items: items))
        lock.lock()
        anchors = specs.map { spec in
            (spec.kind,
             SCNVector3(x: SCNFloat(spec.plan.x + offset.x), y: SCNFloat(spec.elevation),
                        z: SCNFloat(-spec.plan.y + offset.z)),
             SCNVector3(x: SCNFloat(spec.axis.x), y: SCNFloat(spec.axis.y), z: SCNFloat(spec.axis.z)))
        }
        lock.unlock()
        if specs.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.handles = [] }
        }
    }

    /// 部屋全体が見える位置にカメラを戻す。
    func resetCamera(room: Room) {
        let b = room.bounds
        offset = (-b.center.x, b.center.y)
        content.position = SCNVector3(x: SCNFloat(offset.x), y: 0, z: SCNFloat(offset.z))
        let distance = max(b.width, b.height) * 1.3 + 150
        let target = SCNVector3(x: 0, y: SCNFloat(room.ceilingHeight * 0.3), z: 0)
        cameraNode.position = SCNVector3(x: SCNFloat(distance * 0.45), y: SCNFloat(distance * 0.85),
                                         z: SCNFloat(distance * 0.9))
        cameraNode.look(at: target)
    }

    // MARK: SCNSceneRendererDelegate

    /// 描画のたびに、印の画面上の位置を求める。
    public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
        lock.lock()
        let current = anchors
        lock.unlock()
        guard !current.isEmpty else { return }

        var result: [ProjectedHandle] = []
        for a in current {
            let p0 = renderer.projectPoint(a.point)
            let p1 = renderer.projectPoint(SCNVector3(x: a.point.x + a.axis.x * 100,
                                                      y: a.point.y + a.axis.y * 100,
                                                      z: a.point.z + a.axis.z * 100))
            result.append(ProjectedHandle(
                id: a.kind,
                position: CGPoint(x: CGFloat(p0.x), y: CGFloat(p0.y)),
                pxPerCM: CGVector(dx: CGFloat(p1.x - p0.x) / 100, dy: CGFloat(p1.y - p0.y) / 100)))
        }
        guard !Self.isSame(result, lastHandles) else { return }
        lastHandles = result
        DispatchQueue.main.async { [weak self] in self?.handles = result }
    }

    private static func isSame(_ a: [ProjectedHandle], _ b: [ProjectedHandle]) -> Bool {
        guard a.count == b.count else { return false }
        for (x, y) in zip(a, b) {
            if x.id != y.id || abs(x.position.x - y.position.x) > 0.5 || abs(x.position.y - y.position.y) > 0.5
                || abs(x.pxPerCM.dx - y.pxPerCM.dx) > 0.01 || abs(x.pxPerCM.dy - y.pxPerCM.dy) > 0.01 {
                return false
            }
        }
        return true
    }
}
