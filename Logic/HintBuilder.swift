import Foundation

/// 「分からないときのヒント」を、問題データから組み立てる純粋ロジック。
///
/// 1699問すべてにヒント文を持たせるのは現実的でないため、
/// 既存のデータ（初心者向け補足・用語集・分野/小テーマ）から**答えを明かさない範囲で**生成する。
/// 段階は2つ。
///   1. 考え方（どこを見て考えるか）。問題ごとに書いた <exam>_hints.json があれば最優先
///   2. 選択肢をしぼる（違う選択肢を消し、なぜ違うかも見せる）
/// 3段目の「教材で確かめる」は画面側（QuizPlayerView）が担う。
enum HintBuilder {

    // MARK: - 段階1：着眼点

    /// 答えそのものには触れずに、考える取っかかりを1つ返す。
    static func focusHint(for q: QuizQuestion, glossary: [GlossaryEntry] = [],
                          hints: [String: String] = [:]) -> String {
        // 0) 問題ごとに書いたヒント（答えを漏らしていないかは作成時に機械チェック済み。念のためここでも確かめる）
        if let h = hints[q.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !h.isEmpty, !revealsAnswer(h, for: q) {
            return h
        }
        // 1) 初心者向け補足があれば最優先。ただし正解を書いてしまっているものは使わない。
        if let note = q.beginnerNote?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty, !revealsAnswer(note, for: q) {
            return note
        }

        // 2) 問題文に出てくる用語の説明（正解選択肢に含まれる語はヒントにしない）
        if let entry = glossaryHint(for: q, glossary: glossary) {
            return "「\(entry.term)」とは：\(entry.explanation)"
        }

        // 3) 最後の手段：分野と小テーマから考える方向を示す
        let theme = q.service.trimmingCharacters(in: .whitespacesAndNewlines)
        if !theme.isEmpty {
            return "「\(theme)」まわりの知識が問われています。関係のない選択肢から順に消してみましょう。"
        }
        return "出題分野は「\(q.domain.shortTitle)」。用語の意味を思い出しながら、確実に違う選択肢を消していきましょう。"
    }

    /// 問題文に含まれ、かつ正解選択肢には含まれない用語を1件選ぶ（長い語を優先）。
    private static func glossaryHint(for q: QuizQuestion, glossary: [GlossaryEntry]) -> GlossaryEntry? {
        let answers = q.correctAnswers.compactMap { idx -> String? in
            q.choices.indices.contains(idx) ? q.choices[idx] : nil
        }
        return glossary
            .filter { $0.term.count >= 2 }
            .sorted { $0.term.count > $1.term.count }
            .first { entry in
                q.question.contains(entry.term)
                    && !answers.contains(where: { $0.contains(entry.term) })
                    && !revealsAnswer(entry.explanation, for: q)
            }
    }

    /// ヒント文が正解選択肢を書いてしまっていないか。
    /// 「AWS Budgets（予算アラート）」なら「Budgets」「予算アラート」も見る（頭の AWS/Amazon と括弧の補足を外した芯）。
    static func revealsAnswer(_ text: String, for q: QuizQuestion) -> Bool {
        let wrong = q.choices.indices.filter { !q.correctAnswers.contains($0) }.map { q.choices[$0] }
        for term in answerTerms(for: q) where !wrong.contains(where: { $0.contains(term) }) {
            if text.contains(term) { return true }
        }
        return false
    }

    /// 正解選択肢から、ヒントに出てはいけない語（3字以上）を取り出す
    static func answerTerms(for q: QuizQuestion) -> [String] {
        var out: [String] = []
        for idx in q.correctAnswers where q.choices.indices.contains(idx) {
            let full = q.choices[idx].trimmingCharacters(in: .whitespacesAndNewlines)
            var core = full.replacingOccurrences(of: "[（(][^）)]*[)）]", with: "", options: .regularExpression)
            core = core.replacingOccurrences(of: "^(AWS|Amazon)\\s*", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            // 短すぎる語（「はい」など）は偶然一致しやすいので判定から外す
            if core.count >= 3 { out.append(core) }
            if let r = full.range(of: "[（(]([^）)]+)[)）]", options: .regularExpression) {
                let inner = String(full[r].dropFirst().dropLast())
                if inner.count >= 3 { out.append(inner) }
            }
        }
        return out
    }

    // MARK: - 段階2：選択肢をしぼる

    /// この問題で選択肢の絞り込みができるか（不正解が2つ以上ないと意味がない）
    static func canEliminate(_ q: QuizQuestion) -> Bool {
        !eliminatedChoices(for: q).isEmpty
    }

    /// 消してよい不正解選択肢。問題IDから決まる固定の結果で、開き直しても変わらない。
    /// 単一選択は「残り2択」まで、複数選択は不正解の半分を消す。
    /// 理由の文が正解の名前を出してしまう選択肢は、なるべく消さずに残す（理由を見せると答えが分かるため）。
    static func eliminatedChoices(for q: QuizQuestion) -> Set<Int> {
        let wrong = q.choices.indices.filter { !q.correctAnswers.contains($0) }
        guard wrong.count >= 2 else { return [] }

        let removeCount = q.isMultipleSelect ? max(1, wrong.count / 2) : wrong.count - 1
        guard removeCount >= 1 else { return [] }

        // 毎回「上から消える」と癖になるので、問題IDで開始位置をずらす
        let offset = stableHash(q.id) % wrong.count
        let rotated = Array(wrong[offset...] + wrong[..<offset])
        let safeFirst = rotated.filter { reason(for: $0, in: q) != nil } + rotated.filter { reason(for: $0, in: q) == nil }
        return Set(safeFirst.prefix(removeCount))
    }

    /// 消した選択肢が「なぜ違うか」。答えを明かす理由・空の理由は出さない（nil）。
    static func reason(for index: Int, in q: QuizQuestion) -> String? {
        guard let r = q.wrongReason(for: index)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !r.isEmpty, !revealsAnswer(r, for: q) else { return nil }
        return r
    }

    /// 端末やアプリの起動ごとに変わらないハッシュ（Swiftの hashValue は起動ごとに変わるため自前で持つ）
    private static func stableHash(_ s: String) -> Int {
        var h = 5381
        for b in s.utf8 { h = ((h &* 33) &+ Int(b)) & 0x00FF_FFFF }
        return abs(h)
    }
}
