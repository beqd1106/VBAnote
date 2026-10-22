import SwiftUI

/// 学習する資格を選ぶ画面。初回起動時と、設定・ホームの「資格を切り替える」から開く。
/// 進捗は資格ごとに別々に保存されるので、切り替えても消えない。
struct ExamPickerView: View {
    @EnvironmentObject var catalog: ExamCatalog

    /// 見出しグループ（exams.json の並び順を保つ）
    private var groups: [String] {
        var seen: [String] = []
        for g in ExamCatalog.all.map(\.group) where !seen.contains(g) { seen.append(g) }
        return seen
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    header
                    ForEach(groups, id: \.self) { group in
                        VStack(alignment: .leading, spacing: Theme.Space.m) {
                            Text(group).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.inkSoft)
                            ForEach(ExamCatalog.all.filter { $0.group == group }) { exam in
                                Button { catalog.select(exam) } label: { examCard(exam) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("exam_\(exam.key)")
                            }
                        }
                    }
                    Text("※各試験の範囲・配点は変更されることがあります。最新情報は各試験の公式サイトでご確認ください。本アプリは非公式の学習支援アプリです。")
                        .captionStyle()
                }
                .padding(.horizontal, Theme.Space.xl)
                .padding(.vertical, Theme.Space.xxl)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            if let prev = catalog.previous {
                Button { catalog.cancelPicker() } label: {
                    Label("\(prev.examShortName)にもどる", systemImage: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.blue)
                }
                .padding(.bottom, Theme.Space.m)
            }
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("資格").font(.system(size: 30, weight: .heavy)).foregroundStyle(Theme.navy)
                Text("note").font(.system(size: 30, weight: .regular)).foregroundStyle(Theme.navy.opacity(0.8))
            }
            Capsule().fill(Theme.orange).frame(width: 60, height: 3)
            Text("どの資格を学びますか？").headingStyle().padding(.top, Theme.Space.m)
            Text("あとから設定でいつでも切り替えられます。進捗は資格ごとに保存されます。")
                .captionStyle()
        }
    }

    private func examCard(_ exam: ExamSpec) -> some View {
        let isCurrent = catalog.selected?.key == exam.key
        return Card {
            HStack(alignment: .top, spacing: Theme.Space.m) {
                Image(systemName: exam.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 44, height: 44)
                    .background(Theme.orangeSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    HStack(spacing: Theme.Space.s) {
                        Text(exam.examShortName)
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.navy)
                        if StoreFactory.hasProgress(for: exam.key) {
                            TagChip(text: "学習中", color: Theme.orange)
                        }
                    }
                    Text(exam.blurb).font(.system(size: 13)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("問題\(exam.questionCount)問・レッスン\(exam.lessonCount)・模試\(exam.mockCount)問／\(exam.mockMinutes)分")
                        .captionStyle()
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.top, Theme.Space.m)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(isCurrent ? Theme.orange : .clear, lineWidth: 2)
        )
    }
}
