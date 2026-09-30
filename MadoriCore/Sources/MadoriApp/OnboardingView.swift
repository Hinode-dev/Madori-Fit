import SwiftUI
import MadoriUI

/// 初回に見せる、使い方の説明。あとから、部屋の一覧の「使い方」でも見られる。
struct OnboardingView: View {
    let onFinish: () -> Void
    let onTrySample: () -> Void

    @State private var page = 0

    private struct Page {
        let emoji: String
        let title: String
        let text: String
    }

    private let pages = [
        Page(emoji: "🏠", title: "ようこそ、Madori Fitへ",
             text: "引っ越し前に、お部屋の寸法と家具から、ちょうどいい配置を見つけるアプリです。すべて、この端末の中だけで動きます。"),
        Page(emoji: "📐", title: "お部屋を登録",
             text: "LiDARのあるiPhone・iPadなら、部屋をスキャンするだけ。ない端末では、寸法を入力します。ARの定規で測って、そのまま入れることもできます。"),
        Page(emoji: "🛋️", title: "家具を選んで、配置案を作る",
             text: "家具のサイズを選ぶと、通路が確保できる配置案を、自動で作ります。ドラッグで直したり、気に入った家具を固定して、ほかを作り直したりできます。3Dでも見られます。"),
        Page(emoji: "🚚", title: "搬入チェックと、ARの実寸確認",
             text: "玄関やエレベーターの寸法を入れると、家具が通れるか確認できます。ARで、実寸の家具を、実際の部屋に重ねて見ることもできます。")
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index]).tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #endif

            VStack(spacing: 10) {
                if page < pages.count - 1 {
                    Button("つぎへ") { withAnimation { page += 1 } }
                        .buttonStyle(.pill)
                    Button("スキップ", action: onFinish)
                        .buttonStyle(.plain)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Button("サンプルの部屋で試す", action: onTrySample)
                        .buttonStyle(.pill)
                    Button("はじめる", action: onFinish)
                        .buttonStyle(.soft)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(MadoriTheme.background.ignoresSafeArea())
    }

    private func pageView(_ page: Page) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(page.emoji).font(.system(size: 88))
            Text(page.title)
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text(page.text)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 24)
    }
}
