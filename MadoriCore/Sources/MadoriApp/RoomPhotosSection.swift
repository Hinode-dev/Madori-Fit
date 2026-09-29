import SwiftUI
import PhotosUI
import SwiftData
import MadoriCore
import MadoriUI

/// 部屋の参考写真を追加・整理する。寸法を直すときに、編集画面の上に表示される。
struct RoomPhotosSection: View {
    @Bindable var record: RoomRecord
    @Environment(\.modelContext) private var context
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var failedToLoad = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        Section {
            if !record.sortedPhotos.isEmpty {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(record.sortedPhotos, id: \.uid) { photo in
                        thumbnail(photo)
                    }
                }
                .padding(.vertical, 4)
            }
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                Label("アルバムから追加", systemImage: "photo.on.rectangle")
            }
            #if os(iOS)
            if CameraPicker.isAvailable {
                Button("撮影して追加", systemImage: "camera") { isShowingCamera = true }
            }
            #endif
        } header: {
            Text("参考写真（\(record.sortedPhotos.count)）")
        } footer: {
            Text("寸法を直すときに、編集画面の上に表示されます。どの壁の写真かを指定しておくと分かりやすくなります。")
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .alert("読み込めない写真がありました", isPresented: $failedToLoad) {
            Button("OK", role: .cancel) {}
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraPicker { data in
                isShowingCamera = false
                if let data { add(data) }
            }
            .ignoresSafeArea()
        }
        #endif
    }

    private func thumbnail(_ photo: RoomPhoto) -> some View {
        ZStack(alignment: .bottomLeading) {
            DataImage(data: photo.imageData, maxPixel: 300)
                .frame(height: 72)
                .clipped()
            if let side = photo.side {
                Text("\(side.label)の壁")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .background(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .contextMenu {
            ForEach(WallSide.allCases, id: \.self) { side in
                Button("\(side.label)の壁の写真にする") { photo.side = side }
            }
            Button("壁の指定を外す") { photo.side = nil }
            Button("削除", role: .destructive) { context.delete(photo) }
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        var failed = false
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                add(data)
            } else {
                failed = true
            }
        }
        pickerItems = []
        failedToLoad = failed
    }

    private func add(_ data: Data) {
        guard let jpeg = ImageProcessing.downscaledJPEG(from: data) else {
            failedToLoad = true
            return
        }
        let photo = RoomPhoto(imageData: jpeg)
        photo.room = record
        context.insert(photo)
        record.updatedAt = Date()
    }
}
