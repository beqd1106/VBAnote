import SwiftUI

/// オンボーディング〜初回診断〜プラン選択を1つのフローで扱う。
struct OnboardingFlowView: View {
    @EnvironmentObject var store: StudyStore
    @State private var step = 0

    // 診断入力
    @State private var name = ""
    @State private var experience: ExperienceLevel = .noneAtAll
    @State private var dailyMinutes = 30
    @State private var hasExamDate = false
    @State private var examDate = Calendar.current.date(byAdding: .day, value: 56, to: .now)!
    @State private var weakDomains: Set<ExamDomain> = []
    @State private var selectedPlan: StudyPlanType = .standard8

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                // 進捗インジケータ
                HStack(spacing: 6) {
                    ForEach(0..<4) { i in
                        Capsule()
                            .fill(i <= step ? Theme.orange : Theme.line)
                            .frame(height: 5)
                    }
                }
                .padding(.horizontal, Theme.Space.xl)
                .padding(.top, Theme.Space.m)

                TabView(selection: $step) {
                    welcomePage.tag(0)
                    diagnosisPage.tag(1)
                    weakAreaPage.tag(2)
                    planPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)
            }
        }
    }

    // MARK: - 0. ようこそ

    private var welcomePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                Spacer(minLength: Theme.Space.s)
                Image(systemName: "sparkles")
                    .font(.system(size: 48)).foregroundStyle(Theme.blue)
                Text(ExamInfo.appName).titleStyle()
                Text("完全初心者から、\(ExamInfo.examFullName)合格を目指す学習アプリです。")
                    .font(.system(size: 16)).foregroundStyle(Theme.ink)

                VStack(alignment: .leading, spacing: Theme.Space.m) {
                    featureRow("calendar", "毎日やることが分かる", "学習プランに沿って今日のタスクを提示")
                    featureRow("text.book.closed.fill", "用語を身近な例えで理解", "専門用語をかみ砕いて説明")
                    featureRow("arrow.clockwise", "間違いを自動で復習", "忘れた頃に再出題して定着")
                    featureRow("chart.pie.fill", "苦手と合格可能性が見える", "弱点を可視化して対策")
                }
                Spacer(minLength: Theme.Space.l)
                PrimaryButton(title: "はじめる", icon: "arrow.right") { withAnimation { step = 1 } }
                Text("※試験範囲・配点は変更されることがあります。最新情報は必ず\(ExamInfo.officialSite)でご確認ください。")
                    .captionStyle()
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.vertical, Theme.Space.l)
        }
    }

    private func featureRow(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.m) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Theme.orange)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(subtitle).captionStyle()
            }
        }
    }

    // MARK: - 1. 診断

    private var diagnosisPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                pageTitle("かんたん診断", "あなたに合った学習プランを作ります")

                field("ニックネーム（任意）") {
                    TextField("例：たろう", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                field("AI・ITの経験") {
                    VStack(spacing: Theme.Space.s) {
                        ForEach(ExperienceLevel.allCases) { level in
                            selectableRow(title: level.title, subtitle: level.detail,
                                          selected: experience == level) {
                                experience = level
                                selectedPlan = recommendedPlan(for: level)
                            }
                        }
                    }
                }

                field("1日の学習時間：約\(dailyMinutes)分") {
                    Slider(value: Binding(get: { Double(dailyMinutes) },
                                          set: { dailyMinutes = Int($0) }),
                           in: 10...90, step: 5)
                    .tint(Theme.orange)
                }

                field("試験予定日") {
                    Toggle("試験日を決めている", isOn: $hasExamDate).tint(Theme.blue)
                    if hasExamDate {
                        DatePicker("受験日", selection: $examDate, in: Date()...,
                                   displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                }

                PrimaryButton(title: "次へ", icon: "arrow.right") { withAnimation { step = 2 } }
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.vertical, Theme.Space.l)
        }
    }

    // MARK: - 2. 苦手分野

    private var weakAreaPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                pageTitle("苦手そうな分野は？", "複数選択できます（後から変更可）")
                VStack(spacing: Theme.Space.s) {
                    ForEach(ExamDomain.allCases) { domain in
                        selectableRow(title: domain.title,
                                      subtitle: "出題比率 約\(domain.weightPercent)%",
                                      selected: weakDomains.contains(domain)) {
                            if weakDomains.contains(domain) { weakDomains.remove(domain) }
                            else { weakDomains.insert(domain) }
                        }
                    }
                }
                Text("どれも分からなくても大丈夫。ゼロから順番に学べます。")
                    .captionStyle()
                PrimaryButton(title: "プランを見る", icon: "arrow.right") { withAnimation { step = 3 } }
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.vertical, Theme.Space.l)
        }
    }

    // MARK: - 3. プラン

    private var planPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.l) {
                pageTitle("学習プランを選ぶ", "あなたには「\(recommendedPlan(for: experience).title)」がおすすめです")

                VStack(spacing: Theme.Space.m) {
                    ForEach(StudyPlanType.allCases) { plan in
                        planCard(plan)
                    }
                }

                PrimaryButton(title: "このプランで始める", icon: "checkmark") {
                    finish()
                }
            }
            .padding(.horizontal, Theme.Space.xl)
            .padding(.vertical, Theme.Space.l)
        }
    }

    private func planCard(_ plan: StudyPlanType) -> some View {
        let selected = selectedPlan == plan
        let recommended = plan == recommendedPlan(for: experience)
        return Button { selectedPlan = plan } label: {
            Card {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(plan.title).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                            if recommended { TagChip(text: "おすすめ", color: Theme.orange) }
                        }
                        Text(plan.subtitle).captionStyle()
                        Text("目安：1日 約\(plan.recommendedDailyMinutes)分").captionStyle()
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(selected ? Theme.orange : Theme.line)
                }
            }
        }
        .buttonStyle(.plain)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(selected ? Theme.orange : .clear, lineWidth: 2)
        )
    }

    // MARK: - 部品

    private func pageTitle(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).titleStyle()
            Text(subtitle).font(.system(size: 15)).foregroundStyle(Theme.inkSoft)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
            content()
        }
    }

    private func selectableRow(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text(subtitle).captionStyle()
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.orange : Theme.line)
            }
            .padding(Theme.Space.m)
            .background(selected ? Theme.orangeSoft : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.chip)
                .stroke(selected ? Theme.orange : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func recommendedPlan(for level: ExperienceLevel) -> StudyPlanType {
        switch level {
        case .noneAtAll: return .standard8
        case .someIT:    return .custom6
        case .someCloud: return .intensive4
        }
    }

    private func finish() {
        let profile = UserProfile(
            name: name,
            experience: experience,
            dailyStudyMinutes: dailyMinutes,
            targetExamDate: hasExamDate ? examDate : nil,
            plan: selectedPlan,
            weakDomains: Array(weakDomains)
        )
        store.createProfile(profile)
    }
}
