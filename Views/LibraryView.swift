import SwiftUI

enum LibraryRoute: Hashable {
    case lessonsAll
    case termsAll
    case services
    case roadmap
    case lesson(String)
    case term(String)
}

struct LibraryView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: Theme.Space.m) {
                        hubRow("分野別レッスン", "図解と例え話でやさしく学ぶ",
                               "text.book.closed.fill", Theme.blue, .lessonsAll)
                        hubRow("用語カード", "\(ExamInfo.examShortName)の重要用語を一言＋使いどころで理解",
                               "rectangle.on.rectangle.angled", Theme.teal, .termsAll)
                        hubRow(ExamInfo.servicesTitle, ExamInfo.servicesSubtitle,
                               "square.grid.2x2.fill", Theme.orange, .services)
                        hubRow("学習ロードマップ", "全\(store.profile?.plan.durationWeeks ?? 8)週の道のり",
                               "map.fill", Theme.navy, .roadmap)
                    }
                    .padding(Theme.Space.l)
                }
            }
            .navigationTitle("学ぶ")
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .lessonsAll: LessonListView()
                case .termsAll:   TermListView()
                case .services:   ServiceListView()
                case .roadmap:    RoadmapView()
                case .lesson(let id):
                    if let l = ContentRepository.shared.lessons.first(where: { $0.id == id }) {
                        LessonDetailView(lesson: l)
                    }
                case .term(let id):
                    if let t = ContentRepository.shared.terms.first(where: { $0.id == id }) {
                        TermDetailView(term: t)
                    }
                }
            }
        }
    }

    private func hubRow(_ title: String, _ subtitle: String, _ icon: String, _ color: Color, _ route: LibraryRoute) -> some View {
        NavigationLink(value: route) {
            Card {
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(.white)
                        .frame(width: 48, height: 48).background(color)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        Text(subtitle).captionStyle()
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct RoadmapView: View {
    @EnvironmentObject var store: StudyStore
    var body: some View {
        let plan = store.profile?.plan ?? .standard8
        let roadmap = PlanFactory.roadmap(for: plan)
        let currentWeek = store.currentWeek
        return ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(plan.title).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.navy)
                            Text("全\(plan.durationWeeks)週間・1日約\(store.profile?.dailyStudyMinutes ?? plan.recommendedDailyMinutes)分").captionStyle()
                            ProgressBar(value: Double(currentWeek)/Double(plan.durationWeeks), color: Theme.blue)
                        }
                    }
                    ForEach(roadmap) { goal in
                        weekRow(goal, isCurrent: goal.week == currentWeek, isDone: goal.week < currentWeek)
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("学習ロードマップ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func weekRow(_ goal: WeekGoal, isCurrent: Bool, isDone: Bool) -> some View {
        Card {
            HStack(alignment: .top, spacing: Theme.Space.m) {
                ZStack {
                    Circle().fill(isCurrent ? Theme.orange : (isDone ? Theme.green : Theme.line))
                        .frame(width: 36, height: 36)
                    if isDone {
                        Image(systemName: "checkmark").foregroundStyle(.white).font(.system(size: 14, weight: .bold))
                    } else {
                        Text("\(goal.week)").foregroundStyle(isCurrent ? .white : Theme.inkSoft)
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Week \(goal.week)").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.inkSoft)
                        if isCurrent { TagChip(text: "今週", color: Theme.orange) }
                    }
                    Text(goal.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    Text(goal.detail).captionStyle()
                    HStack(spacing: 6) {
                        ForEach(goal.domains.prefix(4)) { DomainChip(domain: $0) }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
