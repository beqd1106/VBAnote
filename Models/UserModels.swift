import Foundation
import SwiftData

/// ユーザーの進捗・履歴を保存する SwiftData モデル群（ローカル完結）。
/// 将来 CloudKit / Supabase に拡張しやすいよう、コンテンツ（JSON）とは分離している。

// MARK: - 補助 enum

/// IT/クラウド経験レベル（初回診断で設定）
enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case noneAtAll          // まったくの未経験
    case someIT             // IT経験はある
    case someCloud          // クラウドも少し触ったことがある

    var id: String { rawValue }
    var title: String {
        switch self {
        case .noneAtAll: return "まったくの初心者"
        case .someIT:    return "IT経験あり"
        case .someCloud: return "生成AI利用経験あり"
        }
    }
    var detail: String {
        switch self {
        case .noneAtAll: return "AI・ITともにほぼ未経験"
        case .someIT:    return "ITの基礎知識はある"
        case .someCloud: return "ChatGPTなど生成AIを使ったことがある"
        }
    }
}

/// 学習プラン（期間）
enum StudyPlanType: String, Codable, CaseIterable, Identifiable {
    case intensive4   // 短期集中
    case standard8    // 標準（完全初心者の推奨）
    case relaxed12    // ゆっくり
    case custom6      // 中間

    var id: String { rawValue }
    var durationWeeks: Int {
        switch self {
        case .intensive4: return 4
        case .custom6:    return 6
        case .standard8:  return 8
        case .relaxed12:  return 12
        }
    }
    var title: String {
        switch self {
        case .intensive4: return "短期集中プラン"
        case .custom6:    return "しっかりプラン"
        case .standard8:  return "標準プラン"
        case .relaxed12:  return "ゆっくりプラン"
        }
    }
    var subtitle: String { "\(durationWeeks)週間で合格を目指す" }
    var recommendedDailyMinutes: Int {
        switch self {
        case .intensive4: return 60
        case .custom6:    return 45
        case .standard8:  return 30
        case .relaxed12:  return 20
        }
    }
}

// MARK: - ユーザープロフィール

@Model
final class UserProfile {
    var name: String
    var experienceRaw: String
    var dailyStudyMinutes: Int
    var targetExamDate: Date?
    var planRaw: String
    /// 初回診断で「苦手そう」と答えた分野（rawValueの配列）
    var weakDomainsRaw: [String]
    var createdAt: Date

    init(name: String = "",
         experience: ExperienceLevel = .noneAtAll,
         dailyStudyMinutes: Int = 30,
         targetExamDate: Date? = nil,
         plan: StudyPlanType = .standard8,
         weakDomains: [ExamDomain] = [],
         createdAt: Date = .now) {
        self.name = name
        self.experienceRaw = experience.rawValue
        self.dailyStudyMinutes = dailyStudyMinutes
        self.targetExamDate = targetExamDate
        self.planRaw = plan.rawValue
        self.weakDomainsRaw = weakDomains.map(\.rawValue)
        self.createdAt = createdAt
    }

    var experience: ExperienceLevel {
        get { ExperienceLevel(rawValue: experienceRaw) ?? .noneAtAll }
        set { experienceRaw = newValue.rawValue }
    }
    var plan: StudyPlanType {
        get { StudyPlanType(rawValue: planRaw) ?? .standard8 }
        set { planRaw = newValue.rawValue }
    }
    var weakDomains: [ExamDomain] {
        get { weakDomainsRaw.compactMap { ExamDomain(rawValue: $0) } }
        set { weakDomainsRaw = newValue.map(\.rawValue) }
    }

    /// 試験日まで残り日数（未設定ならnil）
    var daysUntilExam: Int? {
        guard let date = targetExamDate else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: .now),
                                      to: cal.startOfDay(for: date)).day
        return days
    }
}

// MARK: - 回答履歴

@Model
final class AnswerRecord {
    var questionId: String
    var domainRaw: String
    var isCorrect: Bool
    var answeredAt: Date
    /// 模擬試験での回答かどうか
    var isMockExam: Bool

    init(questionId: String, domain: ExamDomain, isCorrect: Bool,
         answeredAt: Date = .now, isMockExam: Bool = false) {
        self.questionId = questionId
        self.domainRaw = domain.rawValue
        self.isCorrect = isCorrect
        self.answeredAt = answeredAt
        self.isMockExam = isMockExam
    }

    var domain: ExamDomain { ExamDomain(rawValue: domainRaw) ?? ExamDomain.allCases[0] }
}

// MARK: - 復習アイテム（間隔反復）

@Model
final class ReviewItem {
    @Attribute(.unique) var questionId: String
    var nextReviewDate: Date
    /// 復習段階（0→1→2→… 連続正解で進む）。間隔 1日→3日→7日→14日…
    var reviewLevel: Int
    var lastResultCorrect: Bool
    var createdAt: Date

    init(questionId: String, nextReviewDate: Date, reviewLevel: Int = 0,
         lastResultCorrect: Bool = false, createdAt: Date = .now) {
        self.questionId = questionId
        self.nextReviewDate = nextReviewDate
        self.reviewLevel = reviewLevel
        self.lastResultCorrect = lastResultCorrect
        self.createdAt = createdAt
    }

    var isDue: Bool { nextReviewDate <= .now }
}

// MARK: - 問題ごとのメタ（お気に入り・メモ）

@Model
final class QuestionMeta {
    @Attribute(.unique) var questionId: String
    var isBookmarked: Bool
    var note: String

    init(questionId: String, isBookmarked: Bool = false, note: String = "") {
        self.questionId = questionId
        self.isBookmarked = isBookmarked
        self.note = note
    }
}

// MARK: - 模擬試験結果

struct DomainScoreEntry: Codable, Hashable {
    var domainRaw: String
    var correct: Int
    var total: Int
    var domain: ExamDomain { ExamDomain(rawValue: domainRaw) ?? ExamDomain.allCases[0] }
    var rate: Double { total == 0 ? 0 : Double(correct) / Double(total) }
}

@Model
final class MockExamResult {
    var id: String
    var date: Date
    /// 0〜1000のスコア（正答率×1000）（本番に合わせた目安表示用）
    var scaledScore: Int
    var correctCount: Int
    var totalCount: Int
    var domainScores: [DomainScoreEntry]

    init(id: String = UUID().uuidString, date: Date = .now,
         scaledScore: Int, correctCount: Int, totalCount: Int,
         domainScores: [DomainScoreEntry]) {
        self.id = id
        self.date = date
        self.scaledScore = scaledScore
        self.correctCount = correctCount
        self.totalCount = totalCount
        self.domainScores = domainScores
    }

    var correctRate: Double { totalCount == 0 ? 0 : Double(correctCount) / Double(totalCount) }
    /// 合格目安（ExamInfo.passScore）を超えたか
    var isPassingScore: Bool { scaledScore >= ExamInfo.passScore }
}

// MARK: - レッスン履修状態（履修済みマーク用）

@Model
final class LessonProgress {
    @Attribute(.unique) var lessonId: String
    var completedAt: Date

    init(lessonId: String, completedAt: Date = .now) {
        self.lessonId = lessonId
        self.completedAt = completedAt
    }
}

// MARK: - 1日の学習ログ（連続日数・カレンダー用）

@Model
final class StudyDayLog {
    /// その日の0時（startOfDay）
    @Attribute(.unique) var day: Date
    var studiedMinutes: Int
    var questionsAnswered: Int

    init(day: Date, studiedMinutes: Int = 0, questionsAnswered: Int = 0) {
        self.day = day
        self.studiedMinutes = studiedMinutes
        self.questionsAnswered = questionsAnswered
    }
}
