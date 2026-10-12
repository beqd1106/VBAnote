import SwiftUI

/// カスタム演習：分野×難易度×お気に入り×間違えた問題で絞り込んで出題する。
struct CustomPracticeView: View {
    @EnvironmentObject var store: StudyStore
    private let repo = ContentRepository.shared

    @State private var domains: Set<ExamDomain> = []   // 空＝すべて
    @State private var difficulties: Set<Int> = []      // 空＝すべて（1/2/3）
    @State private var onlyBookmarked = false
    @State private var onlyMistaken = false

    @State private var started = false
    @State private var startQuestions: [QuizQuestion] = []

    private let maxCount = 30

    private var filtered: [QuizQuestion] {
        var list = repo.questions
        if !domains.isEmpty { list = list.filter { domains.contains($0.domain) } }
        if !difficulties.isEmpty { list = list.filter { difficulties.contains($0.difficulty) } }
        if onlyBookmarked {
            let ids = store.bookmarkedQuestionIds()
            list = list.filter { ids.contains($0.id) }
        }
        if onlyMistaken {
            let ids = store.mistakenQuestionIds()
            list = list.filter { ids.contains($0.id) }
        }
        return list
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    section("分野（複数選択可・未選択＝すべて）") {
                        FlexChips {
                            ForEach(ExamDomain.allCases) { d in
                                toggleChip(d.shortTitle, active: domains.contains(d)) { toggle(&domains, d) }
                            }
                        }
                    }
                    section("難易度") {
                        HStack(spacing: Theme.Space.s) {
                            toggleChip("やさしい", active: difficulties.contains(1)) { toggle(&difficulties, 1) }
                            toggleChip("ふつう", active: difficulties.contains(2)) { toggle(&difficulties, 2) }
                            toggleChip("やや難", active: difficulties.contains(3)) { toggle(&difficulties, 3) }
                        }
                    }
                    section("絞り込み") {
                        VStack(spacing: Theme.Space.s) {
                            switchRow("お気に入りのみ", "star.fill", Theme.blue, $onlyBookmarked,
                                      count: store.bookmarkedQuestionIds().count)
                            switchRow("間違えた問題のみ", "xmark.circle.fill", Theme.red, $onlyMistaken,
                                      count: store.mistakenQuestionIds().count)
                        }
                    }

                    // 件数と開始
                    let count = filtered.count
                    Card {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("該当 \(count) 問").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                                Text(count > maxCount ? "ランダムに\(maxCount)問を出題します" : "この条件で出題します").captionStyle()
                            }
                            Spacer()
                        }
                    }
                    PrimaryButton(title: "演習をはじめる", icon: "play.fill", enabled: count > 0) {
                        startQuestions = Array(filtered.shuffled().prefix(maxCount))
                        started = true
                    }
                    if count == 0 {
                        Text("条件に合う問題がありません。絞り込みを緩めてください。")
                            .captionStyle().frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("カスタム演習")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $started) {
            QuizPlayerView(title: "カスタム演習", questions: startQuestions)
        }
    }

    // MARK: - パーツ

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSoft)
            content()
        }
    }

    private func toggleChip(_ title: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(active ? .white : Theme.inkSoft)
                .background(active ? Theme.navy : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: active ? 0 : 1))
        }
    }

    private func switchRow(_ title: String, _ icon: String, _ color: Color, _ binding: Binding<Bool>, count: Int) -> some View {
        Card(padding: Theme.Space.m) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: icon).foregroundStyle(color).frame(width: 24)
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text("\(count)問").captionStyle()
                Spacer()
                Toggle("", isOn: binding).labelsHidden().tint(color)
            }
        }
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ v: T) {
        if set.contains(v) { set.remove(v) } else { set.insert(v) }
    }
}

/// 折り返し表示のチップコンテナ（簡易）
struct FlexChips<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        // 分野は4つなので横並びで十分
        HStack(spacing: Theme.Space.s) { content() }
    }
}
