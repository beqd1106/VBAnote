import SwiftUI

// MARK: - 聞き流し：チャプター一覧

/// 聞き流しの入口。通勤ミックス（時間で選ぶ）・続きから・復習/お気に入り・分野ごとのチャプター。
struct ListeningHubView: View {
    @EnvironmentObject var store: StudyStore
    @State private var progress = ListeningProgress.load(examKey: ExamContext.current.key)
    @State private var presented: PresentedChapter?

    private let repo = ContentRepository.shared
    private var examKey: String { ExamContext.current.key }

    /// 再生画面に渡すもの
    struct PresentedChapter: Identifiable {
        let chapter: ListeningChapter
        let startAt: Int
        var id: String { chapter.id + "#\(startAt)" }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    intro
                    continueCard
                    mixRow
                    specialLists
                    ForEach(ExamDomain.allCases) { domain in
                        domainSection(domain)
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("聞き流し")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $presented, onDismiss: { progress = .load(examKey: examKey) }) { p in
            ListeningPlayerView(chapter: p.chapter, startAt: p.startAt, allChapters: allDomainChapters)
                .environmentObject(store)
        }
    }

    private var allDomainChapters: [ListeningChapter] {
        ExamDomain.allCases.flatMap { ListeningCatalog.domainChapters($0) }
    }

    private func open(_ chapter: ListeningChapter, at index: Int = 0) {
        guard !chapter.questionIds.isEmpty else { return }
        presented = PresentedChapter(chapter: chapter, startAt: index)
    }

    // MARK: 部品

    private var intro: some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: "headphones").font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.orange)
                .frame(width: 48, height: 48).background(Theme.orangeSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("耳で1区切り（約3分）").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.navy)
                Text("問題 → 考える間 → 答え → 解説の順に流れます。画面を消しても続き、ロック画面やイヤホンで操作できます。")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var continueCard: some View {
        if let id = progress.lastChapterId, let chapter = chapter(for: id), progress.lastIndex < chapter.questionIds.count {
            Button { open(chapter, at: progress.lastIndex) } label: {
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: "play.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(Theme.orange))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("続きから聞く").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.orange)
                        Text(chapter.title).font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                        Text("\(progress.lastIndex + 1)問目から・残り\(chapter.questionIds.count - progress.lastIndex)問")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.7))
                }
                .padding(Theme.Space.l)
                .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.navy))
            }
            .buttonStyle(.pressable)
        }
    }

    private var mixRow: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: "通勤ミックス（時間で選ぶ）")
            HStack(spacing: Theme.Space.s) {
                ForEach([3, 10, 20], id: \.self) { m in
                    Button { open(ListeningCatalog.mix(minutes: m, store: store, progress: progress)) } label: {
                        VStack(spacing: 2) {
                            Text("\(m)").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.navy)
                            Text("分").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSoft)
                        }
                        .frame(maxWidth: .infinity, minHeight: 72)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(Theme.line, lineWidth: 1))
                        .shadow(color: Theme.cardShadow(), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("通勤ミックス\(m)分を再生")
                }
            }
            Text("復習待ち → 苦手な分野 → まだ聞いていない問題 の順に自動で選びます")
                .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
        }
    }

    @ViewBuilder private var specialLists: some View {
        let lists = [ListeningCatalog.review(store: store), ListeningCatalog.favorites(store: store)].compactMap { $0 }
        if !lists.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                SectionHeader(title: "リスト")
                ForEach(lists) { chapter in
                    chapterRow(chapter, icon: chapter.kind == .review ? "arrow.clockwise" : "star.fill")
                }
            }
        }
    }

    private func domainSection(_ domain: ExamDomain) -> some View {
        let chapters = ListeningCatalog.domainChapters(domain)
        let done = chapters.filter { progress.completedChapterIds.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: Theme.Space.s) {
            HStack {
                Text(domain.title).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.navy)
                Spacer()
                Text("\(done)/\(chapters.count) チャプター").captionStyle()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Space.s) {
                    ForEach(chapters) { c in chapterChip(c, color: domain.color) }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// 分野のチャプターは横に並ぶ小さなタイル（聞いたものはチェック）
    private func chapterChip(_ c: ListeningChapter, color: Color) -> some View {
        let done = progress.completedChapterIds.contains(c.id)
        let fav = progress.favoriteChapterIds.contains(c.id)
        return Button { open(c) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: done ? "checkmark.circle.fill" : "play.circle.fill")
                        .font(.system(size: 20)).foregroundStyle(done ? Theme.green : color)
                    Spacer()
                    if fav { Image(systemName: "star.fill").font(.system(size: 11)).foregroundStyle(Theme.orange) }
                }
                Text(c.title.components(separatedBy: " ").last.map { "チャプター\($0)" } ?? c.title)
                    .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.ink)
                Text("\(c.questionIds.count)問・約\(c.minutes)分").font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
            }
            .padding(Theme.Space.m)
            .frame(width: 118, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(done ? Theme.green.opacity(0.4) : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .contextMenu {
            Button(fav ? "お気に入りから外す" : "お気に入りにする", systemImage: fav ? "star.slash" : "star") {
                if fav { progress.favoriteChapterIds.remove(c.id) } else { progress.favoriteChapterIds.insert(c.id) }
                progress.save(examKey: examKey)
            }
        }
        .accessibilityLabel("\(c.title)、\(c.questionIds.count)問\(done ? "、聞き終わり" : "")")
    }

    private func chapterRow(_ c: ListeningChapter, icon: String) -> some View {
        Button { open(c) } label: {
            Card(padding: Theme.Space.m) {
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: icon).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(Theme.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(c.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("\(c.subtitle)・約\(c.minutes)分").captionStyle()
                    }
                    Spacer()
                    Image(systemName: "play.fill").foregroundStyle(Theme.orange)
                }
            }
        }
        .buttonStyle(.pressable)
    }

    private func chapter(for id: String) -> ListeningChapter? {
        allDomainChapters.first { $0.id == id }
            ?? (id == "review" ? ListeningCatalog.review(store: store) : nil)
            ?? (id == "favorites" ? ListeningCatalog.favorites(store: store) : nil)
    }
}

// MARK: - 聞き流し：再生画面（縦スワイプで1問ずつ）

struct ListeningPlayerView: View {
    let chapter: ListeningChapter
    let startAt: Int
    /// 自動で次へ進むときに使う、分野チャプターの並び
    let allChapters: [ListeningChapter]

    @EnvironmentObject var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var player = ListeningPlayer.shared
    @State private var scrolledIndex: Int?
    @State private var showSettings = false

    @AppStorage(ListeningSettings.Keys.rate) private var rate = 1.0
    @AppStorage(ListeningSettings.Keys.recallPause) private var recallPause = 3.0
    @AppStorage(ListeningSettings.Keys.readExplanation) private var readExplanation = true
    @AppStorage(ListeningSettings.Keys.autoNext) private var autoNext = false

    private let repo = ContentRepository.shared
    private var examKey: String { ExamContext.current.key }

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()
            pages
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
            if player.phase == .chapterDone && !player.isPlaying {
                chapterDoneOverlay
            }
        }
        .onAppear(perform: start)
        .onChange(of: scrolledIndex) {
            if let i = scrolledIndex, i != player.index { player.jump(to: i) }
        }
        .onChange(of: player.index) {
            if scrolledIndex != player.index {
                withAnimation(.easeInOut(duration: 0.3)) { scrolledIndex = player.index }
            }
            saveLastPosition()
        }
        .onChange(of: player.chapter?.id) { scrolledIndex = player.index }
        .sheet(isPresented: $showSettings) { settingsSheet.presentationDetents([.medium]) }
        .statusBarHidden(false)
        .preferredColorScheme(.dark)
    }

    // MARK: 開始と記録

    private func start() {
        let qs = chapter.questionIds.compactMap { repo.question(id: $0) }
        player.onQuestionHeard = { q in
            var p = ListeningProgress.load(examKey: examKey)
            p.heardIds.insert(q.id)
            p.save(examKey: examKey)
            store.logListening()
        }
        player.onChapterCompleted = { c in
            var p = ListeningProgress.load(examKey: examKey)
            p.completedChapterIds.insert(c.id)
            p.lastChapterId = nil; p.lastIndex = 0
            p.save(examKey: examKey)
        }
        player.onToggleFavorite = { q in store.toggleBookmark(q.id) }
        let mastery = store.listeningMastery()
        player.masteryProvider = { q in
            mastery.weak.contains(q.id) ? .weak : mastery.solid.contains(q.id) ? .solid : .new
        }
        player.nextChapterProvider = { current in
            guard let i = allChapters.firstIndex(where: { $0.id == current.id }), i + 1 < allChapters.count else { return nil }
            let next = allChapters[i + 1]
            return (next, next.questionIds.compactMap { repo.question(id: $0) })
        }
        player.load(chapter, questions: qs, startAt: startAt)
        scrolledIndex = player.index
    }

    private func saveLastPosition() {
        guard let c = player.chapter, player.phase != .chapterDone else { return }
        var p = ListeningProgress.load(examKey: examKey)
        p.lastChapterId = c.id; p.lastIndex = player.index
        p.save(examKey: examKey)
    }

    // MARK: ページ（1問1画面・縦スワイプ）

    private var pages: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(player.questions.enumerated()), id: \.offset) { i, q in
                    page(q, isCurrent: i == player.index)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(i)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledIndex)
        .ignoresSafeArea()
    }

    private func page(_ q: QuizQuestion, isCurrent: Bool) -> some View {
        let showAnswer = isCurrent && [.answer, .explanation, .chapterDone].contains(player.phase)
        let showExplanation = isCurrent && [.explanation, .chapterDone].contains(player.phase)
        return HStack(alignment: .bottom, spacing: Theme.Space.m) {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Spacer(minLength: 96)
                DomainChip(domain: q.domain)
                Text(q.question)
                    .font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, c in
                        let correct = q.correctAnswers.contains(i)
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(i + 1)").font(.system(size: 13, weight: .bold))
                                .frame(width: 24, height: 24)
                                .background(Circle().fill(showAnswer && correct ? Theme.orange : .white.opacity(0.12)))
                            Text(c).font(.system(size: 15, weight: showAnswer && correct ? .bold : .regular))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.white.opacity(showAnswer && !correct ? 0.45 : 0.92))
                    }
                }
                if isCurrent && player.phase == .thinking {
                    Label("考えてみよう…", systemImage: "brain.head.profile")
                        .font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.orange)
                        .transition(.opacity)
                }
                if showExplanation {
                    Text(ListeningScript.shortExplanation(q.explanation))
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.8))
                        .padding(Theme.Space.m)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.08)))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
                Spacer(minLength: 150)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            sideRail(q).padding(.bottom, 150)
        }
        .padding(.horizontal, Theme.Space.l)
        .contentShape(Rectangle())
        .onTapGesture { player.togglePlay() }
        .animation(.easeOut(duration: 0.25), value: player.phase)
        .accessibilityElement(children: .contain)
    }

    /// 右側の縦ボタン（親指が届く位置）
    private func sideRail(_ q: QuizQuestion) -> some View {
        VStack(spacing: Theme.Space.l) {
            railButton(store.isBookmarked(q.id) ? "star.fill" : "star", "お気に入り",
                       tint: store.isBookmarked(q.id) ? Theme.orange : .white) { store.toggleBookmark(q.id) }
            railButton(readExplanation ? "text.bubble.fill" : "text.bubble", readExplanation ? "解説あり" : "解説なし") {
                readExplanation.toggle()
            }
            railButton("speedometer", String(format: "%.1fx", rate)) {
                let rates = ListeningSettings.rates
                rate = rates[((rates.firstIndex(of: rate) ?? 1) + 1) % rates.count]
            }
            railButton(autoNext ? "infinity.circle.fill" : "infinity.circle", autoNext ? "連続再生" : "1区切り") {
                autoNext.toggle()
            }
            railButton("slider.horizontal.3", "設定") { showSettings = true }
        }
    }

    private func railButton(_ icon: String, _ label: String, tint: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 22, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(.white.opacity(0.12)))
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(label)
    }

    // MARK: 上下のバー

    private var topBar: some View {
        VStack(spacing: Theme.Space.s) {
            HStack {
                Button { player.stop(); dismiss() } label: {
                    Image(systemName: "chevron.down").font(.system(size: 18, weight: .bold))
                        .frame(width: 44, height: 44).background(Circle().fill(.white.opacity(0.12)))
                }
                .accessibilityLabel("閉じる")
                Spacer()
                VStack(spacing: 2) {
                    Text(player.chapter?.title ?? chapter.title).font(.system(size: 14, weight: .bold))
                    Text("\(player.index + 1) / \(player.questions.count)問").font(.system(size: 12)).opacity(0.7)
                }
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            // ストーリー風の区切り線（いま何問目か）
            HStack(spacing: 4) {
                ForEach(0..<max(player.questions.count, 1), id: \.self) { i in
                    Capsule().fill(i < player.index ? Theme.orange : i == player.index ? .white : .white.opacity(0.25))
                        .frame(height: 3)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Theme.Space.l)
        .padding(.top, Theme.Space.s)
    }

    private var bottomBar: some View {
        HStack(spacing: Theme.Space.l) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill").font(.system(size: 18)).frame(width: 48, height: 48)
            }.accessibilityLabel("前の問題")
            Button { player.togglePlay() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.navy)
                    .frame(width: 68, height: 68).background(Circle().fill(Theme.orange))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(player.isPlaying ? "一時停止" : "再生")
            Button { player.next() } label: {
                Image(systemName: "forward.fill").font(.system(size: 18)).frame(width: 48, height: 48)
            }.accessibilityLabel("次の問題")
        }
        .foregroundStyle(.white)
        .padding(.bottom, Theme.Space.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Theme.navy.opacity(0), Theme.navy], startPoint: .top, endPoint: .bottom)
                .frame(height: 160).allowsHitTesting(false), alignment: .bottom
        )
    }

    // MARK: チャプター完了

    private var chapterDoneOverlay: some View {
        let next = nextChapter
        return VStack(spacing: Theme.Space.l) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 52)).foregroundStyle(Theme.green)
            Text("1区切り完了").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
            Text("\(player.questions.count)問を聞きました。お気に入りにした問題は「演習」のお気に入りからも解けます。")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            VStack(spacing: Theme.Space.m) {
                if let next {
                    PrimaryButton(title: "次へ：\(next.title)", icon: "play.fill") {
                        player.load(next, questions: next.questionIds.compactMap { repo.question(id: $0) })
                    }
                }
                SecondaryButton(title: "今日はここまで", icon: "checkmark") { player.stop(); dismiss() }
            }
        }
        .padding(Theme.Space.xl)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.navy.opacity(0.96)))
        .padding(Theme.Space.l)
    }

    private var nextChapter: ListeningChapter? {
        guard let id = player.chapter?.id, let i = allChapters.firstIndex(where: { $0.id == id }),
              i + 1 < allChapters.count else { return nil }
        return allChapters[i + 1]
    }

    // MARK: 設定

    private var settingsSheet: some View {
        NavigationStack {
            Form {
                Section("答えの前の間") {
                    Picker("考える時間", selection: $recallPause) {
                        Text("聞くだけ（すぐ答え）").tag(0.0)
                        Text("3秒").tag(3.0)
                        Text("5秒").tag(5.0)
                        Text("8秒").tag(8.0)
                    }
                    Text("間をあけると、答えを思い出す練習になります。間違えたことのある問題は長め、正解した問題は短めに自動で調整します。").font(.footnote).foregroundStyle(.secondary)
                }
                Section("読み上げ") {
                    Picker("速さ", selection: $rate) {
                        ForEach(ListeningSettings.rates, id: \.self) { Text(String(format: "%.1f倍", $0)).tag($0) }
                    }
                    Toggle("解説も読む", isOn: $readExplanation)
                    Toggle("チャプターが終わったら次へ進む", isOn: $autoNext)
                }
                Section("スリープタイマー") {
                    Button("このチャプターの終わりで止める") { player.stopAtChapterEnd = true; showSettings = false }
                    Button("15分後に止める") { player.sleepAt = Date().addingTimeInterval(15 * 60); showSettings = false }
                    Button("30分後に止める") { player.sleepAt = Date().addingTimeInterval(30 * 60); showSettings = false }
                    if player.sleepAt != nil || player.stopAtChapterEnd {
                        Button("タイマーを解除", role: .destructive) { player.sleepAt = nil; player.stopAtChapterEnd = false }
                    }
                }
                Section {
                    Text("声は「設定 > アクセシビリティ > 読み上げコンテンツ > 声 > 日本語」で高品質の声をダウンロードすると聞きやすくなります。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("聞き流しの設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { showSettings = false } } }
        }
        .preferredColorScheme(.light)
    }
}
