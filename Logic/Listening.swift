import Foundation
import AVFoundation
import MediaPlayer

// MARK: - チャプター

/// 聞き流しの1区切り（約3分・5問）。分野ごとの通し番号のほか、復習・お気に入り・通勤ミックスも同じ形で扱う。
struct ListeningChapter: Identifiable, Hashable {
    enum Kind: Hashable { case domain, review, weak, favorites, mix }
    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let questionIds: [String]

    /// 1問あたり読み上げ約35秒で見積もる（問題・間・答え・解説の頭）
    var minutes: Int { max(1, Int((Double(questionIds.count) * 35 / 60).rounded())) }
}

/// いまの資格のチャプター一覧を作る
@MainActor
enum ListeningCatalog {
    static let chapterSize = 5

    /// 分野ごとに5問ずつ区切ったチャプター（並びは問題IDの順で固定。毎回同じチャプターになる）
    static func domainChapters(_ domain: ExamDomain, repo: ContentRepository = .shared) -> [ListeningChapter] {
        let qs = repo.questions(in: domain).filter(isListenable).sorted { $0.id < $1.id }
        return stride(from: 0, to: qs.count, by: chapterSize).enumerated().map { n, start in
            let slice = qs[start..<min(start + chapterSize, qs.count)]
            return ListeningChapter(id: "\(domain.rawValue)-\(n + 1)", kind: .domain,
                                    title: "\(domain.shortTitle) \(n + 1)",
                                    subtitle: "\(slice.count)問", questionIds: slice.map(\.id))
        }
    }

    /// 通勤ミックス：復習期限 → 苦手分野 → まだ聞いていない問題 の順で、指定の分数に収まる数
    static func mix(minutes: Int, store: StudyStore, progress: ListeningProgress,
                    repo: ContentRepository = .shared) -> ListeningChapter {
        let count = max(chapterSize, Int(Double(minutes) * 60 / 35))
        var ids: [String] = []
        func add(_ qs: [QuizQuestion]) {
            for q in qs where ids.count < count && isListenable(q) && !ids.contains(q.id) { ids.append(q.id) }
        }
        add(store.dueReviewQuestions(limit: count))
        if let weak = store.weakAreaRecommendation()?.domain {
            add(repo.questions(in: weak).filter { !progress.heardIds.contains($0.id) }.shuffled())
        }
        add(repo.questions.filter { !progress.heardIds.contains($0.id) }.shuffled())
        add(repo.questions.shuffled())
        return ListeningChapter(id: "mix-\(minutes)", kind: .mix, title: "通勤ミックス \(minutes)分",
                                subtitle: "復習→苦手→新しい問題", questionIds: ids)
    }

    static func review(store: StudyStore) -> ListeningChapter? {
        let qs = store.dueReviewQuestions(limit: 30).filter(isListenable)
        guard !qs.isEmpty else { return nil }
        return ListeningChapter(id: "review", kind: .review, title: "復習待ち",
                                subtitle: "\(qs.count)問", questionIds: qs.map(\.id))
    }

    /// 間違えた・自信なしの問題（復習の期限がまだ先のものも含めて、耳でおさらいする）
    static func weak(store: StudyStore) -> ListeningChapter? {
        let ids = store.listeningMastery().weak
        let qs = ContentRepository.shared.questions.filter { ids.contains($0.id) && isListenable($0) }.prefix(30)
        guard !qs.isEmpty else { return nil }
        return ListeningChapter(id: "weak", kind: .weak, title: "間違えた問題",
                                subtitle: "\(qs.count)問", questionIds: qs.map(\.id))
    }

    static func favorites(store: StudyStore) -> ListeningChapter? {
        let qs = store.bookmarkedQuestions().filter(isListenable)
        guard !qs.isEmpty else { return nil }
        return ListeningChapter(id: "favorites", kind: .favorites, title: "お気に入り",
                                subtitle: "\(qs.count)問", questionIds: qs.map(\.id))
    }

    /// 耳だけで意味が通る問題か（図・表が前提の問題、3行以上のコードや疑似言語、極端に長い問題は外す）
    /// 聞き流し音声の原稿（資格note音声試作/gemini_listen/build_scripts.py の listenable）と同じ規則。変えるときは両方そろえる。
    static func isListenable(_ q: QuizQuestion) -> Bool {
        let text = q.question
        let visual = ["図", "表", "下記", "次の画面", "グラフ"].contains { text.contains($0 + "の") || text.contains($0 + "に") || text.contains($0 + "を") }
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return !visual && lines.count < 3 && text.count <= 220
    }
}

// MARK: - 聞いた記録（解いた記録とは別に持つ）

/// 聞き流しの進み具合。習得の判定には使わず、「どこまで聞いたか」と「聞いた日」だけを持つ。
struct ListeningProgress: Codable, Equatable {
    var completedChapterIds: Set<String> = []
    var heardIds: Set<String> = []
    var favoriteChapterIds: Set<String> = []
    /// 途中で止めたところ
    var lastChapterId: String?
    var lastIndex: Int = 0

    private static func key(_ examKey: String) -> String { "listening.\(examKey)" }

    static func load(examKey: String, defaults: UserDefaults = .standard) -> ListeningProgress {
        guard let data = defaults.data(forKey: key(examKey)),
              let p = try? JSONDecoder().decode(ListeningProgress.self, from: data) else { return ListeningProgress() }
        return p
    }

    func save(examKey: String, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key(examKey)) }
    }
}

// MARK: - 設定

/// 聞き流しの設定（端末に保存）
/// 画面側は同じキーの @AppStorage で読み書きする（Keys を参照）。
enum ListeningSettings {
    enum Keys {
        static let rate = "listening.rate"
        static let recallPause = "listening.recallPause"
        static let readChoices = "listening.readChoices"
        static let readExplanation = "listening.readExplanation"
        static let autoNext = "listening.autoNext"
        static let chime = "listening.chime"
    }
    /// 再生の速さ（表示用の倍率）
    static let rates: [Double] = [0.8, 1.0, 1.2, 1.5]
    private static var d: UserDefaults { .standard }
    static var rate: Double { d.object(forKey: Keys.rate) as? Double ?? 1.0 }
    /// 答えの前に考える間（秒）。0 なら「聞くだけ」
    static var recallPause: Double { d.object(forKey: Keys.recallPause) as? Double ?? 3 }
    static var readChoices: Bool { d.object(forKey: Keys.readChoices) as? Bool ?? true }
    static var readExplanation: Bool { d.object(forKey: Keys.readExplanation) as? Bool ?? true }
    /// チャプターが終わったら次へ自動で進む
    static var autoNext: Bool { d.object(forKey: Keys.autoNext) as? Bool ?? false }
    /// 考える時間に入るときに短い合図音を鳴らす
    static var chime: Bool { d.object(forKey: Keys.chime) as? Bool ?? true }

    /// AVSpeechUtterance の rate に変換（標準0.5を1.0倍とする）
    static func utteranceRate(_ r: Double) -> Float {
        min(AVSpeechUtteranceMaximumSpeechRate, max(AVSpeechUtteranceMinimumSpeechRate, Float(0.5 * r)))
    }
}

// MARK: - 読み上げ文

/// 1問分の読み上げ文を作る（耳で分かるように番号と答えの中身まで読む）
enum ListeningScript {
    /// 読み上げの部品。問題文と選択肢を分けて、選択肢のあいだに短い間を入れる（話し言葉に近づけるため）
    struct Parts { let question: String; let choices: [String]; let answer: String; let explanation: String }

    static let ordinals = ["1つ目", "2つ目", "3つ目", "4つ目", "5つ目", "6つ目"]

    /// - Parameter number: チャプター内の何問目か（1始まり）。nil なら番号を読まない
    static func parts(for q: QuizQuestion, readChoices: Bool, number: Int? = nil) -> Parts {
        let lead = number.map { ($0 == 1 ? "では、" : "") + "第\($0)問。" } ?? ""
        let choices = readChoices
            ? q.choices.enumerated().map { "\(ordinal($0.offset))、\(clean($0.element))。" }
            : []
        let answers = q.correctAnswers.sorted().map { "\($0 + 1)番の、\(clean(q.choices[$0]))" }.joined(separator: "と、")
        return Parts(question: lead + clean(q.question), choices: choices,
                     answer: "正解は、" + answers + "、です。", explanation: shortExplanation(q.explanation))
    }

    /// 問題の身につき具合
    enum Mastery { case new, weak, solid }

    /// 答えの前に考える間（秒）。苦手な問題は長め、身についた問題は短め。
    /// base が 0（聞くだけ）のときは変えない。
    static func thinkPause(base: Double, mastery: Mastery) -> Double {
        guard base > 0 else { return 0 }
        switch mastery {
        case .new: return base
        case .weak: return min(base * 1.5, base + 3)
        case .solid: return max(1, base * 0.5)
        }
    }

    static func ordinal(_ i: Int) -> String { i < ordinals.count ? ordinals[i] : "\(i + 1)つ目" }

    /// 解説は最初の2文まで（長すぎると区切りが崩れるため）
    static func shortExplanation(_ text: String) -> String {
        let sentences = clean(text).split(separator: "。", omittingEmptySubsequences: true)
        return sentences.prefix(2).map { $0 + "。" }.joined()
    }

    /// 読み上げに向かない記号を整える
    static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: "。")
            .replacingOccurrences(of: "「", with: "")
            .replacingOccurrences(of: "」", with: "")
            .replacingOccurrences(of: "（", with: "、")
            .replacingOccurrences(of: "）", with: "、")
    }
}

// MARK: - プレイヤー

/// 聞き流しのプレイヤー。端末の読み上げで「問題 → 考える間 → 答え → 解説」を流す。
/// 間は読み上げ側の待ち時間（postUtteranceDelay）で作るので、画面ロック中も途切れない。
@MainActor
final class ListeningPlayer: NSObject, ObservableObject {
    /// ロック画面の操作は1か所にだけ登録したいので、プレイヤーはアプリで1つ
    static let shared = ListeningPlayer()

    enum Phase: Equatable { case question, thinking, answer, explanation, chapterDone }

    @Published private(set) var chapter: ListeningChapter?
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var index = 0
    @Published private(set) var phase: Phase = .question
    @Published private(set) var isPlaying = false
    /// スリープタイマー：この時刻を過ぎたら次の区切りで止める／チャプター終わりで止める
    @Published var sleepAt: Date?
    @Published var stopAtChapterEnd = false

    /// チャプターを聞き終えた時（記録用）
    var onChapterCompleted: ((ListeningChapter) -> Void)?
    /// 1問の答えまで聞いた時（記録用）
    var onQuestionHeard: ((QuizQuestion) -> Void)?
    /// 自動で次のチャプターを求める時（nil を返したら止める）
    var nextChapterProvider: ((ListeningChapter) -> (ListeningChapter, [QuizQuestion])?)?
    /// ロック画面の「お気に入り」から呼ぶ
    var onToggleFavorite: ((QuizQuestion) -> Void)?
    /// 問題ごとの身につき具合（考える間の長さに使う）。nil なら全問同じ間
    var masteryProvider: ((QuizQuestion) -> ListeningScript.Mastery)?

    private let synth = AVSpeechSynthesizer()
    /// いま流している1問分の読み上げ（最後の1つが終わったら次の問題へ）
    private var pending: [AVSpeechUtterance] = []
    private var phaseByUtterance: [ObjectIdentifier: Phase] = [:]
    private var generation = 0
    /// 読み終わったら合図音を鳴らす読み上げ（問題の最後の部品）
    private var chimeAfter: ObjectIdentifier?
    private lazy var chimePlayer: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "answer_chime", withExtension: "wav") else { return nil }
        let p = try? AVAudioPlayer(contentsOf: url)
        p?.volume = 0.6
        p?.prepareToPlay()
        return p
    }()

    var current: QuizQuestion? { questions.indices.contains(index) ? questions[index] : nil }

    private override init() {
        super.init()
        synth.delegate = self
        setupRemoteCommands()
    }

    // MARK: 操作

    func load(_ chapter: ListeningChapter, questions: [QuizQuestion], startAt: Int = 0, autoplay: Bool = true) {
        stopSpeaking()
        self.chapter = chapter
        self.questions = questions
        self.index = min(max(0, startAt), max(0, questions.count - 1))
        self.phase = .question
        if autoplay { play() } else { updateNowPlaying() }
    }

    func play() {
        guard current != nil else { return }
        activateSession()
        if phase == .chapterDone { index = 0; phase = .question }
        if synth.isPaused {
            synth.continueSpeaking()
        } else {
            speakCurrent()
        }
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        if synth.isSpeaking { synth.pauseSpeaking(at: .word) }
        isPlaying = false
        updateNowPlaying()
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func jump(to newIndex: Int) {
        guard questions.indices.contains(newIndex), newIndex != index || phase == .chapterDone else { return }
        let wasPlaying = isPlaying || phase == .chapterDone
        stopSpeaking()
        index = newIndex
        phase = .question
        if wasPlaying { play() } else { updateNowPlaying() }
    }

    func next() { index + 1 < questions.count ? jump(to: index + 1) : finishChapter() }
    func previous() { jump(to: max(0, index - 1)) }

    func stop() {
        stopSpeaking()
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: 読み上げ

    private func stopSpeaking() {
        generation += 1
        pending = []
        phaseByUtterance = [:]
        chimeAfter = nil
        if synth.isSpeaking || synth.isPaused { synth.stopSpeaking(at: .immediate) }
    }

    private func speakCurrent() {
        guard let q = current else { return }
        stopSpeaking()
        let parts = ListeningScript.parts(for: q, readChoices: ListeningSettings.readChoices, number: index + 1)
        let rate = ListeningSettings.utteranceRate(ListeningSettings.rate)
        let voice = Self.bestJapaneseVoice
        func make(_ text: String, _ phase: Phase, after: TimeInterval) -> AVSpeechUtterance {
            let u = AVSpeechUtterance(string: text)
            u.voice = voice
            u.rate = rate
            u.postUtteranceDelay = after
            phaseByUtterance[ObjectIdentifier(u)] = phase
            return u
        }
        // 問題 →（短い間）→ 選択肢を1つずつ（短い間）→ 考える間 → 答え → 解説
        let think = max(0.6, ListeningScript.thinkPause(base: ListeningSettings.recallPause,
                                                         mastery: masteryProvider?(q) ?? .new))
        var list = [make(parts.question, .question, after: parts.choices.isEmpty ? think : 0.45)]
        for (i, c) in parts.choices.enumerated() {
            list.append(make(c, .question, after: i == parts.choices.count - 1 ? think : 0.25))
        }
        if ListeningSettings.chime, think >= 1, let lastQuestion = list.last {
            chimeAfter = ObjectIdentifier(lastQuestion)
        }
        list.append(make(parts.answer, .answer, after: 0.6))
        if ListeningSettings.readExplanation, !parts.explanation.isEmpty {
            list.append(make(parts.explanation, .explanation, after: 1.1))
        }
        pending = list
        phase = .question
        list.forEach { synth.speak($0) }
    }

    /// 端末にある日本語の声のうち、品質の高いものを優先
    static var bestJapaneseVoice: AVSpeechSynthesisVoice? {
        let ja = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == "ja-JP" }
        return ja.first { $0.quality == .premium } ?? ja.first { $0.quality == .enhanced }
            ?? AVSpeechSynthesisVoice(language: "ja-JP")
    }

    private func utteranceStarted(_ u: AVSpeechUtterance) {
        guard let p = phaseByUtterance[ObjectIdentifier(u)] else { return }
        phase = p
        if p == .answer, let q = current { onQuestionHeard?(q) }
        updateNowPlaying()
    }

    private func utteranceFinished(_ u: AVSpeechUtterance) {
        if phaseByUtterance[ObjectIdentifier(u)] == .question { phase = .thinking }
        if chimeAfter == ObjectIdentifier(u) {
            chimePlayer?.currentTime = 0
            chimePlayer?.play()
        }
        guard let last = pending.last, last === u else { return }
        // 1問終わり：スリープタイマーを確認して次へ
        if let sleepAt, Date() >= sleepAt {
            self.sleepAt = nil
            pause(); return
        }
        if index + 1 < questions.count {
            index += 1
            speakCurrent()
            updateNowPlaying()
        } else {
            finishChapter()
        }
    }

    private func finishChapter() {
        stopSpeaking()
        phase = .chapterDone
        if let chapter { onChapterCompleted?(chapter) }
        if stopAtChapterEnd {
            stopAtChapterEnd = false
            isPlaying = false
            updateNowPlaying()
            return
        }
        if ListeningSettings.autoNext, let chapter, let next = nextChapterProvider?(chapter), !next.1.isEmpty {
            load(next.0, questions: next.1, autoplay: true)
        } else {
            isPlaying = false
            updateNowPlaying()
        }
    }

    // MARK: 音声セッション・ロック画面

    private func activateSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? s.setActive(true)
    }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        c.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        c.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlay(); return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in self?.next(); return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in self?.previous(); return .success }
        c.likeCommand.localizedTitle = "お気に入り"
        c.likeCommand.addTarget { [weak self] _ in
            guard let self, let q = self.current else { return .noActionableNowPlayingItem }
            self.onToggleFavorite?(q)
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let q = current, let chapter else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: String(q.question.prefix(40)),
            MPMediaItemPropertyArtist: "\(chapter.title)・\(index + 1)/\(questions.count)問",
            MPMediaItemPropertyAlbumTitle: "資格note 聞き流し",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }
}

extension ListeningPlayer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceStarted(utterance) }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.utteranceFinished(utterance) }
    }
}
