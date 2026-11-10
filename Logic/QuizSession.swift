import Foundation

/// 途中で閉じた問題セッションの保存内容。資格ごとに最新1件だけ持つ（新しく解き始めたら上書き）。
/// 回答の記録（AnswerRecord）は答え合わせの時点で済んでいるので、再開時に二重に記録しない。
struct QuizSession: Codable, Equatable {
    var title: String
    var questionIds: [String]
    var index: Int
    var selectedByIndex: [Int: Set<Int>]
    var submittedIndices: Set<Int>
    var resultByIndex: [Int: Bool]
    var hintLevelByIndex: [Int: Int]
    var hintTextByIndex: [Int: String]
    var eliminatedByIndex: [Int: Set<Int>]
    var hintUsedIndices: Set<Int>
    var savedAt: Date

    /// まだ答え合わせしていない問題の数
    var remaining: Int { max(0, questionIds.count - submittedIndices.count) }
}

/// 途中セッションの保存先（UserDefaults・資格ごと）
enum QuizSessionStore {
    private static func key(_ examKey: String) -> String { "quizSession.\(examKey)" }

    static func load(examKey: String, defaults: UserDefaults = .standard) -> QuizSession? {
        guard let data = defaults.data(forKey: key(examKey)) else { return nil }
        guard let s = try? JSONDecoder().decode(QuizSession.self, from: data), s.remaining > 0 else {
            // 壊れている・解き終わっているものは消す
            defaults.removeObject(forKey: key(examKey))
            return nil
        }
        return s
    }

    static func save(_ session: QuizSession, examKey: String, defaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: key(examKey))
    }

    static func clear(examKey: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(examKey))
    }
}
