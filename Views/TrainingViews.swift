import SwiftUI
import SafariServices

/// 操作トレーニング（Dify・WinActor）。本物の画面と同じ手順で組み立てて自動採点する練習画面は Web 版で作っているので、
/// アプリ内ブラウザでその画面を開く。他社の画像・ロゴは使っていない練習用の画面。
enum Training {
    /// 操作トレーニングがある資格と、ツール名
    static let tools: [String: String] = ["dify": "Dify", "wia": "WinActor"]
    static var isAvailable: Bool { tools[ExamContext.current.key] != nil }

    static func url(examKey: String) -> URL? {
        URL(string: "https://beqd1106.com/shikakunote/app/#/train?exam=\(examKey)")
    }
}

/// ホームの入口カード
struct TrainingEntryCard: View {
    @State private var showing = false

    var body: some View {
        if let tool = Training.tools[ExamContext.current.key], let url = Training.url(examKey: ExamContext.current.key) {
            Button { showing = true } label: {
                HStack(spacing: Theme.Space.m) {
                    Image(systemName: "hand.tap.fill").font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.orange)
                        .frame(width: 44, height: 44).background(Theme.orangeSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("操作トレーニング").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                        Text("\(tool)の画面と同じ手順で作って、自動で採点").captionStyle()
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft)
                }
                .padding(Theme.Space.l)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .stroke(Theme.orange.opacity(0.6), lineWidth: 1.5))
                .shadow(color: Theme.cardShadow(), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(.pressable)
            .accessibilityHint("練習用の画面をアプリ内で開きます")
            .fullScreenCover(isPresented: $showing) {
                SafariView(url: url).ignoresSafeArea()
            }
        }
    }
}

/// アプリ内ブラウザ（閉じるボタン付き）
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
