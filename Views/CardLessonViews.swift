import SwiftUI
import UIKit

// MARK: - 教材の読み方（3モード）
//
// サクッと＝カードを1枚ずつめくる／ふつう＝区切りのカードをまとめて読む／じっくり＝今までの長文。
// どのモードでも「教材」ボタンで長文を開ける。答える前に教材を見た問題は、正解しても
// 「教材を見て正解」として復習に残す（自力の正解と区別する）。Web版と同じ仕様。

enum LessonMode: String, CaseIterable, Identifiable {
    case card, scroll, long
    var id: String { rawValue }
    static let storageKey = "lessonMode"

    var title: String {
        switch self {
        case .card: return "サクッと"
        case .scroll: return "ふつう"
        case .long: return "じっくり"
        }
    }
    var sub: String {
        switch self {
        case .card: return "1枚ずつ"
        case .scroll: return "まとめて読む"
        case .long: return "長文"
        }
    }
    var icon: String {
        switch self {
        case .card: return "rectangle.stack"
        case .scroll: return "list.bullet.rectangle"
        case .long: return "doc.text"
        }
    }
}

/// 区切りをどこまで終えたか（資格ごと・レッスンごとに「終えた区切りの数」）
enum CardProgress {
    private static var key: String { "cardsDone." + ExamContext.current.key }

    static func doneUnits(_ lessonId: String) -> Int {
        (UserDefaults.standard.dictionary(forKey: key)?[lessonId] as? Int) ?? 0
    }

    static func markDone(_ lessonId: String, unit: Int) {
        var d = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        if ((d[lessonId] as? Int) ?? 0) < unit + 1 { d[lessonId] = unit + 1 }
        UserDefaults.standard.set(d, forKey: key)
    }
}

// MARK: - モード切り替え（押せると一目で分かる3つの面）

struct LessonModeSwitch: View {
    @Binding var mode: LessonMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LessonMode.allCases) { m in
                let on = m == mode
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { mode = m }
                } label: {
                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: m.icon).font(.system(size: 12, weight: .semibold))
                            Text(m.title).font(.system(size: 14, weight: .bold))
                        }
                        Text(m.sub).font(.system(size: 10, weight: .medium)).opacity(0.85)
                    }
                    .foregroundStyle(on ? Color.white : Theme.navy)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(on ? Theme.navy : Color.clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(m.title)、\(m.sub)")
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("lessonMode-\(m.rawValue)")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: - レッスン画面に出す「区切り」の一覧

struct CardUnitsSection: View {
    let lesson: Lesson
    let cards: LessonCards
    let mode: LessonMode
    /// 区切りから戻ったときに「終えた数」を読み直すための合図
    @State private var tick = 0

    var body: some View {
        let done = min(CardProgress.doneUnits(lesson.id), cards.units.count) + tick * 0
        let total = cards.units.count
        let resume = done > 0 && done < total ? done : 0
        let minutes = cards.units.reduce(0) { $0 + $1.minutes }

        VStack(alignment: .leading, spacing: Theme.Space.m) {
            NavigationLink {
                CardUnitView(lesson: lesson, cards: cards, unitIndex: resume, mode: mode)
            } label: {
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: mode == .card ? "rectangle.stack.fill" : "list.bullet.rectangle.fill")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resume > 0 ? "続きから：区切り\(resume + 1)" : (done >= total ? "もう一度カードで読む" : "カードで始める"))
                            .font(.system(size: 16, weight: .bold))
                        Text(resume > 0 ? cards.units[resume].title : "\(total)区切り・全部で約\(minutes)分")
                            .font(.system(size: 12, weight: .medium)).opacity(0.9)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Space.l).padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.orange))
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("cardStart")

            Card(padding: Theme.Space.m) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("区切り").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.navy)
                        Spacer()
                        Text("\(done)/\(total) 終了").font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(done >= total ? Theme.green : Theme.inkSoft)
                    }
                    .padding(.bottom, Theme.Space.s)
                    ForEach(Array(cards.units.enumerated()), id: \.offset) { i, unit in
                        NavigationLink {
                            CardUnitView(lesson: lesson, cards: cards, unitIndex: i, mode: mode)
                        } label: {
                            unitRow(i, unit, isDone: i < done)
                        }
                        .buttonStyle(.plain)
                        if i < total - 1 { Divider() }
                    }
                }
            }
        }
        .onAppear { tick += 1 }
    }

    private func unitRow(_ i: Int, _ unit: CardUnit, isDone: Bool) -> some View {
        HStack(spacing: Theme.Space.m) {
            ZStack {
                Circle().fill(isDone ? Theme.green : Theme.orangeSoft).frame(width: 30, height: 30)
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(i + 1)").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(unit.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                if let goal = unit.goal, !goal.isEmpty {
                    Text(goal).font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Text("約\(unit.minutes)分").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkSoft)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.inkSoft)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 1区切りを読む画面（サクッと＝1枚ずつ／ふつう＝まとめて）

private struct CardAnswer {
    let selected: Set<Int>
    let correct: Bool
    /// 答える前に教材を見たか
    let peeked: Bool
}

struct CardUnitView: View {
    let lesson: Lesson
    let cards: LessonCards
    let mode: LessonMode

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var unitIndex: Int
    @State private var i = 0
    @State private var answers: [String: CardAnswer] = [:]
    @State private var pending: [String: Set<Int>] = [:]
    @State private var peeked: Set<String> = []
    @State private var finished = false
    @State private var reader: LessonReaderItem?
    @State private var toast: String?

    init(lesson: Lesson, cards: LessonCards, unitIndex: Int, mode: LessonMode) {
        self.lesson = lesson
        self.cards = cards
        self.mode = mode
        _unitIndex = State(initialValue: min(max(unitIndex, 0), max(cards.units.count - 1, 0)))
    }

    private var unit: CardUnit { cards.units[unitIndex] }
    private var repo: ContentRepository { ContentRepository.shared }
    private func question(_ item: CardItem) -> QuizQuestion? {
        guard item.t == "quiz", let id = item.q else { return nil }
        return repo.question(id: id)
    }
    /// この区切りで実際に出す問題
    private var unitQuestions: [QuizQuestion] { unit.cards.compactMap { question($0) } }

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()
            if finished {
                doneView
            } else if mode == .scroll {
                scrollBody
            } else {
                cardBody
            }
            if let toast {
                Text(toast)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.navy.opacity(0.92)))
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationTitle(mode == .scroll ? "まとめて読む" : "カード")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reader) { LessonReaderSheet(item: $0) }
    }

    // MARK: 見出し（区切り名・教材ボタン）

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Space.s) {
            Text("区切り \(unitIndex + 1)/\(cards.units.count)・\(unit.title)")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(action: openBook) {
                Label("教材", systemImage: "book")
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.navy)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Theme.card))
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    .shadow(color: Theme.cardShadow(), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("教材（長文）を開く")
            .accessibilityIdentifier("cardBook")
        }
    }

    /// カード1枚ごとの進み具合（問題のカードは淡いオレンジ）
    private var segments: some View {
        HStack(spacing: 4) {
            ForEach(Array(unit.cards.enumerated()), id: \.offset) { idx, item in
                Capsule()
                    .fill(idx < i ? Theme.navy : idx == i ? Theme.orange : (item.t == "quiz" ? Theme.orangeSoft : Theme.line))
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: サクッと（1枚ずつ）

    private var cardBody: some View {
        let item = unit.cards[i]
        let q = question(item)
        let canNext = q == nil || answers[q!.id] != nil
        return VStack(spacing: Theme.Space.l) {
            VStack(spacing: Theme.Space.m) {
                header
                segments
            }
            ScrollView {
                Group {
                    if let q {
                        quizBlock(q)
                    } else {
                        pointCard(item)
                    }
                }
                .id("\(unitIndex)-\(i)")
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
                .padding(.bottom, Theme.Space.s)
            }
            .scrollIndicators(.hidden)
            .gesture(DragGesture(minimumDistance: 30).onEnded { v in
                guard abs(v.translation.width) > abs(v.translation.height) else { return }
                if v.translation.width < -40, canNext { next() }
                if v.translation.width > 40 { prev() }
            })
            HStack(spacing: Theme.Space.s) {
                Button(action: prev) {
                    Image(systemName: "chevron.left").font(.system(size: 16, weight: .bold))
                        .foregroundStyle(i == 0 ? Theme.inkSoft.opacity(0.4) : Theme.navy)
                        .frame(width: 56, height: 52)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).fill(Theme.card))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(i == 0)
                .accessibilityLabel("前のカード")
                PrimaryButton(title: i == unit.cards.count - 1 ? "この区切りを終える" : (canNext ? "次へ" : "答えると進めます"),
                              enabled: canNext) { next() }
                    .accessibilityIdentifier("cardNext")
            }
        }
        .padding(.horizontal, Theme.Space.l)
        .padding(.vertical, Theme.Space.m)
    }

    // MARK: ふつう（区切りをまとめて読む）

    private var scrollBody: some View {
        let qs = unitQuestions
        let allAnswered = qs.allSatisfy { answers[$0.id] != nil }
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                header
                if let goal = unit.goal, !goal.isEmpty {
                    Label(goal, systemImage: "scope")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.navy)
                }
                ForEach(Array(unit.cards.enumerated()), id: \.offset) { _, item in
                    if let q = question(item) {
                        quizBlock(q)
                    } else if item.t == "point" {
                        pointCard(item)
                    }
                }
                PrimaryButton(title: "この区切りを終える", enabled: allAnswered) { finish() }
                    .accessibilityIdentifier("unitFinish")
                if !allAnswered {
                    Text("はさまっている問題に全部答えると終えられます。").captionStyle()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(Theme.Space.l)
            .padding(.bottom, Theme.Space.xl)
        }
    }

    // MARK: カードの中身

    private func pointCard(_ item: CardItem) -> some View {
        Card(padding: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                TagChip(text: unit.title, color: Theme.orange)
                if let head = item.head, !head.isEmpty {
                    Text(head).font(.system(size: 21, weight: .bold)).foregroundStyle(Theme.navy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                GlossaryText(text: item.body ?? "", size: 17, color: Theme.ink, lineSpacing: 7)
                if let ex = item.ex, !ex.isEmpty {
                    HStack(alignment: .top, spacing: Theme.Space.s) {
                        Text("例").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Theme.orange))
                        GlossaryText(text: ex, size: 14, color: Theme.ink, lineSpacing: 4)
                    }
                    .padding(Theme.Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.orangeSoft.opacity(0.6)))
                }
            }
        }
    }

    private func quizBlock(_ q: QuizQuestion) -> some View {
        let a = answers[q.id]
        let sel = a?.selected ?? pending[q.id] ?? []
        return Card(padding: Theme.Space.l) {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(spacing: 6) {
                    TagChip(text: "確認", color: Theme.blue)
                    if q.isMultipleSelect { TagChip(text: "\(q.correctAnswers.count)つ選ぶ", color: Theme.orange) }
                    if peeked.contains(q.id) && a == nil { TagChip(text: "教材を見た", color: Theme.blue) }
                }
                GlossaryText(text: q.question, size: 17, weight: .semibold, color: Theme.navy, lineSpacing: 4)
                VStack(spacing: Theme.Space.s) {
                    ForEach(q.choices.indices, id: \.self) { j in
                        choiceButton(q, j, selected: sel.contains(j), answer: a)
                    }
                }
                if q.isMultipleSelect && a == nil {
                    PrimaryButton(title: "答える", enabled: sel.count == q.correctAnswers.count) { submit(q) }
                }
                if let a { feedback(q, a) }
            }
        }
    }

    private func choiceButton(_ q: QuizQuestion, _ j: Int, selected: Bool, answer: CardAnswer?) -> some View {
        let isRight = q.correctAnswers.contains(j)
        var stroke = Theme.line
        var fill = Theme.card
        var mark: String? = nil
        if answer != nil {
            if isRight { stroke = Theme.green; fill = Theme.green.opacity(0.10); mark = "checkmark.circle.fill" }
            else if selected { stroke = Theme.red; fill = Theme.red.opacity(0.08); mark = "xmark.circle.fill" }
        } else if selected {
            stroke = Theme.blue; fill = Theme.blueSoft
        }
        return Button {
            tap(q, j)
        } label: {
            HStack(alignment: .top, spacing: Theme.Space.s) {
                Text("\(j + 1)").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(selected && answer == nil ? Color.white : Theme.navy)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(selected && answer == nil ? Theme.blue : Theme.bg))
                Text(q.choices[j]).font(.system(size: 15)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if let mark {
                    Image(systemName: mark).foregroundStyle(isRight ? Theme.green : Theme.red)
                }
            }
            .padding(.horizontal, Theme.Space.m).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(stroke, lineWidth: selected || (answer != nil && isRight) ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(answer != nil)
        .accessibilityLabel("選択肢\(j + 1)、\(q.choices[j])")
    }

    private func feedback(_ q: QuizQuestion, _ a: CardAnswer) -> some View {
        let color = a.correct ? (a.peeked ? Theme.blue : Theme.green) : Theme.red
        let title = a.correct ? (a.peeked ? "教材を見て正解" : "正解") : "おしい"
        let icon = a.correct ? (a.peeked ? "book.fill" : "checkmark.circle.fill") : "xmark.circle.fill"
        let wrongPick = a.selected.subtracting(q.correctAnswers).sorted().first
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            Label(title, systemImage: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(color)
            if let w = wrongPick, let reason = q.wrongReason(for: w) {
                GlossaryText(text: "\(w + 1)がちがう理由：\(reason)", size: 14, color: Theme.ink, lineSpacing: 3)
            }
            GlossaryText(text: Self.firstSentence(q.explanation), size: 14, color: Theme.ink, lineSpacing: 3)
            if a.correct && a.peeked {
                Text("教材を見て答えたので、この問題は復習に残します。").captionStyle()
            }
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(color.opacity(0.35), lineWidth: 1))
    }

    static func firstSentence(_ t: String) -> String {
        let s: String
        if let r = t.range(of: "。") { s = String(t[..<r.upperBound]) } else { s = t }
        return s.count > 120 ? String(s.prefix(118)) + "…" : s
    }

    // MARK: 区切りの終わり

    private var doneView: some View {
        let qs = unitQuestions
        let ok = qs.filter { answers[$0.id]?.correct == true && answers[$0.id]?.peeked == false }.count
        let okPeek = qs.filter { answers[$0.id]?.correct == true && answers[$0.id]?.peeked == true }.count
        let ng = qs.count - ok - okPeek
        let last = unitIndex + 1 >= cards.units.count
        let nextUnit: CardUnit? = last ? nil : cards.units[unitIndex + 1]
        return ScrollView {
            VStack(spacing: Theme.Space.l) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Theme.green)
                    .padding(.top, Theme.Space.xl)
                Text(last ? "このレッスンのカードを全部めくりました" : "区切りクリア").titleStyle()
                    .multilineTextAlignment(.center)
                Text("区切り \(unitIndex + 1)/\(cards.units.count)「\(unit.title)」").captionStyle()
                if !qs.isEmpty {
                    HStack(spacing: Theme.Space.s) {
                        scoreBox(ok, "自力で正解", Theme.green)
                        if okPeek > 0 { scoreBox(okPeek, "教材を見て正解", Theme.blue) }
                        scoreBox(ng, "まちがい", Theme.red)
                    }
                    if okPeek + ng > 0 {
                        Text("教材を見た問題とまちがえた問題は、復習に残しました。").captionStyle()
                            .multilineTextAlignment(.center)
                    }
                }
                HStack(spacing: 4) {
                    ForEach(cards.units.indices, id: \.self) { k in
                        Capsule().fill(k <= unitIndex ? Theme.green : Theme.line).frame(height: 6)
                    }
                }
                .padding(.vertical, Theme.Space.s)
                VStack(spacing: Theme.Space.s) {
                    if let nextUnit {
                        PrimaryButton(title: "次の区切りへ：\(nextUnit.title)（約\(nextUnit.minutes)分）") { goUnit(unitIndex + 1) }
                            .accessibilityIdentifier("nextUnit")
                        SecondaryButton(title: "今日はここまで") { dismiss() }
                    } else {
                        PrimaryButton(title: "レッスンに戻って確認問題へ") { dismiss() }
                    }
                }
            }
            .padding(Theme.Space.l)
        }
    }

    private func scoreBox(_ n: Int, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(n)").font(.system(size: 26, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(color.opacity(0.08)))
    }

    // MARK: 操作

    private func tap(_ q: QuizQuestion, _ j: Int) {
        guard answers[q.id] == nil else { return }
        if q.isMultipleSelect {
            var s = pending[q.id] ?? []
            if s.contains(j) { s.remove(j) } else { s.insert(j) }
            pending[q.id] = s
            UISelectionFeedbackGenerator().selectionChanged()
        } else {
            pending[q.id] = [j]
            submit(q)
        }
    }

    private func submit(_ q: QuizQuestion) {
        let sel = pending[q.id] ?? []
        guard !sel.isEmpty, answers[q.id] == nil else { return }
        let correct = q.isCorrect(selected: sel)
        let peek = peeked.contains(q.id)
        withAnimation(.easeOut(duration: 0.2)) {
            answers[q.id] = CardAnswer(selected: sel, correct: correct, peeked: peek)
        }
        // 教材を見てからの正解は「ヒントつき」と同じ扱い（自力の正解にしない・復習に残す）
        store.recordAnswer(question: q, correct: correct, usedHint: peek)
        UINotificationFeedbackGenerator().notificationOccurred(correct ? .success : .error)
    }

    private func next() {
        if i < unit.cards.count - 1 {
            withAnimation(.easeOut(duration: 0.25)) { i += 1 }
        } else {
            finish()
        }
    }

    private func prev() {
        guard i > 0 else { return }
        withAnimation(.easeOut(duration: 0.25)) { i -= 1 }
    }

    private func finish() {
        CardProgress.markDone(lesson.id, unit: unitIndex)
        withAnimation(.easeOut(duration: 0.25)) { finished = true }
    }

    private func goUnit(_ k: Int) {
        guard cards.units.indices.contains(k) else { return }
        unitIndex = k
        i = 0
        answers = [:]
        pending = [:]
        peeked = []
        withAnimation(.easeOut(duration: 0.25)) { finished = false }
    }

    /// 教材（長文）を開く。まだ答えていない問題は「教材を見た」にする。
    private func openBook() {
        var fresh: [String] = []
        let near: String
        if mode == .scroll {
            fresh = unitQuestions.map(\.id).filter { answers[$0] == nil && !peeked.contains($0) }
            near = unit.title + " " + unit.points.map { ($0.head ?? "") + ($0.body ?? "") }.joined(separator: " ")
        } else {
            let item = unit.cards[i]
            if let q = question(item) {
                if answers[q.id] == nil && !peeked.contains(q.id) { fresh = [q.id] }
                near = q.question
            } else {
                near = (item.head ?? "") + (item.body ?? "")
            }
        }
        if !fresh.isEmpty {
            peeked.formUnion(fresh)
            showToast("教材を見て答えた問題は、復習に残します")
        }
        reader = LessonReaderItem(lesson: lesson, focusKey: nil, backTitle: "カードに戻る", nearText: near)
    }

    private func showToast(_ text: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeIn(duration: 0.2)) { if toast == text { toast = nil } }
        }
    }
}
