import SwiftUI
import ImageIO
import UniformTypeIdentifiers
import MadoriCore

/// 寸法を見直すときに見返す、部屋の参考写真。
public struct ReferencePhoto: Identifiable, Equatable, Sendable {
    public let id: UUID
    /// どの壁の写真か。図の上から見た位置で指定する。
    public var side: WallSide?
    public var data: Data

    public init(id: UUID = UUID(), side: WallSide? = nil, data: Data) {
        self.id = id
        self.side = side
        self.data = data
    }
}

public enum ImageProcessing {
    /// 長辺が `maxPixel` 以下になるよう縮小した JPEG。画像として読めなければ nil。
    public static func downscaledJPEG(from data: Data, maxPixel: Int = 1600, quality: Double = 0.75) -> Data? {
        guard let image = thumbnail(from: data, maxPixel: maxPixel) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(
            destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    /// 向き情報を反映し、長辺が `maxPixel` 以下になるよう縮めた画像。
    public static func thumbnail(from data: Data, maxPixel: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}

/// 画像データを、メインスレッドの外で縮小して表示する。
public struct DataImage: View {
    let data: Data
    let maxPixel: Int
    let contentMode: ContentMode
    @State private var image: CGImage?

    public init(data: Data, maxPixel: Int, contentMode: ContentMode = .fill) {
        self.data = data
        self.maxPixel = maxPixel
        self.contentMode = contentMode
    }

    public var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .task(id: data.count) {
            let data = data
            let maxPixel = maxPixel
            image = await Task.detached(priority: .userInitiated) {
                ImageProcessing.thumbnail(from: data, maxPixel: maxPixel)
            }.value
        }
    }
}

/// 写真を横に並べる。タップで拡大する。編集画面の上に固定して使う。
public struct ReferencePhotoStrip: View {
    public let photos: [ReferencePhoto]
    @State private var selected: ReferencePhoto?

    public init(photos: [ReferencePhoto]) {
        self.photos = photos
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(photos) { photo in
                    Button {
                        selected = photo
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            DataImage(data: photo.data, maxPixel: 300)
                                .frame(width: 88, height: 66)
                                .clipped()
                            if let side = photo.side {
                                Text("\(side.label)の壁")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .background(.ultraThinMaterial)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(photo.side.map { "\($0.label)の壁の写真" } ?? "参考写真")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .frame(height: 78)
        .background(.bar)
        .sheet(item: $selected) { PhotoViewer(photo: $0) }
    }
}

/// 写真を拡大して見る。ピンチで拡大、ドラッグで移動、ダブルタップで元に戻す。
struct PhotoViewer: View {
    let photo: ReferencePhoto
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                DataImage(data: photo.data, maxPixel: 2400, contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = max(1, baseScale * $0) }
                            .onEnded { _ in
                                baseScale = scale
                                if scale <= 1 { reset() }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { offset = CGSize(width: baseOffset.width + $0.translation.width,
                                                         height: baseOffset.height + $0.translation.height) }
                            .onEnded { _ in baseOffset = offset }
                    )
                    .onTapGesture(count: 2) { withAnimation { reset() } }
            }
            .navigationTitle(photo.side.map { "\($0.label)の壁" } ?? "参考写真")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func reset() {
        scale = 1
        baseScale = 1
        offset = .zero
        baseOffset = .zero
    }
}
