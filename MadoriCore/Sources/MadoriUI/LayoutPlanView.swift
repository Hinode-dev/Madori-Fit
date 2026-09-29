import SwiftUI
import MadoriCore

/// 部屋と配置案を、上から見た図として描く。
public struct LayoutPlanView: View {
    public let room: Room
    public let layout: MadoriCore.Layout?
    public var showsClearance: Bool
    public var showsLabels: Bool

    public init(room: Room, layout: MadoriCore.Layout? = nil,
                showsClearance: Bool = true, showsLabels: Bool = true) {
        self.room = room
        self.layout = layout
        self.showsClearance = showsClearance
        self.showsLabels = showsLabels
    }

    public var body: some View {
        let bounds = room.bounds
        Canvas { context, size in
            let t = PlanTransform(bounds: bounds, size: size, padding: 12)
            drawRoom(&context, t)
            drawOpenings(&context, t)
            if let layout {
                let problemIDs = Set(layout.issues.map(\.furnitureID))
                if showsClearance {
                    for item in layout.items { drawClearance(&context, t, item) }
                }
                for item in layout.items {
                    drawFurniture(&context, t, item, hasProblem: problemIDs.contains(item.furniture.id))
                }
            }
        }
        .aspectRatio(max(bounds.width, 1) / max(bounds.height, 1), contentMode: .fit)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        guard let layout else { return "\(room.name) の間取り" }
        let names = layout.items.map(\.furniture.name).joined(separator: "、")
        return "\(room.name) の配置案。\(names)"
    }

    // MARK: 描画

    private func drawRoom(_ context: inout GraphicsContext, _ t: PlanTransform) {
        guard let first = room.corners.first else { return }
        var path = Path()
        path.move(to: t.point(first))
        for c in room.corners.dropFirst() { path.addLine(to: t.point(c)) }
        path.closeSubpath()
        context.fill(path, with: .color(.gray.opacity(0.12)))
        context.stroke(path, with: .color(.primary.opacity(0.8)), style: StrokeStyle(lineWidth: 3, lineJoin: .miter))
    }

    private func drawOpenings(_ context: inout GraphicsContext, _ t: PlanTransform) {
        for opening in room.openings {
            let span = room.span(of: opening)
            var line = Path()
            line.move(to: t.point(span.start))
            line.addLine(to: t.point(span.end))
            switch opening.kind {
            case .door:
                let zone = Path(t.rect(room.zone(for: opening)))
                context.fill(zone, with: .color(.orange.opacity(0.15)))
                context.stroke(zone, with: .color(.orange.opacity(0.6)),
                               style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                context.stroke(line, with: .color(.orange), style: StrokeStyle(lineWidth: 5, lineCap: .butt))
            case .window:
                context.stroke(line, with: .color(.cyan), style: StrokeStyle(lineWidth: 5, lineCap: .butt))
            }
        }
    }

    private func drawClearance(_ context: inout GraphicsContext, _ t: PlanTransform, _ item: PlacedFurniture) {
        guard item.clearanceZone.area > 0 else { return }
        let path = Path(t.rect(item.clearanceZone))
        context.fill(path, with: .color(Palette.color(for: item.furniture.category).opacity(0.10)))
        context.stroke(path, with: .color(Palette.color(for: item.furniture.category).opacity(0.5)),
                       style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
    }

    private func drawFurniture(_ context: inout GraphicsContext, _ t: PlanTransform,
                               _ item: PlacedFurniture, hasProblem: Bool) {
        let color = hasProblem ? Color.red : Palette.color(for: item.furniture.category)
        let rect = t.rect(item.footprint)
        let body = Path(roundedRect: rect, cornerRadius: 3)
        context.fill(body, with: .color(color.opacity(0.35)))
        context.stroke(body, with: .color(color), style: StrokeStyle(lineWidth: 1.5))

        // 正面を示す三角形。
        let f = item.frontDirection
        let dir = CGPoint(x: f.x, y: -f.y)
        let perp = CGPoint(x: -dir.y, y: dir.x)
        let base = t.point(item.frontFaceCenter)
        var arrow = Path()
        arrow.move(to: CGPoint(x: base.x + dir.x * 8, y: base.y + dir.y * 8))
        arrow.addLine(to: CGPoint(x: base.x + perp.x * 5, y: base.y + perp.y * 5))
        arrow.addLine(to: CGPoint(x: base.x - perp.x * 5, y: base.y - perp.y * 5))
        arrow.closeSubpath()
        context.fill(arrow, with: .color(color))

        if showsLabels {
            let fontSize: CGFloat = min(rect.width, rect.height) < 36 ? 8 : 11
            let label = Text(item.furniture.name).font(.system(size: fontSize)).foregroundStyle(Color.primary)
            context.draw(label, at: CGPoint(x: rect.midX, y: rect.midY))
        }
    }
}

enum Palette {
    static func color(for category: FurnitureCategory) -> Color {
        switch category {
        case .bed: return .indigo
        case .sofa: return .teal
        case .table: return .brown
        case .desk: return .blue
        case .storage: return .green
        case .tv: return .purple
        case .appliance: return .gray
        case .other: return .pink
        }
    }
}
