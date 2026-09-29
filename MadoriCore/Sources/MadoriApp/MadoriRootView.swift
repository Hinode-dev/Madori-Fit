import SwiftUI

/// アプリの最上位の画面。`modelContainer` は呼び出し側 (App) で付ける。
public struct MadoriRootView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            RoomListView()
        }
    }
}
