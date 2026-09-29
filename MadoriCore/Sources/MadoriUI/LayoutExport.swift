import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import MadoriCore

/// 書き出す用紙の中身。平面図（寸法つき）と、家具の一覧。
public struct LayoutExportView: View {
    public let title: String
    public let room: Room
    public let layout: MadoriCore.Layout

    public init(title: String, room: Room, layout: MadoriCore.Layout) {
        self.title = title
        self.room = room
        self.layout = layout
    }

    public var body: some View {
        let b = room.bounds
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            Text(String(format: "%.0f × %.0f cm（約 %.1f 畳）・天井高 %.0f cm",
                        b.width, b.height, room.area / 16_200, room.ceilingHeight))
                .font(.subheadline)
            LayoutPlanView(room: room, layout: layout, showsClearance: false, showsLabels: true,
                           showsDimensions: true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(layout.items, id: \.furniture.id) { item in
                    HStack {
                        Text(item.furniture.name)
                        Spacer()
                        Text(String(format: "%.0f × %.0f × %.0f cm", item.furniture.width,
                                    item.furniture.depth, item.furniture.height))
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
            Text("オレンジ色の枠は、ドアの開閉に空けておく場所です。家具の三角形は、正面の向きを表します。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 640)
        .background(Color.white)
        .foregroundStyle(Color.black)
        .environment(\.colorScheme, .light)
    }
}

public enum LayoutExporter {
    /// 画像 (PNG) と PDF を、一時フォルダに書き出す。
    @MainActor
    public static func export(title: String, room: Room, layout: MadoriCore.Layout) -> (png: URL, pdf: URL)? {
        let renderer = ImageRenderer(content: LayoutExportView(title: title, room: room, layout: layout))
        renderer.scale = 2

        guard let image = renderer.cgImage else { return nil }
        let png = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(png, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        let pdf = NSMutableData()
        renderer.render { size, renderInContext in
            var box = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(data: pdf as CFMutableData),
                  let context = CGContext(consumer: consumer, mediaBox: &box, nil) else { return }
            context.beginPDFPage(nil)
            renderInContext(context)
            context.endPDFPage()
            context.closePDF()
        }
        guard pdf.length > 0 else { return nil }

        do {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("MadoriExport-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let name = safeFileName(title)
            let pngURL = folder.appendingPathComponent("\(name).png")
            let pdfURL = folder.appendingPathComponent("\(name).pdf")
            try (png as Data).write(to: pngURL)
            try (pdf as Data).write(to: pdfURL)
            return (pngURL, pdfURL)
        } catch {
            return nil
        }
    }

    /// ファイル名に使えない文字を置き換える。空なら既定の名前にする。
    static func safeFileName(_ title: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/\\:?*\"<>|").union(.controlCharacters)
        let cleaned = title.components(separatedBy: forbidden).joined(separator: "-")
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "配置案" : String(cleaned.prefix(60))
    }
}

/// 書き出した画像・PDF を共有する画面。
public struct LayoutExportSheet: View {
    public let title: String
    public let room: Room
    public let layout: MadoriCore.Layout
    @State private var files: (png: URL, pdf: URL)?
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    public init(title: String, room: Room, layout: MadoriCore.Layout) {
        self.title = title
        self.room = room
        self.layout = layout
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let files {
                    ShareLink(item: files.png) { Label("画像 (PNG) を共有", systemImage: "photo") }
                        .buttonStyle(.borderedProminent)
                    ShareLink(item: files.pdf) { Label("PDF を共有", systemImage: "doc.richtext") }
                        .buttonStyle(.bordered)
                    Text("寸法つきの平面図と、家具の一覧が入っています")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else if failed {
                    Label("書き出せませんでした", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                } else {
                    ProgressView("書き出しています…")
                }
            }
            .padding()
            .navigationTitle("書き出し")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
            .task {
                if let result = LayoutExporter.export(title: title, room: room, layout: layout) {
                    files = result
                } else {
                    failed = true
                }
            }
        }
    }
}
