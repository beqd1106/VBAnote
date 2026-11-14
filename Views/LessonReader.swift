import SwiftUI

// MARK: - 教材本文の表示（レッスン画面と、問題の途中で開くシートで共用）

enum LessonText {
    /// design/add_points.py が作る節の見出し。この節は「言葉：意味」の行が並ぶ。
    static let pointsHeading = "出題ポイント（問題で問われる言葉）"

    /// 正解の選択肢から「言葉」の部分を取り出す（add_points.py の key_of と同じ規則）
    static func answerKey(_ q: QuizQuestion) -> String? {
        guard let i = q.correctAnswers.first, q.choices.indices.contains(i) else { return nil }
        let stops: Set<Character> = ["（", "(", "：", ":", "、", "。"]
        let key = String(q.choices[i].prefix { !stops.contains($0) }).trimmingCharacters(in: .whitespaces)
        return key.count >= 2 ? key : nil
    }

    struct Point: Hashable {
        let key: String
        let desc: String
    }

    static func points(_ body: String) -> [Point] {
        body.split(separator: "\n").compactMap { raw in
            var line = String(raw)
            if line.hasPrefix("・") { line.removeFirst() }
            guard !line.isEmpty else { return nil }
            guard let r = line.range(of: "：") else { return Point(key: "", desc: line) }
            return Point(key: String(line[..<r.lowerBound]), desc: String(line[r.upperBound...]))
        }
    }
}

/// レッスンの各節。focusKey を渡すと、その言葉が載っている所（出題ポイントのカード、
/// 無ければ本文の節）をオレンジで強調し、id "lesson-hit" を付ける（スクロール先）。
struct LessonSectionsView: View {
    let lesson: Lesson
    var focusKey: String? = nil

    /// 強調する場所。出題ポイントにあればそれを優先し、無ければ言葉を含む最初の本文の節。
    private var hitPoint: String? {
        guard let key = focusKey else { return nil }
        for s in lesson.sections where s.heading == LessonText.pointsHeading {
            if LessonText.points(s.body).contains(where: { $0.key == key }) { return key }
        }
        return nil
    }
    private var hitSection: Int? {
        guard let key = focusKey, hitPoint == nil else { return nil }
        return lesson.sections.firstIndex { $0.heading != LessonText.pointsHeading && $0.body.contains(key) }
    }

    var body: some View {
        ForEach(Array(lesson.sections.enumerated()), id: \.offset) { i, section in
            if section.heading == LessonText.pointsHeading {
                pointsBlock(section.body)
            } else {
                let hit = i == hitSection
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.heading).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        if hit, let key = focusKey {
                            Label("「\(key)」はこの節に出てきます", systemImage: "arrow.down.circle.fill")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.orange)
                        }
                        GlossaryText(text: section.body, size: 15, color: Theme.ink, lineSpacing: 4)
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(hit ? Theme.orange : .clear, lineWidth: 2))
                .id(hit ? "lesson-hit" : "section-\(i)")
            }
        }
    }

    private func pointsBlock(_ body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("出題ポイント").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
            Text("問題で問われる言葉と、その意味です。").captionStyle()
            ForEach(LessonText.points(body), id: \.self) { p in
                let hit = !p.key.isEmpty && p.key == hitPoint
                VStack(alignment: .leading, spacing: 2) {
                    if !p.key.isEmpty {
                        Text(p.key).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.navy)
                    }
                    GlossaryText(text: p.desc, size: 14, color: Theme.ink, lineSpacing: 3)
                }
                .padding(.horizontal, Theme.Space.m)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(hit ? Theme.orangeSoft : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(hit ? Theme.orange : Theme.line, lineWidth: hit ? 2 : 1))
                .id(hit ? "lesson-hit" : "point-\(p.key)")
            }
        }
    }
}

// MARK: - 問題の途中で開く教材シート

/// シートで開くので問題画面はそのまま残り、閉じれば解きかけの状態に戻る。
struct LessonReaderItem: Identifiable {
    let lesson: Lesson
    /// 答え合わせ後だけ渡す（答える前に開いたときは答えが分からないよう強調しない）
    let focusKey: String?
    var id: String { lesson.id + "|" + (focusKey ?? "") }
}

struct LessonReaderSheet: View {
    let item: LessonReaderItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Space.l) {
                            DomainChip(domain: item.lesson.domain)
                            Text(item.lesson.title).titleStyle()
                            Card {
                                HStack(alignment: .top, spacing: Theme.Space.s) {
                                    Image(systemName: "sparkles").foregroundStyle(Theme.orange)
                                    GlossaryText(text: item.lesson.summary, size: 14, weight: .medium, color: Theme.ink)
                                }
                            }
                            LessonSectionsView(lesson: item.lesson, focusKey: item.focusKey)
                        }
                        .padding(Theme.Space.l)
                        .padding(.bottom, 96)
                    }
                    .onAppear {
                        guard item.focusKey != nil else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("lesson-hit", anchor: .center) }
                        }
                    }
                }
                VStack {
                    Spacer()
                    PrimaryButton(title: "問題に戻る") { dismiss() }
                        .padding(.horizontal, Theme.Space.l)
                        .padding(.bottom, Theme.Space.s)
                        .accessibilityIdentifier("lessonSheetBack")
                }
            }
            .navigationTitle("教材")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDragIndicator(.visible)
    }
}
