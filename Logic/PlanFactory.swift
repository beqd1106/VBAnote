import Foundation

/// 8週間標準カリキュラムをベースに、選択プランの週数へスケールして
/// 週ごとの学習テーマ（ロードマップ）を生成する。
struct WeekGoal: Identifiable, Hashable {
    let id = UUID()
    let week: Int
    let title: String
    let detail: String
    let domains: [ExamDomain]
}

enum PlanFactory {

    /// 完全初心者向け 8週間の標準ロードマップ（資格ごとの中身は ExamInfo.roadmap）
    private static var baseEightWeeks: [WeekGoal] { ExamInfo.roadmap }

    /// プラン週数に合わせてロードマップを生成する。
    /// 8週以外は週数に応じて圧縮/伸長する（テーマの順序は保つ）。
    static func roadmap(for plan: StudyPlanType) -> [WeekGoal] {
        let weeks = plan.durationWeeks
        if weeks == 8 { return baseEightWeeks }

        var result: [WeekGoal] = []
        for w in 1...weeks {
            // 8週カリキュラム上の対応位置を比例で求める
            let srcIndex = min(baseEightWeeks.count - 1,
                               Int((Double(w - 1) / Double(weeks - 1)) * Double(baseEightWeeks.count - 1)))
            let base = baseEightWeeks[srcIndex]
            result.append(.init(week: w, title: base.title, detail: base.detail, domains: base.domains))
        }
        return result
    }

    /// 現在の経過日数から「今が何週目か」を返す（1始まり）。
    static func currentWeek(startedAt: Date, plan: StudyPlanType, now: Date = .now) -> Int {
        let days = Calendar.current.dateComponents([.day],
            from: Calendar.current.startOfDay(for: startedAt),
            to: Calendar.current.startOfDay(for: now)).day ?? 0
        let week = days / 7 + 1
        return min(max(week, 1), plan.durationWeeks)
    }
}
