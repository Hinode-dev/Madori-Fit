import SwiftUI
import MadoriCore

/// 間取りの座標 (cm, y 上向き) を、画面の座標 (pt, y 下向き) へ変換する。
/// 描画領域の中央に、縦横比を保って収める。
struct PlanTransform {
    let bounds: Rect
    let scale: CGFloat
    let origin: CGPoint

    init(bounds: Rect, size: CGSize, padding: CGFloat) {
        self.bounds = bounds
        let bw = max(bounds.width, 1)
        let bh = max(bounds.height, 1)
        let s = min((size.width - 2 * padding) / bw, (size.height - 2 * padding) / bh)
        scale = max(s, 0.01)
        origin = CGPoint(x: (size.width - bw * scale) / 2, y: (size.height - bh * scale) / 2)
    }

    func point(_ p: Point) -> CGPoint {
        CGPoint(x: origin.x + (p.x - bounds.minX) * scale,
                y: origin.y + (bounds.maxY - p.y) * scale)
    }

    func rect(_ r: Rect) -> CGRect {
        let topLeft = point(Point(x: r.minX, y: r.maxY))
        return CGRect(x: topLeft.x, y: topLeft.y, width: r.width * scale, height: r.height * scale)
    }
}
