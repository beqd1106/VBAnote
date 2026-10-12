import SwiftUI

struct AnalysisView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.l) {
                        passCard
                        domainBreakdown
                        weakestCard
                        badgesCard
                        mockHistory
                        NavigationLink(value: AnalysisRoute.calendar) {
                            Card {
                                HStack {
                                    Image(systemName: "calendar").foregroundStyle(Theme.blue)
                                    Text("学習カレンダー・記録の書き出し").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.navy)
                                    Spacer()
                                    Text("\(store.studyStreak())日連続").captionStyle()
                                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                                }
                            }
                        }.buttonStyle(.plain)
                    }
                    .padding(Theme.Space.l)
                }
            }
            .navigationTitle("分析")
            .navigationDestination(for: AnalysisRoute.self) { route in
                switch route {
                case .calendar: StudyCalendarView()
                }
            }
        }
    }

    // MARK: - 合格可能性

    private var passCard: some View {
        let score = store.passProbabilityScore()
        return Card {
            VStack(spacing: Theme.Space.m) {
                HStack(spacing: Theme.Space.l) {
                    ScoreRing(value: Double(score)/100, color: Theme.orange,
                              label: "\(score)", caption: "目安")
                        .frame(width: 110, height: 110)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("合格可能性スコア").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        Text(PassProbability.label(for: score)).font(.system(size: 14)).foregroundStyle(Theme.ink)
                    }
                }
                Text("※このスコアは学習を促すための目安です。合格を保証・予測するものではありません。")
                    .font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - 分野別正答率

    private var domainBreakdown: some View {
        let rates = store.correctRateByDomain()
        return Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("分野別の正答率").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                ForEach(ExamDomain.allCases) { d in
                    let answered = store.answeredCount(in: d)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(d.title).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                            Spacer()
                            if answered > 0 {
                                Text("\(Int((rates[d] ?? 0)*100))%").font(.system(size: 13, weight: .bold))
                                    .foregroundStyle((rates[d] ?? 0) >= 0.7 ? Theme.green : Theme.orange)
                            } else {
                                Text("未演習").font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                            }
                        }
                        ProgressBar(value: rates[d] ?? 0, color: d.color, height: 8)
                        Text("配点 約\(d.weightPercent)%・\(answered)問回答").font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
                    }
                }
            }
        }
    }

    // MARK: - 最も苦手

    @ViewBuilder private var weakestCard: some View {
        if let weak = store.weakestDomain() {
            Card {
                HStack(alignment: .top, spacing: Theme.Space.m) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.orange)
                        .font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("いま一番の苦手").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSoft)
                        Text(weak.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        Text("「演習」タブからこの分野を重点的に解きましょう。").captionStyle()
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - バッジ

    private var badgesCard: some View {
        let streak = store.studyStreak()
        let answered = store.totalAnswered
        let mocks = store.mockResults()
        let passed = mocks.contains { $0.isPassingScore }
        let badges: [(String, String, Bool)] = [
            ("はじめの一歩", "figure.walk", answered >= 1),
            ("3日坊主突破", "flame.fill", streak >= 3),
            ("100問達成", "100.circle.fill", answered >= 100),
            ("模試デビュー", "graduationcap.fill", !mocks.isEmpty),
            ("合格圏到達", "rosette", passed),
            ("7日連続", "calendar.badge.checkmark", streak >= 7),
        ]
        return Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("バッジ").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Space.m) {
                        ForEach(badges, id: \.0) { b in
                            BadgeView(title: b.0, icon: b.1, earned: b.2)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 模試履歴

    @ViewBuilder private var mockHistory: some View {
        let results = store.mockResults()
        if !results.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: Theme.Space.s) {
                    Text("模擬試験の記録").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    ForEach(results.prefix(5)) { r in
                        HStack {
                            Text(r.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                            Spacer()
                            Text("\(r.scaledScore)点").font(.system(size: 14, weight: .bold))
                                .foregroundStyle(r.isPassingScore ? Theme.green : Theme.orange)
                            Image(systemName: r.isPassingScore ? "checkmark.seal.fill" : "minus.circle")
                                .foregroundStyle(r.isPassingScore ? Theme.green : Theme.inkSoft)
                                .font(.system(size: 13))
                        }
                    }
                }
            }
        }
    }
}

enum AnalysisRoute: Hashable { case calendar }
