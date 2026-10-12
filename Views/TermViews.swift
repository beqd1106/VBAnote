import SwiftUI

/// 用語カード一覧（分野フィルタ＋検索）
struct TermListView: View {
    var domain: ExamDomain? = nil
    @State private var keyword = ""
    @State private var selectedDomain: ExamDomain?

    init(domain: ExamDomain? = nil) {
        self.domain = domain
        _selectedDomain = State(initialValue: domain)
    }

    private var results: [TermCard] {
        var list = ContentRepository.shared.searchTerms(keyword)
        if let d = selectedDomain { list = list.filter { $0.domain == d } }
        return list
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    // 検索
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                        TextField("用語を検索（例：S3、IAM）", text: $keyword)
                    }
                    .padding(Theme.Space.m)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))

                    // 分野フィルタ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Space.s) {
                            filterChip("すべて", active: selectedDomain == nil) { selectedDomain = nil }
                            ForEach(ExamDomain.allCases) { d in
                                filterChip(d.shortTitle, active: selectedDomain == d) { selectedDomain = d }
                            }
                        }
                    }

                    // 暗記モード（フリップ）への入口
                    if !results.isEmpty {
                        NavigationLink { FlashcardView(cards: results) } label: {
                            HStack(spacing: Theme.Space.s) {
                                Image(systemName: "rectangle.on.rectangle.angled").foregroundStyle(.white)
                                    .frame(width: 36, height: 36).background(Theme.orange)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("暗記モードで学ぶ").font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.navy)
                                    Text("\(results.count)枚をタップでめくって暗記").captionStyle()
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
                            }
                            .padding(Theme.Space.m)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).stroke(Theme.orange.opacity(0.3), lineWidth: 1))
                        }.buttonStyle(.plain)
                    }

                    ForEach(results) { term in
                        NavigationLink { TermDetailView(term: term) } label: {
                            termRow(term)
                        }.buttonStyle(.plain)
                    }
                    if results.isEmpty {
                        EmptyStateView(icon: "magnifyingglass", title: "見つかりません",
                                       message: "別のキーワードで検索してみてください。")
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("用語カード")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filterChip(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .foregroundStyle(active ? .white : Theme.inkSoft)
                .background(active ? Theme.navy : Theme.card)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.line, lineWidth: active ? 0 : 1))
        }
    }

    private func termRow(_ term: TermCard) -> some View {
        Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(term.term).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    Spacer()
                    DomainChip(domain: term.domain)
                }
                Text(term.shortDescription).font(.system(size: 14)).foregroundStyle(Theme.ink)
            }
        }
    }
}

/// 用語カード詳細（フリップ式の表示）
struct TermDetailView: View {
    let term: TermCard
    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    HStack { DomainChip(domain: term.domain); Spacer() }
                    Text(term.term).titleStyle()
                    Text(term.shortDescription)
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(Theme.blue)

                    infoCard("初心者向け説明", term.beginnerExplanation, "person.fill.questionmark", Theme.blue)
                    infoCard("いつ使う？", term.useCase, "wrench.and.screwdriver.fill", Theme.teal)
                    infoCard("試験ポイント", term.examPoint, "checkmark.seal.fill", Theme.orange)

                    if !term.relatedServices.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            Text("関連サービス").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSoft)
                            FlowChips(items: term.relatedServices)
                        }
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle(term.term)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoCard(_ title: String, _ body: String, _ icon: String, _ color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon).foregroundStyle(color)
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
                }
                GlossaryText(text: body, size: 15, color: Theme.ink)
            }
        }
    }
}

/// 簡易な折り返しチップ表示
struct FlowChips: View {
    let items: [String]
    var body: some View {
        // シンプルに横スクロールで表現（折り返しは構成簡素化のため省略）
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.s) {
                ForEach(items, id: \.self) { TagChip(text: $0, color: Theme.blue) }
            }
        }
    }
}
