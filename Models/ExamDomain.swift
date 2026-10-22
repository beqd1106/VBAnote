import SwiftUI

/// 現在学習中の資格の出題分野。中身は exams.json（ExamContext.current.domains）から引く。
/// 問題JSONの "domain" 文字列をそのまま保持し、資格ごとに分野の数・名前が変わっても同じコードで扱う。
/// ※配点比率は公式の出題範囲の分量からの近似値。最新は公式サイトで確認すること。
struct ExamDomain: Hashable, Codable, Identifiable {
    let rawValue: String

    /// 現在の資格に存在しない分野名なら nil（旧データ・他資格のデータを弾く）
    init?(rawValue: String) {
        guard ExamContext.current.domains.contains(where: { $0.id == rawValue }) else { return nil }
        self.rawValue = rawValue
    }

    private init(trusted rawValue: String) { self.rawValue = rawValue }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }

    /// 現在の資格の全分野（章の順）
    static var allCases: [ExamDomain] {
        ExamContext.current.domains.map { ExamDomain(trusted: $0.id) }
    }

    var id: String { rawValue }

    private var spec: ExamSpec.DomainSpec? {
        ExamContext.current.domains.first { $0.id == rawValue }
    }

    /// 出題比率の近似値（模試の出題配分・合格可能性スコアに使用）。合計1.0。
    var weight: Double { spec?.weight ?? 0 }

    var title: String { spec?.title ?? rawValue }

    var shortTitle: String { spec?.shortTitle ?? rawValue }

    /// 章番号（並び順）
    var chapterNumber: Int {
        (ExamContext.current.domains.firstIndex { $0.id == rawValue } ?? 0) + 1
    }

    /// 配点を百分率の整数で（UI表示用）
    var weightPercent: Int { Int((weight * 100).rounded()) }

    var color: Color { Theme.named(spec?.color ?? "navy") }

    var systemIcon: String { spec?.icon ?? "book.fill" }
}
