import SwiftUI

/// ホーム最上部の「次の一手」。開いて1秒で学習に入れるよう、いまやるべきことを1つだけ出す。
/// 優先順：復習期限の問題 → 続きのレッスン → 今日の10問。
struct NextAction: Equatable {
    enum Kind { case resume, review, lesson, mixed }
    let kind: Kind
    let eyebrow: String
    let title: String
    let detail: String
    let buttonTitle: String
    let route: HomeRoute

    @MainActor
    static func make(store: StudyStore, session: QuizSession? = nil) -> NextAction {
        if let session {
            return NextAction(kind: .resume, eyebrow: "途中から再開",
                              title: session.title,
                              detail: "残り\(session.remaining)問・\(session.questionIds.count)問中",
                              buttonTitle: "続きから解く", route: .resumeSession)
        }
        let due = store.dueReviewCount
        if due > 0 {
            let n = min(due, 5)
            return NextAction(kind: .review, eyebrow: "まずはここから",
                              title: "間違えた問題を \(n)問 解き直す",
                              detail: due > n ? "復習待ち \(due)問のうち\(n)問・約\(minutes(n))分" : "約\(minutes(n))分",
                              buttonTitle: "復習をはじめる", route: .reviewQuick(n))
        }
        if let lesson = store.nextUnfinishedLesson() {
            return NextAction(kind: .lesson, eyebrow: "続きから",
                              title: lesson.title,
                              detail: "\(lesson.domain.shortTitle)・約\(lesson.estimatedMinutes)分",
                              buttonTitle: "レッスンを開く", route: .lesson(lesson.id))
        }
        return NextAction(kind: .mixed, eyebrow: "今日の演習",
                          title: "全分野から10問",
                          detail: "約\(minutes(10))分",
                          buttonTitle: "問題を解く", route: .quizMixed)
    }

    /// 1問あたり約40秒で見積もる
    private static func minutes(_ n: Int) -> Int { max(1, Int((Double(n) * 40 / 60).rounded(.up))) }

    var icon: String {
        switch kind {
        case .resume: return "play.fill"
        case .review: return "arrow.clockwise"
        case .lesson: return "text.book.closed.fill"
        case .mixed: return "checklist"
        }
    }
}

struct NextActionCard: View {
    let action: NextAction

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: action.icon)
                    .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.orange)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(action.eyebrow).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.orange)
                    Text(action.title).font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    Text(action.detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.72))
                }
                Spacer(minLength: 0)
            }
            // カード全体が押せるが、主役のボタン形も見せて「押せる」と一目で分かるようにする
            HStack(spacing: Theme.Space.s) {
                Text(action.buttonTitle).font(.system(size: 16, weight: .bold))
                Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Theme.orange)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button, style: .continuous))
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.navy)
        )
        .shadow(color: Theme.navy.opacity(0.18), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.eyebrow)。\(action.title)。\(action.detail)")
        .accessibilityHint(action.buttonTitle)
        .accessibilityAddTraits(.isButton)
    }
}
