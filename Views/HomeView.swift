import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: StudyStore

    private let repo = ContentRepository.shared

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        AppWordmarkHeader()
                        todayHeroCard
                        examPrepBanner
                        continueLessonCard
                        quickActions
                        todaySection
                        weakAreaCard
                        categorySection
                        roadmapCard
                    }
                    .padding(.horizontal, Theme.Space.l)
                    .padding(.bottom, Theme.Space.l)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
        }
    }

    // MARK: - 今日の学習（進捗リング＋統計）

    private var todayHeroCard: some View {
        let score = store.passProbabilityScore()
        return Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack {
                    Label("今日の学習", systemImage: "checklist")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    Spacer()
                    Text(todayString).font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                }

                HStack(spacing: Theme.Space.l) {
                    ScoreRing(value: Double(score)/100, color: Theme.orange,
                              label: "\(score)", caption: "合格目安")
                        .frame(width: 104, height: 104)

                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        statRow("連続学習", "\(store.studyStreak()) 日")
                        statRow("累計演習", "\(store.totalAnswered) 問")
                        statRow("復習待ち", "\(store.dueReviewCount) 問")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(PassProbability.label(for: score))
                    .font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(Theme.bg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: Theme.Space.s) {
            Circle().fill(Theme.orange).frame(width: 7, height: 7)
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.navy)
        }
    }

    // MARK: - 試験直前バナー

    @ViewBuilder private var examPrepBanner: some View {
        if let days = store.profile?.daysUntilExam, days >= 0, days <= 7 {
            NavigationLink(value: HomeRoute.finalCheck) {
                Card {
                    HStack(spacing: Theme.Space.m) {
                        Image(systemName: "bolt.fill").font(.system(size: 22)).foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Theme.orange).clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("試験直前モード").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                            Text("残り\(days)日。頻出ポイントを総復習").captionStyle()
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 続きから学習（次の未履修レッスン）

    @ViewBuilder private var continueLessonCard: some View {
        if let lesson = store.nextUnfinishedLesson() {
            let done = store.completedLessonCount
            let total = repo.lessons.count
            NavigationLink(value: HomeRoute.lesson(lesson.id)) {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        HStack {
                            Label("続きから学習", systemImage: "play.circle.fill")
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.blue)
                            Spacer()
                            Text("\(done)/\(total) レッスン").captionStyle()
                        }
                        HStack(spacing: Theme.Space.m) {
                            Image(systemName: "text.book.closed.fill").foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(lesson.domain.color)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                Text("\(lesson.domain.shortTitle)・約\(lesson.estimatedMinutes)分").captionStyle()
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - クイックアクション（4タイル）

    private var quickActions: some View {
        HStack(spacing: Theme.Space.m) {
            quickTile("用語カード", "rectangle.on.rectangle.angled", .termSearch)
            quickTile("問題演習", "checklist", .quizMixed)
            quickTile("復習", "arrow.clockwise", .review, badge: store.dueReviewCount)
            quickTile("お気に入り", "star.fill", .bookmarks)
        }
    }

    private func quickTile(_ title: String, _ icon: String, _ route: HomeRoute, badge: Int = 0) -> some View {
        NavigationLink(value: route) {
            VStack(spacing: Theme.Space.s) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                        .frame(width: 54, height: 54)
                        .background(Theme.orangeSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(minWidth: 18, minHeight: 18)
                            .background(Theme.red).clipShape(Circle())
                            .offset(x: 6, y: -6)
                    }
                }
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.Space.m)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: Theme.cardShadow(), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 今日の学習タスク

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: "今日のおすすめ")
            ForEach(store.todayTasks()) { task in
                NavigationLink(value: route(for: task)) {
                    taskRow(task)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func taskRow(_ task: TodayTask) -> some View {
        Card(padding: Theme.Space.m) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: icon(for: task.kind))
                    .font(.system(size: 18)).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(color(for: task.kind))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(task.subtitle).captionStyle()
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
            }
        }
    }

    // MARK: - 苦手克服のおすすめ（苦手分析連動）

    @ViewBuilder private var weakAreaCard: some View {
        if let rec = store.weakAreaRecommendation() {
            NavigationLink(value: HomeRoute.lesson(rec.lesson.id)) {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Space.s) {
                        HStack {
                            Label("苦手克服のおすすめ", systemImage: "target")
                                .font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.orange)
                            Spacer()
                            Text("\(rec.domain.shortTitle) 正答率 \(Int(rec.rate * 100))%")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(rec.rate >= 0.7 ? Theme.green : Theme.red)
                        }
                        HStack(spacing: Theme.Space.m) {
                            Image(systemName: rec.domain.systemIcon).foregroundStyle(.white)
                                .frame(width: 40, height: 40).background(rec.domain.color)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(rec.domain.title)を集中的に固めよう")
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                Text("「\(rec.lesson.title)」の反復ドリルで基礎から").captionStyle()
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - カテゴリ（4分野）

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            SectionHeader(title: "分野から学ぶ")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.Space.m),
                                GridItem(.flexible(), spacing: Theme.Space.m)],
                      spacing: Theme.Space.m) {
                ForEach(ExamDomain.allCases) { domain in
                    NavigationLink(value: HomeRoute.quiz(domain)) {
                        categoryCard(domain)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryCard(_ domain: ExamDomain) -> some View {
        let count = repo.questions(in: domain).count
        let rate = store.correctRateByDomain()[domain] ?? 0
        let answered = store.answeredCount(in: domain)
        return Card(padding: Theme.Space.m) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: domain.systemIcon)
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(domain.color)
                        .frame(width: 36, height: 36)
                        .background(domain.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    if answered > 0 {
                        Text("\(Int(rate*100))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(rate >= 0.7 ? Theme.green : Theme.orange)
                    }
                }
                Text(domain.title).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.navy)
                    .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Text("\(count)問").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - ロードマップ

    private var roadmapCard: some View {
        NavigationLink(value: HomeRoute.roadmap) {
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    HStack {
                        Label("学習ロードマップ", systemImage: "map.fill")
                            .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                    }
                    let plan = store.profile?.plan ?? .standard8
                    Text("\(plan.title)（全\(plan.durationWeeks)週）／今は\(store.currentWeek)週目")
                        .captionStyle()
                    ProgressBar(value: Double(store.currentWeek) / Double(plan.durationWeeks), color: Theme.orange)
                    if let goal = PlanFactory.roadmap(for: plan).first(where: { $0.week == store.currentWeek }) {
                        Text("今週：\(goal.title)").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.orange)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - ルーティング

    private func route(for task: TodayTask) -> HomeRoute {
        switch task.kind {
        case .lesson: return .lesson(task.refId ?? "")
        case .terms:  return .terms(ExamDomain(rawValue: task.refId ?? "") ?? ExamDomain.allCases[0])
        case .quiz:   return .quiz(ExamDomain(rawValue: task.refId ?? "") ?? ExamDomain.allCases[0])
        case .review: return .review
        }
    }

    @ViewBuilder private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .lesson(let id):
            if let lesson = repo.lessons.first(where: { $0.id == id }) {
                LessonDetailView(lesson: lesson)
            }
        case .terms(let domain):
            TermListView(domain: domain)
        case .quiz(let domain):
            QuizPlayerView(title: domain.shortTitle + "の問題",
                           questions: Array(repo.questions(in: domain).shuffled().prefix(10)))
        case .quizMixed:
            QuizPlayerView(title: "今日の問題",
                           questions: Array(repo.questions.shuffled().prefix(10)))
        case .review:
            QuizPlayerView(title: "復習", questions: store.dueReviewQuestions(limit: 10))
        case .bookmarks:
            QuizPlayerView(title: "お気に入り", questions: store.bookmarkedQuestions())
        case .termSearch:
            TermListView()
        case .roadmap:
            RoadmapView()
        case .finalCheck:
            FinalCheckView()
        }
    }

    // MARK: - ヘルパ

    private var todayString: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "M月d日 (E)"
        return f.string(from: .now)
    }

    private func icon(for kind: TodayTask.Kind) -> String {
        switch kind {
        case .lesson: return "text.book.closed.fill"
        case .terms: return "rectangle.on.rectangle.angled"
        case .quiz: return "checklist"
        case .review: return "arrow.clockwise"
        }
    }
    private func color(for kind: TodayTask.Kind) -> Color {
        switch kind {
        case .lesson: return Theme.blue
        case .terms: return Theme.teal
        case .quiz: return Theme.orange
        case .review: return Theme.navy
        }
    }
}

/// ホームからの遷移先
enum HomeRoute: Hashable {
    case lesson(String)
    case terms(ExamDomain)
    case quiz(ExamDomain)
    case quizMixed
    case review
    case bookmarks
    case roadmap
    case finalCheck
    case termSearch
}

/// アプリ名ワードマークのヘッダー（アイコンのブランドに合わせたノート風）
private struct AppWordmarkHeader: View {
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text(ExamInfo.brandPrefix).font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.navy)
                    Text("note").font(.system(size: 30, weight: .regular)).foregroundStyle(Theme.navy.opacity(0.8))
                }
                // オレンジの手描き風アンダーライン
                Capsule().fill(Theme.orange).frame(width: 60, height: 3)
            }
            Spacer()
            NavigationLink(value: HomeRoute.termSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 42, height: 42)
                    .background(Theme.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
            }
        }
        .padding(.top, Theme.Space.s)
        .padding(.bottom, Theme.Space.xs)
    }
}
