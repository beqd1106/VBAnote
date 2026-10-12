import Foundation

/// バンドルされたJSONから読み込む「静的な学習コンテンツ」のモデル群。
/// ユーザーの進捗・履歴は SwiftData 側（UserModels.swift）で扱い、
/// コンテンツとユーザーデータを明確に分離する。

// MARK: - 問題

struct QuizQuestion: Codable, Identifiable, Hashable {
    let id: String
    let question: String
    let choices: [String]
    /// 正解の選択肢インデックス（複数選択にも対応）
    let correctAnswers: [Int]
    let explanation: String
    /// 不正解選択肢の理由。キーは選択肢インデックスの文字列。
    let wrongChoiceExplanations: [String: String]
    let domain: ExamDomain
    let service: String
    /// 1=やさしい 2=ふつう 3=やや難
    let difficulty: Int
    let tags: [String]
    /// 初心者向けの一言補足
    let beginnerNote: String?

    /// 複数選択問題かどうか
    var isMultipleSelect: Bool { correctAnswers.count > 1 }

    /// 選んだ回答（インデックス集合）が正解か判定
    func isCorrect(selected: Set<Int>) -> Bool {
        selected == Set(correctAnswers)
    }

    func wrongReason(for index: Int) -> String? {
        wrongChoiceExplanations[String(index)]
    }
}

// MARK: - 用語カード

struct TermCard: Codable, Identifiable, Hashable {
    let id: String
    let term: String
    let shortDescription: String
    let beginnerExplanation: String
    let useCase: String
    let examPoint: String
    let relatedServices: [String]
    let domain: ExamDomain
    let difficulty: Int
}

// MARK: - レッスン

struct Lesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let domain: ExamDomain
    let estimatedMinutes: Int
    let summary: String
    let sections: [LessonSection]
    /// 基礎問題。レッスン本文を読めば解けるやさしい問題で、確認問題の前に解く。
    /// 旧データでキーが無くてもデコードできるよう任意にする。
    let basicQuizIds: [String]?
    let quizIds: [String]
    /// 中級チャレンジ（腕試し）。試験範囲内のシナリオ型の難問。無い場合は空。
    /// 旧データでキーが無くてもデコードできるよう任意にする。
    let challengeQuizIds: [String]?
    /// 反復ドリル（5パターン）。同じ知識を用途→/説明/シナリオ/穴埋め/誤り探しの5方向で問う。
    let drillQuizIds: [String]?
}

struct LessonSection: Codable, Hashable {
    let heading: String
    let body: String
}

// MARK: - 主要生成AIツール一覧

struct GenAIToolItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let oneLiner: String
    let domain: ExamDomain
}

// MARK: - 用語集（初心者向けツールチップ）

/// 問題文・解説などに登場する専門用語に、タップで簡単な説明を出すための辞書。
/// Web版（glossify）と同じ glossary.json を共有する。
struct GlossaryEntry: Codable, Identifiable, Hashable {
    let term: String
    let explanation: String
    var id: String { term }
}
