import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// アプリ全体の色と形。見た目を変えたいときは、ここを直す。
public enum MadoriTheme {
    // パステルカラー
    public static let coral = Color(red: 1.00, green: 0.50, blue: 0.52)
    public static let peach = Color(red: 1.00, green: 0.74, blue: 0.58)
    public static let butter = Color(red: 1.00, green: 0.84, blue: 0.42)
    public static let mint = Color(red: 0.40, green: 0.80, blue: 0.70)
    public static let sky = Color(red: 0.50, green: 0.72, blue: 1.00)
    public static let lavender = Color(red: 0.72, green: 0.62, blue: 0.96)

    /// アプリの基調の色。ボタンやリンクの色になる。
    public static var accent: Color { coral }

    /// 背景。明るいときはクリーム色、暗いときは暖かい濃いグレー。
    public static var background: Color {
        Color(light: (0.995, 0.965, 0.935), dark: (0.10, 0.09, 0.09))
    }

    /// カードの面。
    public static var card: Color {
        Color(light: (1.0, 1.0, 1.0), dark: (0.17, 0.16, 0.16))
    }

    /// 部屋ごとの色。名前から決まるので、同じ名前なら、いつも同じ色になる。
    public static func tint(for name: String) -> Color {
        let palette = [coral, mint, sky, lavender, butter, peach]
        let sum = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 9_973 }
        return palette[sum % palette.count]
    }

    public static let cardCornerRadius: CGFloat = 22
}

extension Color {
    /// 明るいとき・暗いときで色を変える。
    init(light: (Double, Double, Double), dark: (Double, Double, Double)) {
        #if canImport(UIKit)
        self = Color(uiColor: UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #else
        self = Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
        #endif
    }
}

extension View {
    /// クリーム色の背景。Form・List・ScrollView に付ける。
    public func madoriBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(MadoriTheme.background.ignoresSafeArea())
    }

    /// 角の丸い、やわらかい影のカード。
    public func madoriCard(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(MadoriTheme.card,
                        in: RoundedRectangle(cornerRadius: MadoriTheme.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }
}

/// 色つきの、丸いボタン。主な操作に使う。
public struct PillButtonStyle: ButtonStyle {
    public var color: Color

    public init(color: Color = MadoriTheme.accent) {
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// うすい色の、丸いボタン。補助的な操作に使う。
public struct SoftButtonStyle: ButtonStyle {
    public var color: Color

    public init(color: Color = MadoriTheme.accent) {
        self.color = color
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    public static var pill: PillButtonStyle { PillButtonStyle() }
}

extension ButtonStyle where Self == SoftButtonStyle {
    public static var soft: SoftButtonStyle { SoftButtonStyle() }
}

/// 小さな、丸い情報のタグ（畳数、家具の数など）。
public struct InfoChip: View {
    let text: String
    let systemImage: String
    let tint: Color

    public init(_ text: String, systemImage: String, tint: Color) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(tint.opacity(0.18), in: Capsule())
            .foregroundStyle(tint)
    }
}
