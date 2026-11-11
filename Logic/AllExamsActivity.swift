import Foundation
import SwiftData

/// すべての資格の学習記録をまとめる（学習カレンダーの「すべての資格」とホームの記録カード用）。
/// 進捗は資格ごとに別ストアなので、学び始めている資格のストアだけを開いて読む。
@MainActor
struct AllExamsActivity {
    /// 資格ごとの日別記録（キー＝資格キー）
    let byExam: [String: [Date: DailyStudyRecord]]
    /// 全資格を合算した日別記録
    let merged: [Date: DailyStudyRecord]
    /// どれかの資格で学習した日
    let studyDays: Set<Date>

    var streak: Int { StudyStreak.count(days: studyDays) }
    /// 連続の途中で使った休息日（ホームの7日表示で「休」を出す）
    var restDays: Set<Date> { Set(StudyStreak.walk(days: studyDays).rests) }
    var longestStreak: Int { StudyStreak.longest(days: studyDays) }

    /// その日に学習した資格と記録（問題数の多い順）
    func breakdown(on day: Date) -> [(exam: ExamSpec, record: DailyStudyRecord)] {
        ExamContext.all.compactMap { exam in
            guard let r = byExam[exam.key]?[day], r.hasActivity else { return nil }
            return (exam, r)
        }
        .sorted { $0.record.questions + $0.record.lessonsCompleted * 5 > $1.record.questions + $1.record.lessonsCompleted * 5 }
    }

    /// 今日から数えた直近 n 日（古い順）
    func recentDays(_ n: Int, calendar cal: Calendar = .current) -> [DailyStudyRecord] {
        let today = cal.startOfDay(for: .now)
        return (0..<n).reversed().compactMap { offset in
            guard let d = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return merged[d] ?? DailyStudyRecord(day: d)
        }
    }

    /// 学習日の定義（単一資格・全資格で共通）：回答ログのある日＋記録上なにか学習した日
    nonisolated static func studyDays(logs: [StudyDayLog], records: [Date: DailyStudyRecord]) -> Set<Date> {
        Set(logs.map(\.day)).union(records.values.filter(\.hasActivity).map(\.day))
    }

    /// 1資格分の読み込み結果
    private struct ExamSlice { let records: [Date: DailyStudyRecord]; let days: Set<Date> }
    /// いま学習中でない資格の読み込み結果。その資格の記録は切り替えるまで変わらないので使い回す
    private static var cache: [String: ExamSlice] = [:]

    private static func readSlice(_ key: String) -> ExamSlice {
        let context = ModelContext(StoreFactory.container(for: key))
        let answers = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
        let lessons = (try? context.fetch(FetchDescriptor<LessonProgress>())) ?? []
        let logs = (try? context.fetch(FetchDescriptor<StudyDayLog>())) ?? []
        let records = DailyStudyRecord.build(answers: answers, lessons: lessons)
        return ExamSlice(records: records, days: studyDays(logs: logs, records: records))
    }

    /// 全資格の記録を読み込む。現在の資格は毎回読み直し、他の資格はキャッシュを使う。
    /// 読めなかった資格は空として扱う（カレンダーが出ないよりはよいため）
    static func load(currentExamKey: String) -> AllExamsActivity {
        var byExam: [String: [Date: DailyStudyRecord]] = [:]
        var days = Set<Date>()
        for exam in ExamContext.all where exam.key == currentExamKey || StoreFactory.hasProgress(for: exam.key) {
            let slice: ExamSlice
            if exam.key == currentExamKey {
                slice = readSlice(exam.key)
                cache[exam.key] = nil   // 切り替えた後に古い値を使わないよう、学習中の資格はキャッシュしない
            } else if let cached = cache[exam.key] {
                slice = cached
            } else {
                slice = readSlice(exam.key); cache[exam.key] = slice
            }
            byExam[exam.key] = slice.records
            days.formUnion(slice.days)
        }
        return AllExamsActivity(byExam: byExam, merged: merge(byExam.values), studyDays: days)
    }

    nonisolated static func merge<S: Sequence>(_ maps: S) -> [Date: DailyStudyRecord] where S.Element == [Date: DailyStudyRecord] {
        var result: [Date: DailyStudyRecord] = [:]
        for map in maps {
            for (day, r) in map {
                result[day] = result[day].map { $0.adding(r) } ?? r
            }
        }
        return result
    }
}
