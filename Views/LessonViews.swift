import SwiftUI

struct LessonListView: View {
    let lessons = ContentRepository.shared.lessons
    @EnvironmentObject var store: StudyStore

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: Theme.Space.m) {
                    overallProgress
                    ForEach(ExamDomain.allCases) { domain in
                        let items = lessons.filter { $0.domain == domain }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: Theme.Space.s) {
                                HStack {
                                    DomainChip(domain: domain)
                                    Spacer()
                                    domainProgressLabel(domain, total: items.count)
                                }
                                ForEach(items) { lesson in
                                    NavigationLink { LessonDetailView(lesson: lesson) } label: {
                                        lessonRow(lesson)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("レッスン")
        .navigationBarTitleDisplayMode(.inline)
    }

    // 全体の履修進捗バー
    private var overallProgress: some View {
        let done = store.completedLessonCount
        let total = lessons.count
        let rate = total == 0 ? 0 : Double(done) / Double(total)
        return Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack {
                    Text("学習の進み具合").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.navy)
                    Spacer()
                    Text("\(done) / \(total) レッスン").captionStyle()
                }
                ProgressView(value: rate).tint(Theme.orange)
                Text(done == total && total > 0 ? "全レッスン履修おつかれさまでした。"
                                                : "解説を読んで確認問題を解くと、履修済みになります。")
                    .captionStyle()
            }
        }
    }

    private func domainProgressLabel(_ domain: ExamDomain, total: Int) -> some View {
        let done = store.completedLessonCount(in: domain)
        let allDone = done == total && total > 0
        return HStack(spacing: 4) {
            if allDone {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Theme.green)
            }
            Text("\(done)/\(total)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(allDone ? Theme.green : Theme.inkSoft)
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        let done = store.isLessonCompleted(lesson.id)
        return Card(padding: Theme.Space.m) {
            HStack(spacing: Theme.Space.m) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "text.book.closed.fill").foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(lesson.domain.color)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.green)
                            .background(Circle().fill(.white).frame(width: 14, height: 14))
                            .offset(x: 5, y: 5)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(lesson.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(done ? Theme.inkSoft : Theme.ink)
                        if done {
                            Text("履修済み")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.green)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Theme.green.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    Text(questionSummary(lesson)).captionStyle()
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
            }
        }
    }
}

/// レッスン一覧の補足行（基礎問題があれば併記する）
private func questionSummary(_ lesson: Lesson) -> String {
    let basic = lesson.basicQuizIds?.count ?? 0
    let quiz = patternCountLabel(lesson.quizIds.count)
    let parts = basic > 0 ? "基礎\(patternCountLabel(basic))・確認\(quiz)" : "確認問題\(quiz)"
    return "約\(lesson.estimatedMinutes)分・\(parts)"
}

// MARK: - 問題パターン（基礎・確認を5問ずつのA/B/Cに分ける）

/// 1パターンの問題数
private let patternSize = 5

/// 問題IDを先頭から5問ずつに区切る（15問ならA/B/Cの3パターン）
private func patterns(_ ids: [String]) -> [[String]] {
    stride(from: 0, to: ids.count, by: patternSize).map { Array(ids[$0..<min($0 + patternSize, ids.count)]) }
}

/// 「5問×3」のような表記。5で割り切れないときは総数で出す
private func patternCountLabel(_ count: Int) -> String {
    count > patternSize && count % patternSize == 0 ? "\(patternSize)問×\(count / patternSize)" : "\(count)問"
}

/// レッスン内で選ばれた問題パターン
private struct PracticeSet: Hashable {
    enum Kind: Hashable { case basic, confirm }
    let kind: Kind
    let index: Int
    let ids: [String]
    /// A, B, C …
    var letter: String { String(UnicodeScalar(UInt8(65 + index))) }
}

struct LessonDetailView: View {
    let lesson: Lesson
    @EnvironmentObject var store: StudyStore
    /// 基礎・確認のうち選ばれたパターン（A/B/C）
    @State private var activeSet: PracticeSet?
    @State private var showChallenge = false
    @State private var showDrill = false
    /// ドリルは毎回シャッフルして一定数だけ出題する。タップ時に確定してここへ入れる。
    @State private var drillQuestions: [QuizQuestion] = []

    /// 1回のドリルで出題する問題数
    private let drillSessionSize = 10

    private var isDone: Bool { store.isLessonCompleted(lesson.id) }
    private var basicIds: [String] { lesson.basicQuizIds ?? [] }
    private var challengeIds: [String] { lesson.challengeQuizIds ?? [] }
    private var drillIds: [String] { lesson.drillQuizIds ?? [] }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    HStack {
                        DomainChip(domain: lesson.domain)
                        Spacer()
                        if isDone {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                                Text("履修済み").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.green)
                            }
                        } else {
                            Text("約\(lesson.estimatedMinutes)分").captionStyle()
                        }
                    }
                    Text(lesson.title).titleStyle()

                    Card {
                        HStack(alignment: .top, spacing: Theme.Space.s) {
                            Image(systemName: "sparkles").foregroundStyle(Theme.orange)
                            GlossaryText(text: lesson.summary, size: 14, weight: .medium, color: Theme.ink)
                        }
                    }

                    ForEach(Array(lesson.sections.enumerated()), id: \.offset) { _, section in
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.heading).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                                GlossaryText(text: section.body, size: 15, color: Theme.ink, lineSpacing: 4)
                            }
                        }
                    }

                    // 基礎問題 → 確認問題 の順に解いてもらう。どちらも5問ずつのパターンA/B/Cから選ぶ
                    if !basicIds.isEmpty || !lesson.quizIds.isEmpty { stepsCard }

                    // 反復ドリル（5パターン）
                    if !drillIds.isEmpty { drillCard }

                    // 中級チャレンジ（腕試し）
                    if !challengeIds.isEmpty { challengeCard }

                    // 履修済みマークの手動トグル
                    completionButton
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("レッスン")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $activeSet) { set in
            let questions = set.ids.compactMap { ContentRepository.shared.question(id: $0) }
            switch set.kind {
            case .basic:
                QuizPlayerView(title: "基礎問題\(set.letter)・\(lesson.title)",
                               questions: questions, showLessonLink: false)
            case .confirm:
                // 確認問題のパターンをすべて解き終えたら履修済みにする
                QuizPlayerView(title: "確認問題\(set.letter)・\(lesson.title)",
                               questions: questions, showLessonLink: false,
                               onComplete: {
                                   let answered = store.answeredQuestionIds()
                                   if lesson.quizIds.allSatisfy(answered.contains) {
                                       store.markLessonCompleted(lesson.id)
                                   }
                               })
            }
        }
        .navigationDestination(isPresented: $showChallenge) {
            QuizPlayerView(title: "中級チャレンジ・\(lesson.title)",
                           questions: challengeIds.compactMap { ContentRepository.shared.question(id: $0) },
                           showLessonLink: false)
        }
        .navigationDestination(isPresented: $showDrill) {
            QuizPlayerView(title: "反復ドリル・\(lesson.title)",
                           questions: drillQuestions,
                           showLessonLink: false)
        }
    }

    // 基礎問題（STEP 1）→ 確認問題（STEP 2）の2段構え。どちらも5問ずつのパターンA/B/Cから選ぶ
    private var stepsCard: some View {
        let answered = store.answeredQuestionIds()
        let hasBoth = !basicIds.isEmpty && !lesson.quizIds.isEmpty
        return Card {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Text("問題に挑戦").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)

                if !basicIds.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        stepLabel(1, "基礎問題", "レッスンを読んだら、まずここから。用語と役割を確認します。")
                        patternRow(.basic, ids: basicIds, answered: answered)
                    }
                }

                if !lesson.quizIds.isEmpty {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        stepLabel(hasBoth ? 2 : 1, "確認問題", "本試験に近い形で、用語や手法の使い分けまで問います。全パターンを解くと履修済みになります。")
                        patternRow(.confirm, ids: lesson.quizIds, answered: answered)
                    }
                }
            }
        }
    }

    /// パターンA/B/Cのタイル（解き終えたパターンにはチェックが付く）
    private func patternRow(_ kind: PracticeSet.Kind, ids: [String], answered: Set<String>) -> some View {
        let tint = kind == .basic ? Theme.orange : Theme.blue
        let soft = kind == .basic ? Theme.orangeSoft : Theme.blueSoft
        return HStack(spacing: Theme.Space.s) {
            ForEach(Array(patterns(ids).enumerated()), id: \.offset) { index, chunk in
                let set = PracticeSet(kind: kind, index: index, ids: chunk)
                let done = chunk.allSatisfy(answered.contains)
                Button {
                    activeSet = set
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(set.letter).font(.system(size: 20, weight: .bold))
                            if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)) }
                        }
                        Text(done ? "解答済み" : "\(chunk.count)問").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(done ? .white : tint)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous)
                        .fill(done ? tint : soft))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(kind == .basic ? "基礎問題" : "確認問題")パターン\(set.letter)、\(chunk.count)問\(done ? "、解答済み" : "")")
            }
        }
    }

    private func stepLabel(_ number: Int, _ title: String, _ note: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(number == 1 ? Theme.orange : Theme.blue))
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP \(number)・\(title)").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(note).font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// ドリルプールをシャッフルして出題分だけ取り出す
    private func startDrill() {
        let pool = drillIds.compactMap { ContentRepository.shared.question(id: $0) }
        drillQuestions = Array(pool.shuffled().prefix(drillSessionSize))
        showDrill = true
    }

    // 反復ドリル（同じ知識を5パターンで問い、定着させる）
    private var drillCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Theme.teal)
                    Text("反復ドリル").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    Text("5パターン")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.teal)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.teal.opacity(0.12)).clipShape(Capsule())
                    Spacer()
                }
                Text("同じ内容を5つの角度（用途・説明・シナリオ・穴埋め・誤り探し）で出題。毎回ランダムに\(drillSessionSize)問出るので、繰り返すほど定着します。")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    startDrill()
                } label: {
                    HStack {
                        Image(systemName: "square.stack.3d.up.fill")
                        Text("ランダム\(min(drillSessionSize, drillIds.count))問に挑戦（全\(drillIds.count)問）").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.teal)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.teal.opacity(0.5), lineWidth: 1.2))
                }
            }
        }
    }

    // 中級チャレンジ（試験範囲内で、シナリオ型の難問に挑戦）
    private var challengeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.orange)
                    Text("中級チャレンジ").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    Text("やや難")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.orange)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.orangeSoft).clipShape(Capsule())
                    Spacer()
                }
                Text("基礎が身についたら腕試し。\(ExamInfo.examShortName)の範囲内で、状況判断が必要なシナリオ問題に挑戦します。")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    showChallenge = true
                } label: {
                    HStack {
                        Image(systemName: "bolt.fill")
                        Text("挑戦する（\(challengeIds.count)問）").font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13))
                    }
                    .foregroundStyle(Theme.orange)
                    .padding(.vertical, 12).padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.orange.opacity(0.5), lineWidth: 1.2))
                }
            }
        }
    }

    @ViewBuilder private var completionButton: some View {
        if isDone {
            Button {
                store.unmarkLessonCompleted(lesson.id)
            } label: {
                Label("履修済みを取り消す", systemImage: "arrow.uturn.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Theme.inkSoft.opacity(0.3), lineWidth: 1))
            }
        } else {
            Button {
                store.markLessonCompleted(lesson.id)
            } label: {
                Label("このレッスンを履修済みにする", systemImage: "checkmark.circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.green.opacity(0.10)))
            }
        }
    }
}
