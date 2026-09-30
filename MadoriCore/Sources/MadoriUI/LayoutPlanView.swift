import SwiftUI
import MadoriCore

/// 部屋と配置案を、上から見た図として描く。
public struct LayoutPlanView: View {
    public let room: Room
    public let layout: MadoriCore.Layout?
    public var showsClearance: Bool
    public var showsLabels: Bool
    public var selectedID: UUID?
    public var pinnedIDs: Set<UUID>
    /// 部屋の幅と奥行きの寸法を、外側に書く。
    public var showsDimensions: Bool

    public init(room: Room, layout: MadoriCore.Layout? = nil,
                showsClearance: Bool = true, showsLabels: Bool = true,
                selectedID: UUID? = nil, pinnedIDs: Set<UUID> = [], showsDimensions: Bool = false) {
        self.room = room
        self.layout = layout
        self.showsClearance = showsClearance
        self.showsLabels = showsLabels
        self.selectedID = selectedID
        self.pinnedIDs = pinnedIDs
        self.showsDimensions = showsDimensions
    }

    /// 図の周りの余白 (pt)。寸法を書くときは、文字の分だけ広げる。
    public static func padding(showsDimensions: Bool) -> CGFloat {
        showsDimensions ? 32 : 12
    }

    public var body: some View {
        let bounds = room.bounds
        Canvas { context, size in
            let t = PlanTransform(bounds: bounds, size: size, padding: Self.padding(showsDimensions: showsDimensions))
            drawRoom(&context, t)
            drawOpenings(&context, t)
            if showsDimensions { drawDimensions(&context, t) }
            if let layout {
                let problemIDs = Set(layout.issues.map(\.furnitureID))
                if showsClearance {
                    for item in layout.items { drawClearance(&context, t, item) }
                }
                for item in layout.items {
                    drawFurniture(&context, t, item, hasProblem: problemIDs.contains(item.furniture.id),
                                  isSelected: item.furniture.id == selectedID,
                                  isPinned: pinnedIDs.contains(item.furniture.id))
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
        context.fill(path, with: .color(Color(red: 1.0, green: 0.93, blue: 0.84).opacity(0.75)))
        context.stroke(path, with: .color(Color(red: 0.60, green: 0.45, blue: 0.40)), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
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

    private func drawDimensions(_ context: inout GraphicsContext, _ t: PlanTransform) {
        let b = room.bounds
        let secondary = Color.secondary
        let bottom = t.point(Point(x: b.center.x, y: b.minY))
        context.draw(Text("\(Int(b.width)) cm").font(.system(size: 12)).foregroundStyle(secondary),
                     at: CGPoint(x: bottom.x, y: bottom.y + 18))
        let left = t.point(Point(x: b.minX, y: b.center.y))
        var rotated = context
        rotated.translateBy(x: left.x - 18, y: left.y)
        rotated.rotate(by: .degrees(-90))
        rotated.draw(Text("\(Int(b.height)) cm").font(.system(size: 12)).foregroundStyle(secondary), at: .zero)
    }

    private func drawFurniture(_ context: inout GraphicsContext, _ t: PlanTransform,
                               _ item: PlacedFurniture, hasProblem: Bool,
                               isSelected: Bool = false, isPinned: Bool = false) {
        let color = hasProblem ? Color.red : Palette.color(for: item.furniture.category)
        let rect = t.rect(item.footprint)
        let body = Path(roundedRect: rect, cornerRadius: 3)
        context.fill(body, with: .color(color.opacity(0.35)))
        context.stroke(body, with: .color(color), style: StrokeStyle(lineWidth: 1.5))
        if isSelected {
            context.stroke(Path(roundedRect: rect.insetBy(dx: -3, dy: -3), cornerRadius: 5),
                           with: .color(.accentColor), style: StrokeStyle(lineWidth: 3))
        }
        if isPinned {
            context.draw(Image(systemName: "pin.fill"), at: CGPoint(x: rect.maxX - 8, y: rect.minY + 8))
        }

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
    /// 3D のモデルと同じ色にそろえる。
    static func color(for category: FurnitureCategory) -> Color {
        let c = RoomSceneBuilder.categoryColor(category)
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}
