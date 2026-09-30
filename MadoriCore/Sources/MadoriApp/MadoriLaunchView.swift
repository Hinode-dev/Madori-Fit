import SwiftUI
import SwiftData
import MadoriUI

/// アプリの入口。保存先を開き、開けなければ、案内を出す（強制終了しない）。
public struct MadoriLaunchView: View {
    @StateObject private var model = LaunchModel()

    public init() {}

    public var body: some View {
        switch model.state {
        case .ready(let container):
            MadoriRootView()
                .modelContainer(container)
        case .failed(let message):
            StorageErrorView(message: message,
                             onRetry: { model.retry() },
                             onUseTemporary: { model.useTemporary() })
        }
    }
}

/// 保存先を、1 回だけ開いて持つ。
final class LaunchModel: ObservableObject {
    @Published var state: StorageResult

    init() {
        state = MadoriStorage.open()
    }

    func retry() {
        state = MadoriStorage.open()
    }

    func useTemporary() {
        state = MadoriStorage.openTemporary()
    }
}

struct StorageErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onUseTemporary: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("😢").font(.system(size: 64))
            Text("データを開けませんでした").font(.title3.bold())
            Text("端末の空き容量が足りないか、保存されたデータに問題がある可能性があります。空き容量を確認して、もう一度お試しください。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
            Button("もう一度試す", action: onRetry)
                .buttonStyle(.pill)
                .padding(.top, 8)
            Button("保存せずに使う", action: onUseTemporary)
                .buttonStyle(.soft)
            Text("「保存せずに使う」では、アプリを閉じると、入力した内容は消えます。元のデータは、消しません。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MadoriTheme.background.ignoresSafeArea())
    }
}
