import SwiftUI

enum PracticeRoute: Hashable {
    case domain(ExamDomain)
    case review
    case bookmarks
    case mock
    case custom
}

struct PracticeHubView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        // 模擬試験
                        NavigationLink(value: PracticeRoute.mock) {
                            Card {
                                HStack(spacing: Theme.Space.m) {
                                    Image(systemName: "graduationcap.fill").font(.system(size: 24))
                                        .foregroundStyle(.white).frame(width: 52, height: 52)
                                        .background(Theme.navy).clipShape(RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("模擬試験").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.navy)
                                        Text("本番形式・分野別スコアで実力チェック").captionStyle()
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }.buttonStyle(.plain)

                        // 復習＆お気に入り
                        HStack(spacing: Theme.Space.m) {
                            quickCard("復習", "\(store.dueReviewCount)問", "arrow.clockwise", Theme.orange, .review)
                            quickCard("お気に入り", "\(store.bookmarkedQuestions().count)問", "star.fill", Theme.blue, .bookmarks)
                        }

                        // カスタム演習
                        NavigationLink(value: PracticeRoute.custom) {
                            Card {
                                HStack(spacing: Theme.Space.m) {
                                    Image(systemName: "slider.horizontal.3").font(.system(size: 22))
                                        .foregroundStyle(.white).frame(width: 52, height: 52)
                                        .background(Theme.orange).clipShape(RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("カスタム演習").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.navy)
                                        Text("分野×難易度×苦手×お気に入りで絞って出題").captionStyle()
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }.buttonStyle(.plain)

                        // 分野別演習
                        SectionHeader(title: "分野別に演習")
                        ForEach(ExamDomain.allCases) { domain in
                            NavigationLink(value: PracticeRoute.domain(domain)) {
                                domainRow(domain)
                            }.buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.Space.l)
                }
            }
            .navigationTitle("演習")
            .navigationDestination(for: PracticeRoute.self) { route in
                switch route {
                case .domain(let d):
                    QuizPlayerView(title: d.title,
                                   questions: ContentRepository.shared.questions(in: d).shuffled())
                case .review:
                    QuizPlayerView(title: "復習", questions: store.dueReviewQuestions())
                case .bookmarks:
                    QuizPlayerView(title: "お気に入り", questions: store.bookmarkedQuestions())
                case .mock:
                    MockExamStartView()
                case .custom:
                    CustomPracticeView()
                }
            }
        }
    }

    private func quickCard(_ title: String, _ value: String, _ icon: String, _ color: Color, _ route: PracticeRoute) -> some View {
        NavigationLink(value: route) {
            Card {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: icon).foregroundStyle(color).font(.system(size: 20))
                    Text(value).font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.navy)
                    Text(title).captionStyle()
                }
            }
        }.buttonStyle(.plain)
    }

    private func domainRow(_ domain: ExamDomain) -> some View {
        let rate = store.correctRateByDomain()[domain] ?? 0
        let answered = store.answeredCount(in: domain)
        let total = ContentRepository.shared.questions(in: domain).count
        return Card(padding: Theme.Space.m) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: domain.systemIcon).font(.system(size: 18)).foregroundStyle(.white)
                    .frame(width: 40, height: 40).background(domain.color)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(domain.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    HStack(spacing: 6) {
                        Text("全\(total)問").captionStyle()
                        if answered > 0 {
                            Text("・正答率\(Int(rate*100))%").font(.system(size: 13))
                                .foregroundStyle(rate >= 0.7 ? Theme.green : Theme.orange)
                        }
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13))
            }
        }
    }
}
