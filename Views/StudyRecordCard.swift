import SwiftUI

/// ホームの「学習の記録」カード。全資格を合算した連続日数・直近7日・今日の目標を一目で見せる。
/// カード全体がカレンダーへの入口（右上の「カレンダー」とシェブロン、押した時の沈み込みが取っ手）。
struct StudyRecordCard: View {
    let activity: AllExamsActivity
    /// 1日の目標（分）。オンボーディングで決めた値
    let goalMinutes: Int

    private let cal = Calendar.current

    var body: some View {
        let week = activity.recentDays(7)
        let today = week.last ?? DailyStudyRecord(day: cal.startOfDay(for: .now))
        let streak = activity.streak
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            header
            HStack(alignment: .center, spacing: Theme.Space.l) {
                streakBlock(streak: streak, studiedToday: today.hasActivity)
                weekStrip(week)
            }
            goalBar(today: today)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .stroke(Theme.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("学習の記録。\(streak)日連続。今日は約\(today.estimatedMinutes)分、目標\(goalMinutes)分")
        .accessibilityHint("学習カレンダーを開きます")
    }

    private var header: some View {
        HStack {
            Label("学習の記録", systemImage: "calendar")
                .font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
            Text("全資格").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.blue)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Capsule().fill(Theme.blueSoft))
            Spacer()
            HStack(spacing: 2) {
                Text("カレンダー").font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.blue)
        }
    }

    private func streakBlock(streak: Int, studiedToday: Bool) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle().fill(streak > 0 ? Theme.orangeSoft : Theme.line.opacity(0.5))
                    .frame(width: 52, height: 52)
                Image(systemName: "flame.fill").font(.system(size: 26))
                    .foregroundStyle(streak > 0 ? Theme.orange : Theme.inkSoft)
            }
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(streak)").font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(Theme.navy)
                Text("日").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.navy)
            }
            Text(studiedToday || streak == 0 ? "連続学習" : "今日で更新")
                .font(.system(size: 11, weight: studiedToday ? .regular : .bold))
                .foregroundStyle(studiedToday || streak == 0 ? Theme.inkSoft : Theme.orange)
        }
        .frame(width: 76)
    }

    private func weekStrip(_ week: [DailyStudyRecord]) -> some View {
        HStack(spacing: 6) {
            ForEach(week) { r in
                let isToday = cal.isDateInToday(r.day)
                VStack(spacing: 5) {
                    Text(CalendarFormat.weekday(r.day))
                        .font(.system(size: 11, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? Theme.navy : Theme.inkSoft)
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(LevelColor.fill(r.level))
                        .frame(height: 30)
                        .overlay {
                            if r.hasActivity {
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy))
                                    .foregroundStyle(r.level >= 3 ? .white : Theme.orange)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(isToday ? Theme.navy : .clear, lineWidth: 1.5)
                        )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func goalBar(today: DailyStudyRecord) -> some View {
        let goal = max(goalMinutes, 1)
        let done = today.estimatedMinutes
        let reached = done >= goal
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("今日の目標").font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                Spacer()
                if reached {
                    Label("達成", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.green)
                } else {
                    Text("約\(done)分 / \(goal)分").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                }
            }
            ProgressBar(value: Double(done) / Double(goal), color: reached ? Theme.green : Theme.orange, height: 8)
        }
    }
}

/// 押せるカードの共通スタイル：押している間だけ少し沈む（取っ手の手触り）
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .shadow(color: Theme.cardShadow(), radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 4)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
