import SwiftUI

/// 用語カードの暗記モード（Anki風フリップ）。
/// 表＝用語、タップで裏返して意味・試験ポイントを確認。1枚ずつ学習する。
struct FlashcardView: View {
    let cards: [TermCard]
    @State private var index = 0
    @State private var isFlipped = false

    private var card: TermCard? { cards.indices.contains(index) ? cards[index] : nil }

    var body: some View {
        ZStack {
            AppBackground()
            if cards.isEmpty {
                EmptyStateView(icon: "rectangle.on.rectangle.angled", title: "カードがありません",
                               message: "別の分野やキーワードでお試しください。")
            } else {
                VStack(spacing: Theme.Space.l) {
                    // 進捗
                    HStack {
                        Text("\(index + 1) / \(cards.count)")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.inkSoft)
                        Spacer()
                        if let card { DomainChip(domain: card.domain) }
                    }
                    ProgressBar(value: Double(index + 1) / Double(cards.count))

                    Spacer(minLength: 0)

                    if let card { flipCard(card) }

                    Text(isFlipped ? "タップで表に戻る" : "タップで答えを表示")
                        .font(.system(size: 12)).foregroundStyle(Theme.inkSoft)

                    Spacer(minLength: 0)

                    // 操作
                    HStack(spacing: Theme.Space.m) {
                        SecondaryButton(title: "前へ", icon: "chevron.left") { move(-1) }
                            .frame(maxWidth: 130)
                            .opacity(index > 0 ? 1 : 0.4)
                            .disabled(index == 0)
                        PrimaryButton(title: index + 1 < cards.count ? "次へ" : "最初に戻る", icon: "chevron.right") {
                            if index + 1 < cards.count { move(1) } else { withAnimation { index = 0; isFlipped = false } }
                        }
                    }
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("暗記モード")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func move(_ delta: Int) {
        let next = index + delta
        guard cards.indices.contains(next) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { isFlipped = false }
        index = next
    }

    // フリップするカード本体
    private func flipCard(_ card: TermCard) -> some View {
        ZStack {
            cardFace {
                VStack(spacing: Theme.Space.m) {
                    Image(systemName: "questionmark.circle").font(.system(size: 26)).foregroundStyle(card.domain.color)
                    Text(card.term).font(.system(size: 24, weight: .heavy)).foregroundStyle(Theme.navy)
                        .multilineTextAlignment(.center)
                    Text(card.shortDescription).font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
            }
            .opacity(isFlipped ? 0 : 1)

            cardFace {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Space.m) {
                        Text(card.term).font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.navy)
                        block("初心者向け", card.beginnerExplanation, Theme.blue)
                        block("試験ポイント", card.examPoint, Theme.orange)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .onTapGesture { withAnimation(.easeInOut(duration: 0.35)) { isFlipped.toggle() } }
    }

    private func cardFace<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(Theme.Space.xl)
            .frame(maxWidth: .infinity, minHeight: 300)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .shadow(color: Theme.cardShadow(), radius: 12, x: 0, y: 6)
    }

    private func block(_ title: String, _ body: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
            Text(body).font(.system(size: 15)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
