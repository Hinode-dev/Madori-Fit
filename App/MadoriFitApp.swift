import SwiftUI
import MadoriApp

/// Xcode のアプリターゲットに、このファイルだけを置く。画面はすべて MadoriApp パッケージにある。
@main
struct MadoriFitApp: App {
    var body: some Scene {
        WindowGroup {
            MadoriLaunchView()
        }
    }
}
