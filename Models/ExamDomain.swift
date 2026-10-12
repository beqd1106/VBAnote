import SwiftUI

/// VBAエキスパート「Excel VBA ベーシック」 の出題分野（configs.py から生成。手で編集しない）。
/// ※配点比率は公式の出題範囲の分量からの近似値。最新は公式サイトで確認すること。
enum ExamDomain: String, CaseIterable, Codable, Identifiable {
    case concept
    case syntax
    case variable
    case cell
    case control
    case book

    var id: String { rawValue }

    /// 出題比率の近似値（模試の出題配分・合格可能性スコアに使用）。合計1.0。
    var weight: Double {
        switch self {
        case .concept: return 0.15
        case .syntax: return 0.15
        case .variable: return 0.15
        case .cell: return 0.2
        case .control: return 0.2
        case .book: return 0.15
        }
    }

    var title: String {
        switch self {
        case .concept: return "マクロとVBAの基本"
        case .syntax: return "モジュール・構文"
        case .variable: return "変数と定数"
        case .cell: return "セルの操作"
        case .control: return "ステートメントと関数"
        case .book: return "ブックとシートの操作"
        }
    }

    var shortTitle: String {
        switch self {
        case .concept: return "基本・実行"
        case .syntax: return "構文"
        case .variable: return "変数"
        case .cell: return "セル"
        case .control: return "制御・関数"
        case .book: return "ブック・シート"
        }
    }

    /// 章番号（並び順）
    var chapterNumber: Int {
        switch self {
        case .concept: return 1
        case .syntax: return 2
        case .variable: return 3
        case .cell: return 4
        case .control: return 5
        case .book: return 6
        }
    }

    /// 配点を百分率の整数で（UI表示用）
    var weightPercent: Int { Int((weight * 100).rounded()) }

    var color: Color {
        switch self {
        case .concept: return Theme.navy
        case .syntax: return Theme.blue
        case .variable: return Theme.teal
        case .cell: return Theme.orange
        case .control: return Theme.purple
        case .book: return Theme.indigo
        }
    }

    var systemIcon: String {
        switch self {
        case .concept: return "play.rectangle.fill"
        case .syntax: return "curlybraces"
        case .variable: return "shippingbox.fill"
        case .cell: return "tablecells"
        case .control: return "arrow.triangle.branch"
        case .book: return "doc.on.doc.fill"
        }
    }

}
