#if DEBUG
import Foundation
import SwiftData

/// App Store 用スクリーンショット撮影のためのデモデータ投入（DEBUG ビルド専用）。
/// UIテストが起動引数 `-ScreenshotSeed` を付けたときだけ動き、通常の利用では何もしない。
@MainActor
enum ScreenshotSeed {
    static func applyIfRequested(to store: StudyStore) {
        guard ProcessInfo.processInfo.arguments.contains("-ScreenshotSeed"),
              !store.hasCompletedOnboarding else { return }
        let ctx = store.context
        let repo = ContentRepository.shared
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let domains = ExamDomain.allCases

        store.createProfile(UserProfile(name: "",
                                        dailyStudyMinutes: 30,
                                        targetExamDate: cal.date(byAdding: .day, value: 21, to: today),
                                        plan: .standard8,
                                        weakDomains: [domains[domains.count - 1]],
                                        createdAt: cal.date(byAdding: .day, value: -14, to: today)!))

        // 分野ごとの正答率に差をつけ、分析画面に「苦手」が見えるようにする（先頭の分野ほど得意）
        var rng = SystemRandomNumberGenerator()
        for (n, d) in domains.enumerated() {
            let rate = 0.86 - 0.3 * Double(n) / Double(max(domains.count - 1, 1))
            for (i, q) in repo.questions(in: d).prefix(40).enumerated() {
                let day = cal.date(byAdding: .day, value: -(i % 12), to: today)!
                let correct = Double.random(in: 0..<1, using: &rng) < rate
                ctx.insert(AnswerRecord(questionId: q.id, domain: d, isCorrect: correct,
                                        answeredAt: day.addingTimeInterval(3600 * 20)))
                if !correct {
                    ctx.insert(ReviewItem(questionId: q.id, nextReviewDate: today))
                }
            }
        }
        for offset in 0..<12 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            ctx.insert(StudyDayLog(day: day, studiedMinutes: 25 + (offset * 7) % 20,
                                   questionsAnswered: 15 + (offset * 5) % 10))
        }
        for lesson in repo.lessons.prefix(6) {
            ctx.insert(LessonProgress(lessonId: lesson.id))
        }
        // 模試1回分：分野の配点どおりに問題数を割り振り、合格ラインを少し上回る成績にする
        let total = ExamInfo.mockCount
        var entries: [DomainScoreEntry] = []
        var assigned = 0
        for (n, d) in domains.enumerated() {
            let t = n == domains.count - 1 ? total - assigned : max(1, Int((Double(total) * d.weight).rounded()))
            assigned += t
            let rate = 0.9 - 0.25 * Double(n) / Double(max(domains.count - 1, 1))
            entries.append(DomainScoreEntry(domainRaw: d.rawValue, correct: Int((Double(t) * rate).rounded()), total: t))
        }
        let correct = entries.reduce(0) { $0 + $1.correct }
        ctx.insert(MockExamResult(date: cal.date(byAdding: .day, value: -2, to: today)!,
                                  scaledScore: min(1000, ExamInfo.passScore + 40), correctCount: correct, totalCount: total,
                                  domainScores: entries))
        try? ctx.save()
    }
}
#endif
