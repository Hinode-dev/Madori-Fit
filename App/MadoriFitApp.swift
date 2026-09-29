import SwiftUI
import MadoriApp

/// Xcode のアプリターゲットに、このファイルだけを置く。画面はすべて MadoriApp パッケージにある。
@main
struct MadoriFitApp: App {
    private let container: ModelContainerBox

    init() {
        container = ModelContainerBox()
    }

    var body: some Scene {
        WindowGroup {
            MadoriRootView()
        }
        .modelContainer(container.value)
    }
}

import SwiftData

private struct ModelContainerBox {
    let value: ModelContainer

    init() {
        do {
            value = try MadoriStorage.makeContainer()
        } catch {
            fatalError("保存先を開けませんでした: \(error)")
        }
    }
}
