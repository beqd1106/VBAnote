import Foundation

/// バンドル内JSONから学習コンテンツを読み込み、メモリにキャッシュする。
/// オフラインで完全に動作する（ネットワーク不要）。
final class ContentRepository {
    static let shared = ContentRepository()

    let questions: [QuizQuestion]
    let terms: [TermCard]
    let lessons: [Lesson]
    let services: [GenAIToolItem]
    /// 用語集（長い語を優先マッチできるよう term.count 降順で保持）
    let glossary: [GlossaryEntry]

    private let questionsById: [String: QuizQuestion]
    /// 問題ID → その問題を確認問題に含むレッスン（レッスン→問題の逆引き）
    private let lessonByQuestionId: [String: Lesson]
    /// 分野ごとの (レッスン, キーワード集合)。未割当の問題を関連レッスンへ寄せる用。
    private let lessonKeywordsByDomain: [ExamDomain: [(lesson: Lesson, keywords: Set<String>)]]

    private init() {
        self.questions = Self.load("questions", as: [QuizQuestion].self)
        self.terms     = Self.load("terms", as: [TermCard].self)
        self.lessons   = Self.load("lessons", as: [Lesson].self)
        self.services  = Self.load("services", as: [GenAIToolItem].self)
        // glossary.json が無い環境でも落ちないよう任意ロード
        let g = Self.loadOptional("glossary", as: [GlossaryEntry].self) ?? []
        self.glossary  = g.sorted { $0.term.count > $1.term.count }
        let byId = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        self.questionsById = byId

        // レッスン←問題の逆引きと、分野別キーワード集合を構築
        var qToLesson: [String: Lesson] = [:]
        var kwByDomain: [ExamDomain: [(lesson: Lesson, keywords: Set<String>)]] = [:]
        for lesson in lessons {
            var kw = Set<String>()
            for qid in (lesson.basicQuizIds ?? []) + lesson.quizIds {
                qToLesson[qid] = lesson
                if let q = byId[qid] {
                    kw.insert(Self.normKeyword(q.service))
                    q.tags.forEach { kw.insert(Self.normKeyword($0)) }
                }
            }
            kwByDomain[lesson.domain, default: []].append((lesson, kw))
        }
        self.lessonByQuestionId = qToLesson
        self.lessonKeywordsByDomain = kwByDomain
    }

    private static func normKeyword(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "amazon", with: "")
            .replacingOccurrences(of: "aws", with: "")
            .filter { !$0.isWhitespace && $0 != "-" && $0 != "・" }
    }

    // MARK: - 検索ヘルパ

    func question(id: String) -> QuizQuestion? { questionsById[id] }

    /// 指定した問題に最も関連する解説レッスンを返す（問題→レッスンの相互リンク用）。
    /// ①その問題を確認問題に含むレッスン → ②同分野でタグ/サービスが最も重なるレッスン → ③同分野の先頭。
    func lesson(forQuestion q: QuizQuestion) -> Lesson? {
        if let l = lessonByQuestionId[q.id] { return l }
        let candidates = lessonKeywordsByDomain[q.domain] ?? []
        var qk = Set<String>([Self.normKeyword(q.service)])
        q.tags.forEach { qk.insert(Self.normKeyword($0)) }
        let best = candidates.max { a, b in a.keywords.intersection(qk).count < b.keywords.intersection(qk).count }
        if let best, !best.keywords.intersection(qk).isEmpty { return best.lesson }
        return lessons(in: q.domain).first
    }

    func questions(in domain: ExamDomain) -> [QuizQuestion] {
        questions.filter { $0.domain == domain }
    }

    /// 模試に使う代表的な問題プール。反復ドリル（基礎固め・変種が多い）は本番の難易度感から
    /// 外れるため除外し、基本問題・中級問題・オリジナル問題で本番に近い構成にする。
    /// レッスン用のやさしい基礎問題も同じ理由で除外する。
    var examPool: [QuizQuestion] {
        questions.filter { !$0.tags.contains("ドリル") && !$0.tags.contains("基礎") }
    }

    func examPool(in domain: ExamDomain) -> [QuizQuestion] {
        examPool.filter { $0.domain == domain }
    }

    func lessons(in domain: ExamDomain) -> [Lesson] {
        lessons.filter { $0.domain == domain }
    }

    func terms(in domain: ExamDomain) -> [TermCard] {
        terms.filter { $0.domain == domain }
    }

    func searchTerms(_ keyword: String) -> [TermCard] {
        let k = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return terms }
        return terms.filter {
            $0.term.lowercased().contains(k)
            || $0.shortDescription.lowercased().contains(k)
            || $0.beginnerExplanation.lowercased().contains(k)
        }
    }

    /// 模擬試験用：公式配点に近い比率で出題を組み立てる（反復ドリルは除外＝本番相応）。
    /// 問題数が限られていても各分野の比率を保つよう抽選する。
    func buildMockExam(count: Int) -> [QuizQuestion] {
        var picked: [QuizQuestion] = []
        for domain in ExamDomain.allCases {
            let target = max(1, Int((Double(count) * domain.weight).rounded()))
            picked.append(contentsOf: examPool(in: domain).shuffled().prefix(target))
        }
        // 不足・超過を調整
        if picked.count > count {
            picked = Array(picked.shuffled().prefix(count))
        } else if picked.count < count {
            let ids = Set(picked.map(\.id))
            let remaining = examPool.filter { !ids.contains($0.id) }
            picked.append(contentsOf: remaining.shuffled().prefix(count - picked.count))
        }
        return picked.shuffled()
    }

    /// 分野別ミニ模試：指定分野の代表問題からランダムに出題する。
    func buildDomainMock(domain: ExamDomain, count: Int) -> [QuizQuestion] {
        Array(examPool(in: domain).shuffled().prefix(count))
    }

    // MARK: - ローダ

    private static func load<T: Decodable>(_ name: String, as type: T.Type) -> T {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            fatalError("リソース \(name).json が見つかりません。project.yml のResources設定を確認してください。")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("\(name).json のデコードに失敗しました: \(error)")
        }
    }

    /// 任意リソース（無ければ nil を返す。glossary など後付けデータ用）
    private static func loadOptional<T: Decodable>(_ name: String, as type: T.Type) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
