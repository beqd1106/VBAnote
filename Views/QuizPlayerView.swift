import SwiftUI

/// 演習・復習・今日のタスクで使う問題プレイヤー（1問ずつ・即時解説）。
/// 「前へ」で1つ前の問題に戻り、回答・正誤・解説を保持したまま見返せる。
struct QuizPlayerView: View {
    let title: String
    /// 出題セットは初回に @State へ固定する。
    /// （呼び出し側が shuffled() で渡すと、親の再描画で配列が作り直され
    ///   index はそのままで別の問題に化けるため。@State で初期値のみ採用して固定）
    @State private var questions: [QuizQuestion]

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    /// 全問終了時に一度だけ呼ばれる（レッスンの履修済みマークなどに使用）。
    private let onComplete: (() -> Void)?
    /// 解説に「この分野の解説レッスンへ」導線を出すか（レッスンから起動した場合は循環を避けて false）。
    private let showLessonLink: Bool

    init(title: String, questions: [QuizQuestion], showLessonLink: Bool = true, onComplete: (() -> Void)? = nil) {
        self.title = title
        _questions = State(initialValue: questions)
        self.onComplete = onComplete
        self.showLessonLink = showLessonLink
    }

    @State private var index = 0
    /// 問題インデックスごとの選択状態（戻っても保持）
    @State private var selectedByIndex: [Int: Set<Int>] = [:]
    /// 答え合わせ済みの問題インデックス
    @State private var submittedIndices: Set<Int> = []
    /// 問題インデックスごとの正誤（採点は1回だけ記録）
    @State private var resultByIndex: [Int: Bool] = [:]
    @State private var finished = false

    /// 問題インデックスごとのヒント段階（0=未使用 1=着眼点 2=選択肢しぼり込み）
    @State private var hintLevelByIndex: [Int: Int] = [:]
    /// 表示中のヒント文（毎回組み立て直さないよう保持）
    @State private var hintTextByIndex: [Int: String] = [:]
    /// しぼり込みで薄くする選択肢
    @State private var eliminatedByIndex: [Int: Set<Int>] = [:]
    /// ヒントを使って答えた問題（正解でも復習リストに残す）
    @State private var hintUsedIndices: Set<Int> = []

    private var current: QuizQuestion { questions[index] }
    private var selected: Set<Int> { selectedByIndex[index] ?? [] }
    private var isSubmitted: Bool { submittedIndices.contains(index) }
    private var hintLevel: Int { hintLevelByIndex[index] ?? 0 }
    private var eliminated: Set<Int> { eliminatedByIndex[index] ?? [] }
    private var usedHint: Bool { hintUsedIndices.contains(index) }
    private var correctCount: Int { resultByIndex.values.filter { $0 }.count }

    var body: some View {
        ZStack {
            AppBackground()
            if finished {
                summaryView
            } else if questions.isEmpty {
                EmptyStateView(icon: "tray", title: "問題がありません",
                               message: "別の分野を選んでみてください。")
            } else {
                quizView
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - 出題

    private var quizView: some View {
        VStack(spacing: 0) {
            // 進捗
            VStack(spacing: 6) {
                HStack {
                    Text("\(index + 1) / \(questions.count)問")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                    Spacer()
                    DomainChip(domain: current.domain)
                }
                ProgressBar(value: Double(index) / Double(questions.count))
            }
            .padding(Theme.Space.l)

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    // 問題文
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            if current.isMultipleSelect {
                                TagChip(text: "複数選択（\(current.correctAnswers.count)つ選ぶ）", color: Theme.teal)
                            }
                            GlossaryText(text: current.question,
                                         size: 17, weight: .semibold, color: Theme.ink)
                        }
                    }

                    // 選択肢
                    VStack(spacing: Theme.Space.s) {
                        ForEach(Array(current.choices.enumerated()), id: \.offset) { i, choice in
                            choiceRow(i, choice)
                        }
                    }

                    // ヒント（回答前だけ。押した人にだけ開く）
                    // まず自力で選択肢を読んでもらうため、選択肢の下に置く。
                    if !isSubmitted { hintSection }

                    if isSubmitted { explanationCard }
                }
                .padding(.horizontal, Theme.Space.l)
                .padding(.bottom, 120)
            }

            // 下部アクション（前へ / 答え合わせ・次へ）
            HStack(spacing: Theme.Space.m) {
                if index > 0 {
                    SecondaryButton(title: "前へ", icon: "chevron.left") { goPrevious() }
                        .frame(maxWidth: 130)
                }
                if !isSubmitted {
                    PrimaryButton(title: "答え合わせ", enabled: !selected.isEmpty) { submit() }
                } else {
                    PrimaryButton(title: index + 1 < questions.count ? "次の問題へ" : "結果を見る",
                                  icon: "arrow.right") { goNext() }
                }
            }
            .padding(Theme.Space.l)
            .background(.ultraThinMaterial)
        }
    }

    private func choiceRow(_ i: Int, _ choice: String) -> some View {
        let isSelected = selected.contains(i)
        let isCorrect = current.correctAnswers.contains(i)
        // ヒントで消した選択肢（答え合わせ後は通常表示に戻す）
        let isEliminated = !isSubmitted && eliminated.contains(i)
        var bg = Theme.card
        var border = Theme.line
        var icon = "circle"
        var iconColor = Theme.line
        if isEliminated {
            icon = "minus.circle"
            iconColor = Theme.inkSoft.opacity(0.6)
        } else if isSubmitted {
            if isCorrect { bg = Theme.green.opacity(0.10); border = Theme.green; icon = "checkmark.circle.fill"; iconColor = Theme.green }
            else if isSelected { bg = Theme.red.opacity(0.10); border = Theme.red; icon = "xmark.circle.fill"; iconColor = Theme.red }
        } else if isSelected {
            bg = Theme.blueSoft; border = Theme.blue; icon = "largecircle.fill.circle"; iconColor = Theme.blue
        }
        return Button {
            guard !isSubmitted, !isEliminated else { return }
            toggle(i)
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.m) {
                Image(systemName: icon).foregroundStyle(iconColor).font(.system(size: 20))
                Text(choice).font(.system(size: 15)).foregroundStyle(Theme.ink)
                    .strikethrough(isEliminated, color: Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip).stroke(border, lineWidth: 1.2))
            .opacity(isEliminated ? 0.45 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isEliminated)
    }

    // MARK: - ヒント

    /// 未使用なら誘導ボタン、使用後はヒントカード
    @ViewBuilder
    private var hintSection: some View {
        if hintLevel == 0 {
            Button { revealHint() } label: {
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: "lightbulb").font(.system(size: 15, weight: .semibold))
                    Text("わからない時はヒント").font(.system(size: 14, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Theme.orange)
                .padding(.horizontal, Theme.Space.m)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Theme.orangeSoft.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip)
                    .stroke(Theme.orange.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
        } else {
            hintCard
        }
    }

    private var hintCard: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").foregroundStyle(Theme.orange).font(.system(size: 14))
                Text("ヒント").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange)
                Spacer(minLength: 0)
            }
            GlossaryText(text: hintTextByIndex[index] ?? "", size: 14, color: Theme.ink)
            Text("ヒントを使った問題は、正解でも復習リストに残します。")
                .font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            if hintLevel == 1 {
                if HintBuilder.canEliminate(current) {
                    Button { revealHint() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.stars").font(.system(size: 13, weight: .semibold))
                            Text("まだ迷う：選択肢をしぼる").font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(Theme.orange)
                        .padding(.horizontal, Theme.Space.m)
                        .frame(minHeight: 40)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(Theme.orange.opacity(0.45), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text("明らかに違う選択肢を薄くしました。残りから選んでください。")
                    .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.orangeSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip)
            .stroke(Theme.orange.opacity(0.3), lineWidth: 1))
    }

    /// ヒントを1段階進める
    private func revealHint() {
        guard !isSubmitted else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            switch hintLevel {
            case 0:
                hintTextByIndex[index] = HintBuilder.focusHint(
                    for: current, glossary: ContentRepository.shared.glossary)
                hintLevelByIndex[index] = 1
            default:
                let drop = HintBuilder.eliminatedChoices(for: current)
                eliminatedByIndex[index] = drop
                // 消した選択肢を選んでいたら外す
                if var sel = selectedByIndex[index] {
                    sel.subtract(drop)
                    selectedByIndex[index] = sel
                }
                hintLevelByIndex[index] = 2
            }
            hintUsedIndices.insert(index)
        }
    }

    // MARK: - 解説

    private var explanationCard: some View {
        let isCorrect = current.isCorrect(selected: selected)
        return Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: isCorrect ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundStyle(isCorrect ? Theme.green : Theme.red)
                    Text(isCorrect ? "正解！" : "残念、不正解")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(isCorrect ? Theme.green : Theme.red)
                    if usedHint {
                        TagChip(text: "ヒント使用", color: Theme.orange)
                    }
                    Spacer()
                    bookmarkButton
                }

                // ヒントつきの正解は「自力」ではないので、復習リストに残すことを伝える
                if usedHint && isCorrect {
                    Text("ヒントを使ったので、この問題は復習リストに残します。")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                }

                Divider()

                labeledBlock("解説", current.explanation, color: Theme.navy)

                // 不正解選択肢の理由
                if !current.wrongChoiceExplanations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("他の選択肢").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSoft)
                        ForEach(current.choices.indices, id: \.self) { i in
                            if let reason = current.wrongReason(for: i) {
                                HStack(alignment: .top, spacing: 6) {
                                    Text("×").foregroundStyle(Theme.red).font(.system(size: 14, weight: .bold))
                                    GlossaryText(text: reason, size: 13, color: Theme.ink)
                                }
                            }
                        }
                    }
                }

                if let note = current.beginnerNote {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(Theme.orange).font(.system(size: 13))
                        GlossaryText(text: note, size: 13, color: Theme.ink)
                    }
                    .padding(Theme.Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.orangeSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // この問題に関連する解説レッスンへ
                if showLessonLink, let lesson = ContentRepository.shared.lesson(forQuestion: current) {
                    NavigationLink { LessonDetailView(lesson: lesson) } label: {
                        HStack(spacing: Theme.Space.s) {
                            Image(systemName: "text.book.closed.fill").foregroundStyle(Theme.blue)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("解説レッスンで学び直す").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                                Text(lesson.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.blue)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.blue).font(.system(size: 12))
                        }
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.blueSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func labeledBlock(_ label: String, _ text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            GlossaryText(text: text, size: 14, color: Theme.ink)
        }
    }

    private var bookmarkButton: some View {
        Button {
            store.toggleBookmark(current.id)
        } label: {
            Image(systemName: store.isBookmarked(current.id) ? "star.fill" : "star")
                .foregroundStyle(store.isBookmarked(current.id) ? Theme.orange : Theme.inkSoft)
        }
    }

    // MARK: - サマリ

    private var summaryView: some View {
        let rate = questions.isEmpty ? 0 : Double(correctCount) / Double(questions.count)
        return ScrollView {
            VStack(spacing: Theme.Space.xl) {
                ScoreRing(value: rate, color: rate >= 0.7 ? Theme.green : Theme.orange,
                          label: "\(Int(rate*100))%",
                          caption: "\(correctCount)/\(questions.count)問正解")
                    .frame(width: 180, height: 180)
                    .padding(.top, Theme.Space.xxl)

                Text(rate >= 0.7 ? "よくできました！この調子です。" : "間違えた問題は復習キューに入りました。")
                    .font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.navy)
                    .multilineTextAlignment(.center)

                if store.dueReviewCount > 0 {
                    Text("復習待ち：\(store.dueReviewCount)問").captionStyle()
                }

                PrimaryButton(title: "終わる", icon: "checkmark") { dismiss() }
                    .padding(.horizontal, Theme.Space.xl)
            }
            .padding(Theme.Space.l)
        }
    }

    // MARK: - 操作

    private func toggle(_ i: Int) {
        var set = selectedByIndex[index] ?? []
        if current.isMultipleSelect {
            if set.contains(i) { set.remove(i) } else { set.insert(i) }
        } else {
            set = [i]
        }
        selectedByIndex[index] = set
    }

    private func submit() {
        guard !isSubmitted else { return }
        submittedIndices.insert(index)
        let correct = current.isCorrect(selected: selected)
        resultByIndex[index] = correct
        // 採点・履歴記録は各問1回だけ
        store.recordAnswer(question: current, correct: correct, usedHint: usedHint)
    }

    private func goPrevious() {
        if index > 0 { index -= 1 }
    }

    private func goNext() {
        if index + 1 < questions.count {
            index += 1
        } else {
            finished = true
            onComplete?()
        }
    }
}
