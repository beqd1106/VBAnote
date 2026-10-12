import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var store: StudyStore
    @AppStorage("aiAssistEnabled") private var aiAssistEnabled = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showResetAlert = false
    @State private var showStaleAlert = false
    @State private var showProgressAlert = false
    /// 「古い問題の記録を削除」で消せる件数（画面を開いたときに数える）
    @State private var staleCount = 0
    @State private var cleanupDone: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: Theme.Space.l) {
                        profileCard
                        planCard
                        aiCard
                        notificationCard
                        nextCertCard
                        legalCard
                        resetCard
                    }
                    .padding(Theme.Space.l)
                }
            }
            .navigationTitle("設定")
            .onAppear { staleCount = store.staleRecordCount() }
        }
    }

    // MARK: - プロフィール

    private var profileCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("プロフィール").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                if let p = store.profile {
                    settingRow("ニックネーム", p.name.isEmpty ? "未設定" : p.name)
                    settingRow("経験レベル", p.experience.title)
                    settingRow("1日の学習時間", "約\(p.dailyStudyMinutes)分")
                    if let date = p.targetExamDate {
                        settingRow("試験予定日", date.formatted(date: .long, time: .omitted))
                    } else {
                        settingRow("試験予定日", "未設定")
                    }
                }
            }
        }
    }

    // MARK: - プラン変更

    private var planCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("学習プラン").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                ForEach(StudyPlanType.allCases) { plan in
                    Button {
                        store.profile?.plan = plan
                        store.objectWillChange.send()
                        try? store.context.save()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                                Text(plan.subtitle).captionStyle()
                            }
                            Spacer()
                            Image(systemName: store.profile?.plan == plan ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(store.profile?.plan == plan ? Theme.orange : Theme.line)
                        }
                    }.buttonStyle(.plain)
                    if plan != StudyPlanType.allCases.last { Divider() }
                }
            }
        }
    }

    // MARK: - AI（将来拡張）

    private var aiCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Toggle(isOn: $aiAssistEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI学習サポート").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                        Text("用語の言い換え・解説の深掘り（準備中）").captionStyle()
                    }
                }.tint(Theme.blue)
                Text("AI機能はバックエンド経由で安全に呼び出し、利用回数・月額上限・キャッシュを設ける設計です。OFFでもアプリは完全に動作します。")
                    .font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var notificationCard: some View {
        Card {
            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("学習リマインド").font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("毎日の学習を通知でお知らせ").captionStyle()
                }
            }.tint(Theme.blue)
        }
    }

    // MARK: - 次の資格

    private var nextCertCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("次のステップ").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                ForEach(ExamInfo.nextCerts, id: \.title) { c in certRow(c.title, c.subtitle, true) }
                Text("合格後はこれらの資格アプリ（◯◯noteシリーズ）へ拡張予定です。")
                    .font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private func certRow(_ title: String, _ subtitle: String, _ comingSoon: Bool) -> some View {
        HStack {
            Image(systemName: "lock.fill").foregroundStyle(Theme.inkSoft).font(.system(size: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
                Text(subtitle).captionStyle()
            }
            Spacer()
            if comingSoon { TagChip(text: "準備中", color: Theme.inkSoft) }
        }
    }

    // MARK: - 法的・免責

    private var legalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("ご利用にあたって").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                bullet("本アプリの問題・解説はすべてオリジナルです。公式問題・市販教材の転載はありません。")
                bullet("試験範囲・配点・受験要件は変更されることがあります。最新情報は必ず\(ExamInfo.officialSite)でご確認ください。")
                bullet("合格可能性スコアは学習の目安であり、合否を保証・予測するものではありません。")
                bullet(ExamInfo.organizerNotice)
            }
        }
    }

    /// リセットは影響範囲の小さい順に3段階。やり直したい範囲だけを選べるようにする。
    private var resetCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("学習データの整理").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)

                if let done = cleanupDone {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green)
                            .font(.system(size: 13))
                        Text(done).font(.system(size: 13)).foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(Theme.Space.s)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.green.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // ① 入れ替え前の問題を参照している記録だけを消す（有効な進捗は残る）
                if staleCount > 0 {
                    resetRow(title: "古い問題の記録を削除",
                             detail: "アプリの更新で入れ替わる前の問題に対する記録が \(staleCount)件 残っています。"
                                   + "いま出題される問題の成績には影響しません。",
                             tint: Theme.blue) { showStaleAlert = true }
                }

                // ② 履歴を全部消す。プロフィールと学習プランは残すので診断はやり直さない
                resetRow(title: "学習の記録をリセット",
                         detail: "解答履歴・復習予定・模試の結果・カレンダーを消します。"
                               + "プロフィールと学習プラン、ブックマークとメモは残ります。",
                         tint: Theme.orange) { showProgressAlert = true }

                // ③ 完全初期化
                resetRow(title: "すべて初期化",
                         detail: "プロフィール・進捗・履歴がすべて消え、初回診断からやり直します。",
                         tint: Theme.red) { showResetAlert = true }
            }
        }
        .alert("古い問題の記録を削除しますか？", isPresented: $showStaleAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("削除する", role: .destructive) {
                let n = store.deleteStaleRecords()
                staleCount = store.staleRecordCount()
                cleanupDone = "古い問題の記録を\(n)件削除しました。"
            }
        } message: {
            Text("いま出題される問題に対する成績・復習予定は残ります。")
        }
        .alert("学習の記録をリセットしますか？", isPresented: $showProgressAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("リセットする", role: .destructive) {
                store.resetProgressKeepingProfile()
                staleCount = store.staleRecordCount()
                cleanupDone = "学習の記録をリセットしました。プロフィールと学習プランはそのままです。"
            }
        } message: {
            Text("解答履歴・復習予定・模試の結果・カレンダーが消えます。これは取り消せません。")
        }
        .alert("すべて初期化しますか？", isPresented: $showResetAlert) {
            Button("キャンセル", role: .cancel) {}
            Button("初期化する", role: .destructive) { resetAll() }
        } message: {
            Text("プロフィール・進捗・履歴がすべて削除され、初回診断からやり直します。")
        }
    }

    private func resetRow(title: String, detail: String, tint: Color,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: Theme.Space.s) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 14, weight: .bold)).foregroundStyle(tint)
                    Text(detail).font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(tint.opacity(0.6))
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(Theme.Space.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.button))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 部品

    private func settingRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.ink)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("・").foregroundStyle(Theme.inkSoft)
            Text(text).font(.system(size: 12)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resetAll() {
        // 全モデルを削除して初回診断へ戻す（LessonProgress も含めてストア側でまとめて処理）
        store.resetAll()
    }
}
