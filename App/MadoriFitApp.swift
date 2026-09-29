import SwiftUI
import SwiftData
import MadoriApp

/// Xcode のアプリターゲットに、このファイルだけを置く。画面はすべて MadoriApp パッケージにある。
@main
struct MadoriFitApp: App {
    private let container: ModelContainer

    init() {
        do {
            container = try MadoriStorage.makeContainer()
        } catch {
            fatalError("保存先を開けませんでした: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            MadoriRootView()
        }
        .modelContainer(container)
    }
}
