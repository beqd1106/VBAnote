import Foundation

/// 忘却曲線を意識した間隔反復のロジック（純粋関数中心でテストしやすい）。
///
/// - 間違えた問題は **その場で復習リストに入る**（翌日まで待たせない）。
///   「間違えた＝すぐ復習したい」という学習者の期待に合わせ、次回復習日を現在時刻にする。
/// - 自力で正解するたびに 1日→3日→7日→14日→30日 と間隔を広げる。
/// - ヒントを使って正解した場合は「自力で解けた」とはみなさず、段階を据え置いて同じ間隔で再出題する。
enum SpacedRepetition {

    /// reviewLevel に対応する次回までの日数
    static let intervals: [Int] = [1, 3, 7, 14, 30]

    static func interval(forLevel level: Int) -> Int {
        let idx = min(max(level, 0), intervals.count - 1)
        return intervals[idx]
    }

    /// 回答結果から次の復習状態を計算する。
    /// - Parameters:
    ///   - currentLevel: 現在の復習段階
    ///   - correct: 今回正解したか
    ///   - usedHint: ヒントを使ったか（使っていたら段階を進めない）
    ///   - now: 基準日時（テスト用に注入可能）
    /// - Returns: (次の段階, 次回復習日)
    static func next(currentLevel: Int, correct: Bool, usedHint: Bool = false, now: Date = .now)
        -> (level: Int, nextDate: Date) {
        // 不正解：段階を0に戻し、すぐ復習できるようにする
        guard correct else { return (0, now) }

        // ヒントつきの正解：段階は据え置き、現在の間隔でもう一度出す
        if usedHint {
            return (max(currentLevel, 0), date(afterDays: interval(forLevel: currentLevel), from: now))
        }

        let newLevel = min(currentLevel + 1, intervals.count - 1)
        return (newLevel, date(afterDays: interval(forLevel: newLevel), from: now))
    }

    private static func date(afterDays days: Int, from now: Date) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: now)) ?? now
    }
}
