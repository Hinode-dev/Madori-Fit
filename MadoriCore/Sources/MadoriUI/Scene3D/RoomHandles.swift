import CoreGraphics
import Foundation
import MadoriCore

/// 3D 表示の上に出す、つかんで動かせる印の種類。
enum HandleKind: Hashable {
    case width
    case depth
    case height
    case opening(UUID)
}

struct Axis3: Equatable {
    var x: Double
    var y: Double
    var z: Double
}

/// 印の位置と、動かす向き。座標は平面図のもの (cm、y が奥) と、床からの高さ。
struct HandleSpec: Equatable {
    var kind: HandleKind
    var plan: Point
    var elevation: Double
    /// 3D シーンでの動かす向き (x が右、y が上、z が手前)。
    var axis: Axis3
}

/// 手入力の下書きと、3D 上の印との対応。画面の外に出して、単体でテストできるようにしている。
enum RoomHandles {
    static let step = 5.0
    static let heightRange: ClosedRange<Double> = 200...400

    static func specs(for draft: RoomDraft) -> [HandleSpec] {
        let w = draft.width
        let d = draft.depth
        var result = [
            HandleSpec(kind: .width, plan: Point(x: w, y: d / 2), elevation: 10, axis: Axis3(x: 1, y: 0, z: 0)),
            HandleSpec(kind: .depth, plan: Point(x: w / 2, y: d), elevation: 10, axis: Axis3(x: 0, y: 0, z: -1)),
            HandleSpec(kind: .height, plan: Point(x: w, y: d), elevation: draft.ceilingHeight,
                       axis: Axis3(x: 0, y: 1, z: 0))
        ]
        for o in draft.openings {
            let center = o.offset + o.width / 2
            let plan: Point
            let axis: Axis3
            switch o.side {
            case .south:
                plan = Point(x: center, y: 0)
                axis = Axis3(x: 1, y: 0, z: 0)
            case .north:
                plan = Point(x: center, y: d)
                axis = Axis3(x: 1, y: 0, z: 0)
            case .east:
                plan = Point(x: w, y: center)
                axis = Axis3(x: 0, y: 0, z: -1)
            case .west:
                plan = Point(x: 0, y: center)
                axis = Axis3(x: 0, y: 0, z: -1)
            }
            let elevation = o.kind == .window ? o.sillHeight + 55 : 100
            result.append(HandleSpec(kind: .opening(o.id), plan: plan, elevation: elevation, axis: axis))
        }
        return result
    }

    /// 印が今動かしている値 (cm)。
    static func value(of kind: HandleKind, in draft: RoomDraft) -> Double? {
        switch kind {
        case .width: return draft.width
        case .depth: return draft.depth
        case .height: return draft.ceilingHeight
        case .opening(let id): return draft.openings.first { $0.id == id }?.offset
        }
    }

    /// 動かし始めの値と、画面上の移動量から、新しい値 (cm) を求める。
    /// `pxPerCM` は、動かす向きに 1cm 進むと画面上でどれだけ動くか。
    static func dragValue(start: Double, translation: CGSize, pxPerCM: CGVector) -> Double? {
        let lengthSquared = Double(pxPerCM.dx * pxPerCM.dx + pxPerCM.dy * pxPerCM.dy)
        guard lengthSquared > 1e-6 else { return nil }
        let along = Double(translation.width * pxPerCM.dx + translation.height * pxPerCM.dy)
        return start + along / lengthSquared
    }

    static func snapped(_ value: Double) -> Double {
        (value / step).rounded() * step
    }

    /// 値を範囲に収めて、下書きに反映する。
    static func apply(_ kind: HandleKind, value: Double, to draft: inout RoomDraft) {
        let v = snapped(value)
        switch kind {
        case .width:
            draft.width = min(max(v, RoomDraft.sizeRange.lowerBound), RoomDraft.sizeRange.upperBound)
        case .depth:
            draft.depth = min(max(v, RoomDraft.sizeRange.lowerBound), RoomDraft.sizeRange.upperBound)
        case .height:
            draft.ceilingHeight = min(max(v, heightRange.lowerBound), heightRange.upperBound)
        case .opening(let id):
            guard let i = draft.openings.firstIndex(where: { $0.id == id }) else { return }
            let room = draft.wallLength(of: draft.openings[i].side)
            draft.openings[i].offset = min(max(v, 0), max(room - draft.openings[i].width, 0))
        }
    }

    static func label(for kind: HandleKind, in draft: RoomDraft) -> String {
        switch kind {
        case .width: return "幅 \(Int(draft.width)) cm"
        case .depth: return "奥行き \(Int(draft.depth)) cm"
        case .height: return "高さ \(Int(draft.ceilingHeight)) cm"
        case .opening(let id):
            guard let o = draft.openings.first(where: { $0.id == id }) else { return "" }
            return "\(o.kind == .door ? "ドア" : "窓") \(Int(o.offset)) cm"
        }
    }
}
