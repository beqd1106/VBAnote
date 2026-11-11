import Foundation

/// 「要確認」の印。問題文・正解・解説がおかしいと感じた問題を、資格ごとに端末へ記録する。
/// 学習の記録（SwiftData）とは分けて UserDefaults に置く（データ構造を変えずに足せるため）。
enum QuestionFlags {
    static func key(_ examKey: String) -> String { "flags.\(examKey)" }

    static func ids(examKey: String, defaults: UserDefaults = .standard) -> [String] {
        defaults.stringArray(forKey: key(examKey)) ?? []
    }

    static func contains(_ id: String, examKey: String, defaults: UserDefaults = .standard) -> Bool {
        ids(examKey: examKey, defaults: defaults).contains(id)
    }

    /// 付け外しする。付けたら true を返す
    @discardableResult
    static func toggle(_ id: String, examKey: String, defaults: UserDefaults = .standard) -> Bool {
        var list = ids(examKey: examKey, defaults: defaults)
        let on: Bool
        if let i = list.firstIndex(of: id) { list.remove(at: i); on = false } else { list.append(id); on = true }
        defaults.set(list, forKey: key(examKey))
        return on
    }

    static func clear(examKey: String, defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key(examKey))
    }

    /// 開発者へ送る文面（問題ID・問題文の先頭）
    static func reportText(examName: String, questions: [QuizQuestion]) -> String {
        var lines = ["【資格note 要確認の問題】\(examName)・\(questions.count)問", ""]
        for q in questions {
            let head = q.question.replacingOccurrences(of: "\n", with: " ")
            lines.append("・\(q.id)：\(head.prefix(60))\(head.count > 60 ? "…" : "")")
        }
        lines += ["", "気になった点（任意）：", ""]
        return lines.joined(separator: "\n")
    }
}
