#if canImport(RoomPlan) && os(iOS)
import SwiftUI
import RoomPlan
import MadoriCore
import MadoriUI

enum RoomScanSupport {
    /// LiDAR を搭載した機種か。
    static var isAvailable: Bool { RoomCaptureSession.isSupported }
}

/// スキャン → 寸法の確認・補正 → 保存、の一連の流れ。
struct RoomScanFlow: View {
    let onSave: (Room) -> Void
    let onCancel: () -> Void

    private enum Phase {
        case scanning
        case editing(RoomDraft, [String])
        case failed(String)
    }

    @State private var phase: Phase = .scanning
    @StateObject private var controller = ScanController()

    var body: some View {
        switch phase {
        case .scanning:
            ZStack(alignment: .bottom) {
                RoomScanRepresentable(controller: controller) { result in
                    handle(result)
                }
                .ignoresSafeArea()
                HStack(spacing: 16) {
                    Button("キャンセル", action: onCancel)
                        .buttonStyle(.bordered)
                    Button("スキャン完了") { controller.finish() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 32)
            }
        case .editing(let draft, let notices):
            NavigationStack {
                RoomEditorView(draft: draft, notices: notices, onSave: onSave)
                    .navigationTitle("スキャン結果を確認")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("キャンセル", action: onCancel)
                        }
                    }
            }
        case .failed(let message):
            ContentUnavailableView {
                Label("スキャンできませんでした", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("やり直す") { phase = .scanning }
                Button("閉じる", action: onCancel)
            }
        }
    }

    private func handle(_ result: Result<CapturedRoom, Error>) {
        switch result {
        case .failure(let error):
            phase = .failed(error.localizedDescription)
        case .success(let captured):
            let scan = RoomPlanAdapter.scan(from: captured)
            if let fit = RoomFitter.fit(scan) {
                phase = .editing(fit.draft, fit.warnings)
            } else {
                phase = .failed("壁を検出できませんでした。部屋全体をゆっくり見回して、もう一度お試しください")
            }
        }
    }
}

/// 画面上の `RoomCaptureView` を止める操作の受け口。
final class ScanController: ObservableObject {
    weak var view: RoomCaptureView?

    func finish() {
        view?.captureSession.stop()
    }
}

struct RoomScanRepresentable: UIViewRepresentable {
    let controller: ScanController
    let onResult: (Result<CapturedRoom, Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    func makeUIView(context: Context) -> RoomCaptureView {
        let view = RoomCaptureView(frame: .zero)
        view.delegate = context.coordinator
        controller.view = view
        view.captureSession.run(configuration: RoomCaptureSession.Configuration())
        return view
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {}

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        uiView.captureSession.stop()
    }

    final class Coordinator: NSObject, RoomCaptureViewDelegate {
        private let onResult: (Result<CapturedRoom, Error>) -> Void

        init(onResult: @escaping (Result<CapturedRoom, Error>) -> Void) {
            self.onResult = onResult
            super.init()
        }

        // RoomCaptureViewDelegate は NSCoding に準拠しているが、保存はしない。
        required init?(coder: NSCoder) {
            return nil
        }

        func encode(with coder: NSCoder) {}

        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            error == nil
        }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            let result: Result<CapturedRoom, Error> = error.map { .failure($0) } ?? .success(processedResult)
            DispatchQueue.main.async { [onResult] in
                onResult(result)
            }
        }
    }
}
#endif
