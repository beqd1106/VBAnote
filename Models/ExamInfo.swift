import Foundation

/// 資格ごとに変わる値。現在学習中の資格（ExamContext.current）から引く。
enum ExamInfo {
    /// アプリ名（全資格共通）
    static let appName = "資格note"
    private static var spec: ExamSpec { ExamContext.current }

    /// ホームのワードマークで強調する頭文字（例："FE"note）
    static var brandPrefix: String { spec.brandPrefix }
    static var examShortName: String { spec.examShortName }
    static var examFullName: String { spec.examFullName }
    static var officialSite: String { spec.officialSite }
    static var organizerNotice: String { spec.organizerNotice }
    /// 本番模試の問題数と制限時間
    static var mockCount: Int { spec.mockCount }
    static var mockMinutes: Int { spec.mockMinutes }
    /// 合格ライン（1000点満点＝正答率×1000）
    static var passScore: Int { spec.passScore }
    static var mockNote: String { spec.mockNote }
    static var servicesTitle: String { spec.servicesTitle }
    static var servicesSubtitle: String { spec.servicesSubtitle }
    static var servicesSearchPlaceholder: String { spec.servicesSearchPlaceholder }

    struct NextCert { let title: String; let subtitle: String; let exam: ExamSpec? }
    static var nextCerts: [NextCert] {
        spec.nextCerts.map { c in
            NextCert(title: c.title, subtitle: c.subtitle,
                     exam: ExamContext.all.first { $0.key == c.examKey })
        }
    }

    /// 直前チェックリスト
    static var finalChecklist: [String] { spec.finalChecklist }

    /// 直前に見直す重要用語カードのID（terms.json の t-key1〜6）
    static var keyTermIds: [String] { spec.keyTermIds }

    /// 完全初心者向け 8週間の標準ロードマップ
    /// （WeekGoal.id は生成のたびに変わるため、資格ごとに1回だけ作って使い回す）
    static var roadmap: [WeekGoal] {
        if let cached = roadmapCache[spec.key] { return cached }
        let goals = spec.roadmap.map {
            WeekGoal(week: $0.week, title: $0.title, detail: $0.detail,
                     domains: $0.domains.compactMap(ExamDomain.init(rawValue:)))
        }
        roadmapCache[spec.key] = goals
        return goals
    }
    private static var roadmapCache: [String: [WeekGoal]] = [:]
}
