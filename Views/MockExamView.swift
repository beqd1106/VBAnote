import SwiftUI

/// 模試の実行設定（本番65問 or 分野別ミニ模試）
struct MockRunConfig: Identifiable {
    let id = UUID()
    let title: String
    let questions: [QuizQuestion]
    let timeLimitMinutes: Int
    let isFullMock: Bool
    /// 分野別ミニ模試のときの分野名（本番模試は nil）
    let domainTitle: String?
}

/// 模擬試験のスタート画面
struct MockExamStartView: View {
    @EnvironmentObject var store: StudyStore
    @State private var run: MockRunConfig?

    private let repo = ContentRepository.shared
    /// 本番に近い問題数。プールが足りない場合は利用可能数に丸める。
    private var fullCount: Int { min(ExamInfo.mockCount, repo.examPool.count) }
    private let domainMockSize = 20

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    fullMockCard
                    historyCard
                    domainMockSection
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("模擬試験")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $run) { cfg in
            MockExamRunView(config: cfg)
        }
    }

    // MARK: - 本番模試

    private var fullMockCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("本番模試").font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.navy)
                infoRow("doc.text.fill", "出題数", "\(fullCount)問（公式配点に近い比率）")
                infoRow("timer", "制限時間", "\(minutes(for: fullCount))分")
                infoRow("chart.pie.fill", "結果", "分野別スコアと弱点を表示")
                Text("反復ドリルと基礎問題は除外し、本番に近い難易度で出題します。※\(ExamInfo.mockNote)")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                PrimaryButton(title: "本番模試を始める", icon: "play.fill") {
                    run = MockRunConfig(title: "模擬試験",
                                        questions: repo.buildMockExam(count: fullCount),
                                        timeLimitMinutes: minutes(for: fullCount),
                                        isFullMock: true, domainTitle: nil)
                }
            }
        }
    }

    // MARK: - スコア推移

    @ViewBuilder private var historyCard: some View {
        let results = store.mockResults()
        if !results.isEmpty {
            let latest = results[0]
            let best = results.map(\.scaledScore).max() ?? latest.scaledScore
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    HStack {
                        Label("これまでの模試", systemImage: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.navy)
                        Spacer()
                        Text("\(results.count)回").captionStyle()
                    }
                    HStack(spacing: Theme.Space.l) {
                        stat("前回", "\(latest.scaledScore)", latest.isPassingScore ? Theme.green : Theme.orange)
                        stat("自己ベスト", "\(best)", best >= ExamInfo.passScore ? Theme.green : Theme.orange)
                    }
                    // 直近の推移（最大6件・古い→新しい）
                    let recent = Array(results.prefix(6).reversed())
                    if recent.count >= 2 {
                        MockTrendBar(scores: recent.map(\.scaledScore))
                            .frame(height: 44)
                    }
                }
            }
        }
    }

    // MARK: - 分野別ミニ模試

    private var domainMockSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: "分野別ミニ模試")
            Text("弱点分野を\(domainMockSize)問で集中演習（本番相応の難易度）")
                .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            ForEach(ExamDomain.allCases) { domain in
                Button {
                    let qs = repo.buildDomainMock(domain: domain, count: domainMockSize)
                    run = MockRunConfig(title: "\(domain.shortTitle)ミニ模試",
                                        questions: qs,
                                        timeLimitMinutes: minutes(for: qs.count),
                                        isFullMock: false, domainTitle: domain.title)
                } label: {
                    Card(padding: Theme.Space.m) {
                        HStack(spacing: Theme.Space.m) {
                            Image(systemName: domain.systemIcon).font(.system(size: 18)).foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(domain.color)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(domain.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text("\(min(domainMockSize, repo.examPool(in: domain).count))問").captionStyle()
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
    }

    private func minutes(for count: Int) -> Int {
        max(5, Int((Double(ExamInfo.mockMinutes) * Double(count) / Double(max(ExamInfo.mockCount, 1))).rounded()))
    }

    private func stat(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).captionStyle()
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(color)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: Theme.Space.s) {
            Image(systemName: icon).foregroundStyle(Theme.orange).frame(width: 24)
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value).font(.system(size: 14)).foregroundStyle(Theme.ink)
        }
    }
}

/// 模試スコアの簡易推移バー（古い→新しい）
struct MockTrendBar: View {
    let scores: [Int]
    var body: some View {
        GeometryReader { geo in
            let maxS = 1000.0
            let w = geo.size.width / CGFloat(max(scores.count, 1))
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(scores.enumerated()), id: \.offset) { _, s in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(s >= ExamInfo.passScore ? Theme.green : Theme.orange)
                            .frame(height: max(4, geo.size.height * 0.7 * CGFloat(Double(s) / maxS)))
                        Text("\(s)").font(.system(size: 9)).foregroundStyle(Theme.inkSoft)
                    }
                    .frame(width: w - 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

/// 模擬試験の本体（即時フィードバックなし・タイマーあり）
struct MockExamRunView: View {
    let config: MockRunConfig
    @State private var questions: [QuizQuestion]

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var index = 0
    @State private var answers: [String: Set<Int>] = [:]
    @State private var remaining: TimeInterval
    @State private var result: MockExamResult?
    /// 採点時に確定する、直前の本番模試スコア（推移比較用）
    @State private var previousScore: Int?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(config: MockRunConfig) {
        self.config = config
        _questions = State(initialValue: config.questions)
        _remaining = State(initialValue: TimeInterval(config.timeLimitMinutes * 60))
    }

    private var current: QuizQuestion { questions[index] }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if let result {
                    MockExamResultView(result: result, isFullMock: config.isFullMock,
                                       domainTitle: config.domainTitle, previousScore: previousScore) { dismiss() }
                } else if questions.isEmpty {
                    EmptyStateView(icon: "tray", title: "問題がありません", message: "別の分野をお試しください。")
                } else {
                    examBody
                }
            }
            .navigationTitle(config.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if result == nil {
                        Button("中断") { dismiss() }.foregroundStyle(Theme.red)
                    }
                }
                ToolbarItem(placement: .principal) {
                    if result == nil && !questions.isEmpty {
                        Label(timeString, systemImage: "timer")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(remaining < 60 ? Theme.red : Theme.navy)
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            guard result == nil, !questions.isEmpty else { return }
            remaining -= 1
            if remaining <= 0 { finish() }
        }
    }

    private var examBody: some View {
        VStack(spacing: 0) {
            ProgressBar(value: Double(index + 1) / Double(questions.count)).padding(Theme.Space.l)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    HStack {
                        Text("第\(index + 1)問 / \(questions.count)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                        Spacer()
                        DomainChip(domain: current.domain)
                    }
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            if current.isMultipleSelect {
                                TagChip(text: "複数選択（\(current.correctAnswers.count)つ）", color: Theme.teal)
                            }
                            GlossaryText(text: current.question, size: 17, weight: .semibold, color: Theme.ink)
                        }
                    }
                    ForEach(Array(current.choices.enumerated()), id: \.offset) { i, choice in
                        choiceRow(i, choice)
                    }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, 120)
            }
            HStack(spacing: Theme.Space.m) {
                if index > 0 {
                    SecondaryButton(title: "前へ", icon: "chevron.left") { index -= 1 }
                }
                if index + 1 < questions.count {
                    PrimaryButton(title: "次へ", icon: "chevron.right") { index += 1 }
                } else {
                    PrimaryButton(title: "採点する", icon: "checkmark") { finish() }
                }
            }
            .padding(Theme.Space.l)
            .background(.ultraThinMaterial)
        }
    }

    private func choiceRow(_ i: Int, _ choice: String) -> some View {
        let sel = answers[current.id]?.contains(i) ?? false
        return Button { toggle(i) } label: {
            HStack(alignment: .top, spacing: Theme.Space.m) {
                Image(systemName: sel ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(sel ? Theme.blue : Theme.line).font(.system(size: 20))
                Text(choice).font(.system(size: 15)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Theme.Space.m).frame(maxWidth: .infinity, alignment: .leading)
            .background(sel ? Theme.blueSoft : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .stroke(sel ? Theme.blue : Theme.line, lineWidth: 1.2))
        }.buttonStyle(.plain)
    }

    private func toggle(_ i: Int) {
        var set = answers[current.id] ?? []
        if current.isMultipleSelect {
            if set.contains(i) { set.remove(i) } else { set.insert(i) }
        } else {
            set = [i]
        }
        answers[current.id] = set
    }

    private func finish() {
        guard result == nil, !questions.isEmpty else { return }
        // 直前の本番模試スコア（保存前に取得）
        previousScore = store.latestMockScaledScore

        var correct = 0
        var byDomain: [ExamDomain: (Int, Int)] = [:]
        for q in questions {
            let sel = answers[q.id] ?? []
            let ok = q.isCorrect(selected: sel)
            if ok { correct += 1 }
            var t = byDomain[q.domain] ?? (0, 0)
            t.1 += 1; if ok { t.0 += 1 }
            byDomain[q.domain] = t
            store.recordAnswer(question: q, correct: ok, isMock: true)
        }
        let rate = questions.isEmpty ? 0 : Double(correct) / Double(questions.count)
        let scaled = Int((rate * 1000).rounded())
        let entries = ExamDomain.allCases.compactMap { d -> DomainScoreEntry? in
            guard let t = byDomain[d] else { return nil }
            return DomainScoreEntry(domainRaw: d.rawValue, correct: t.0, total: t.1)
        }
        let r = MockExamResult(scaledScore: scaled, correctCount: correct,
                               totalCount: questions.count, domainScores: entries)
        // 本番模試のみ履歴（PassProbabilityの最新スコア）へ保存。ミニ模試は履歴を汚さない。
        if config.isFullMock { store.saveMockResult(r) }
        result = r
    }

    private var timeString: String {
        let m = Int(remaining) / 60, s = Int(remaining) % 60
        return String(format: "%d:%02d", m, s)
    }
}

/// 模擬試験の結果
struct MockExamResultView: View {
    let result: MockExamResult
    var isFullMock: Bool = true
    var domainTitle: String? = nil
    var previousScore: Int? = nil
    var onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.l) {
                if isFullMock {
                    fullScoreHeader
                } else {
                    domainScoreHeader
                }

                if isFullMock, result.domainScores.count > 1 {
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            Text("分野別スコア").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                            ForEach(result.domainScores, id: \.domainRaw) { e in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(e.domain.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                                        Spacer()
                                        Text("\(e.correct)/\(e.total)（\(Int(e.rate*100))%）")
                                            .font(.system(size: 13)).foregroundStyle(e.rate >= 0.7 ? Theme.green : Theme.orange)
                                    }
                                    ProgressBar(value: e.rate, color: e.domain.color, height: 8)
                                }
                            }
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        Text("おすすめの次の一手").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        ForEach(recommendations, id: \.self) { rec in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill").foregroundStyle(Theme.blue).font(.system(size: 14))
                                Text(rec).font(.system(size: 14)).foregroundStyle(Theme.ink)
                            }
                        }
                    }
                }

                PrimaryButton(title: "終わる", icon: "checkmark") { onClose() }
            }
            .padding(Theme.Space.l)
        }
    }

    // 本番模試：1000点満点＋合格ライン＋前回比
    private var fullScoreHeader: some View {
        VStack(spacing: Theme.Space.m) {
            ScoreRing(value: Double(result.scaledScore)/1000,
                      color: result.isPassingScore ? Theme.green : Theme.orange,
                      label: "\(result.scaledScore)", caption: "/ 1000")
                .frame(width: 180, height: 180).padding(.top, Theme.Space.xl)

            Text(result.isPassingScore ? "合格ライン（目安\(ExamInfo.passScore)）を超えました！" : "合格ライン（目安\(ExamInfo.passScore)）まであと少し")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(result.isPassingScore ? Theme.green : Theme.orange)
                .multilineTextAlignment(.center)
            Text("正答 \(result.correctCount)/\(result.totalCount)問（\(Int(result.correctRate*100))%）").captionStyle()

            if let prev = previousScore {
                let delta = result.scaledScore - prev
                HStack(spacing: 6) {
                    Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                    Text(delta >= 0 ? "前回より +\(delta)点" : "前回より \(delta)点")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(delta >= 0 ? Theme.green : Theme.red)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Theme.bg).clipShape(Capsule())
            }
        }
    }

    // 分野別ミニ模試：正答率中心（合格ライン表記はしない）
    private var domainScoreHeader: some View {
        VStack(spacing: Theme.Space.m) {
            ScoreRing(value: result.correctRate,
                      color: result.correctRate >= 0.7 ? Theme.green : Theme.orange,
                      label: "\(Int(result.correctRate*100))%", caption: "正答率")
                .frame(width: 170, height: 170).padding(.top, Theme.Space.xl)
            Text("\(domainTitle ?? "分野別")ミニ模試")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
            Text("正答 \(result.correctCount)/\(result.totalCount)問").captionStyle()
        }
    }

    private var recommendations: [String] {
        if isFullMock {
            let weak = result.domainScores.filter { $0.rate < 0.7 }.sorted { $0.rate < $1.rate }
            if weak.isEmpty {
                return ["安定して合格ラインを超えています。間違えた問題の復習で仕上げましょう。"]
            }
            return weak.prefix(3).map { "「\($0.domain.title)」を重点復習しましょう（正答率\(Int($0.rate*100))%）。" }
        } else {
            if result.correctRate >= 0.7 {
                return ["この分野は good です。他の分野のミニ模試や本番模試に挑戦しましょう。"]
            }
            return ["この分野はレッスンの基礎問題と反復ドリルで固め直すのがおすすめです。"]
        }
    }
}
