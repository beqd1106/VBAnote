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

    /// 全資格の記録を読み込む。読めなかった資格は飛ばす（カレンダーが出ないよりはよいため）
    static func load(currentExamKey: String) -> AllExamsActivity {
        var byExam: [String: [Date: DailyStudyRecord]] = [:]
        var days = Set<Date>()
        for exam in ExamContext.all where exam.key == currentExamKey || StoreFactory.hasProgress(for: exam.key) {
            let context = ModelContext(StoreFactory.container(for: exam.key))
            let answers = (try? context.fetch(FetchDescriptor<AnswerRecord>())) ?? []
            let lessons = (try? context.fetch(FetchDescriptor<LessonProgress>())) ?? []
            let logs = (try? context.fetch(FetchDescriptor<StudyDayLog>())) ?? []
            let records = DailyStudyRecord.build(answers: answers, lessons: lessons)
            byExam[exam.key] = records
            days.formUnion(logs.map(\.day))
            days.formUnion(records.values.filter(\.hasActivity).map(\.day))
        }
        return AllExamsActivity(byExam: byExam, merged: merge(byExam.values), studyDays: days)
    }

    static func merge<S: Sequence>(_ maps: S) -> [Date: DailyStudyRecord] where S.Element == [Date: DailyStudyRecord] {
        var result: [Date: DailyStudyRecord] = [:]
        for map in maps {
            for (day, r) in map {
                result[day] = result[day].map { $0.adding(r) } ?? r
            }
        }
        return result
    }
}
