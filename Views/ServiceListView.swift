import SwiftUI

/// 頻出キーワード一覧（カテゴリ別）。見出しは ExamInfo.servicesTitle
struct ServiceListView: View {
    @State private var keyword = ""
    private var services: [GenAIToolItem] {
        let all = ContentRepository.shared.services
        let k = keyword.trimmingCharacters(in: .whitespaces).lowercased()
        guard !k.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(k) || $0.oneLiner.contains(k) || $0.category.contains(k) }
    }
    private var categories: [String] {
        Array(Set(services.map(\.category))).sorted()
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.l) {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                        TextField(ExamInfo.servicesSearchPlaceholder, text: $keyword)
                    }
                    .padding(Theme.Space.m).background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))

                    ForEach(categories, id: \.self) { cat in
                        VStack(alignment: .leading, spacing: Theme.Space.s) {
                            Text(cat).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.navy)
                            ForEach(services.filter { $0.category == cat }) { svc in
                                Card(padding: Theme.Space.m) {
                                    HStack(spacing: Theme.Space.m) {
                                        Image(systemName: svc.domain.systemIcon)
                                            .foregroundStyle(svc.domain.color).frame(width: 28)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(svc.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                                            Text(svc.oneLiner).captionStyle()
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle(ExamInfo.servicesTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
