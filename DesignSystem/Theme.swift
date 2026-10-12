import SwiftUI

/// アプリ全体のデザイントークン。
/// 方向性：AWSらしいクラウド感（白・ネイビー・ブルー）＋ 学習アプリの親しみ（オレンジ）。
/// 初心者が迷わないよう、シンプル・余白広め・階層明快にする。
enum Theme {

    // MARK: - Color（クリーム地のノート風＋ネイビー/オレンジ）
    static let bg        = Color(hex: 0xF7F3EA)   // 画面背景（温かみのある生成りクリーム）
    static let card      = Color(hex: 0xFFFFFF)   // カード面
    static let navy      = Color(hex: 0x1B2A4A)   // 主役の濃紺（見出し・重要要素）
    static let blue      = Color(hex: 0x2D7FF0)   // アクセントの青（リンク・進捗）
    static let blueSoft  = Color(hex: 0xEAF1FE)   // 青の淡い面
    static let orange    = Color(hex: 0xF39220)   // CTA・強調・連続日数の炎
    static let orangeSoft = Color(hex: 0xFBEAD2)  // オレンジの淡い面
    static let teal      = Color(hex: 0x18A0A0)   // 補助アクセント（動向分野）
    static let purple    = Color(hex: 0x7C5CD6)   // 補助アクセント
    static let indigo    = Color(hex: 0x3F51B5)   // 補助アクセント（分野色）
    static let rose      = Color(hex: 0xD05070)   // 補助アクセント（分野色）
    static let green     = Color(hex: 0x2BA664)   // 正解・成功
    static let red       = Color(hex: 0xE0533D)   // 不正解・警告

    static let ink       = Color(hex: 0x29303A)   // 主要テキスト（やや温かい墨）
    static let inkSoft   = Color(hex: 0x8A8170)   // 補助テキスト（クリームに合う温かいグレー）
    static let line      = Color(hex: 0xEBE3D4)   // 区切り線・枠（クリーム系）

    // MARK: - Spacing（4/8/12/16/24/32/48系）
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Radius
    enum Radius {
        static let card: CGFloat = 18
        static let chip: CGFloat = 10
        static let button: CGFloat = 14
    }

    // MARK: - Shadow
    static func cardShadow() -> Color { navy.opacity(0.06) }
}

// MARK: - Hex Color init
extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255.0,
                  green: Double((hex >> 8) & 0xFF) / 255.0,
                  blue:  Double(hex & 0xFF) / 255.0,
                  opacity: alpha)
    }
}

// MARK: - Typography ヘルパ
extension Text {
    func titleStyle() -> some View {
        self.font(.system(size: 24, weight: .bold)).foregroundStyle(Theme.navy)
    }
    func headingStyle() -> some View {
        self.font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.ink)
    }
    func bodyStyle() -> some View {
        self.font(.system(size: 15)).foregroundStyle(Theme.ink)
    }
    func captionStyle() -> some View {
        self.font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
    }
}
