import SwiftUI

/// ホームから資格をすばやく切り替える半分シート。
/// 学習中の資格を上に、まだ始めていない資格を下に並べる。今の資格にはチェックを付ける。
struct ExamSwitcherSheet: View {
    @EnvironmentObject var catalog: ExamCatalog
    @Environment(\.dismiss) private var dismiss

    private var current: String? { catalog.selected?.key }
    private var studying: [ExamSpec] { ExamCatalog.all.filter { StoreFactory.hasProgress(for: $0.key) || $0.key == current } }
    private var others: [ExamSpec] { ExamCatalog.all.filter { !(StoreFactory.hasProgress(for: $0.key) || $0.key == current) } }

    var body: some View {
        NavigationStack {
            List {
                Section("学習中") {
                    ForEach(studying, id: \.key) { row($0) }
                }
                if !others.isEmpty {
                    Section("ほかの資格") {
                        ForEach(others, id: \.key) { row($0) }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .navigationTitle("資格を切り替える")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func row(_ exam: ExamSpec) -> some View {
        let isCurrent = exam.key == current
        return Button {
            guard !isCurrent else { dismiss(); return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            dismiss()
            // シートが閉じてから切り替える（画面ツリーを作り直すため）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { catalog.select(exam) }
        } label: {
            HStack(spacing: Theme.Space.m) {
                Image(systemName: exam.icon)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.navy)
                    .frame(width: 38, height: 38)
                    .background(Theme.orangeSoft)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.chip))
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.examShortName).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.ink)
                    Text("問題\(exam.questionCount)問・レッスン\(exam.lessonCount)").captionStyle()
                }
                Spacer()
                if isCurrent {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green).font(.system(size: 20))
                        .accessibilityLabel("学習中の資格")
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.inkSoft).font(.system(size: 13, weight: .semibold))
                }
            }
            .contentShape(Rectangle())
            .frame(minHeight: 48)
        }
        .buttonStyle(.plain)
        .listRowBackground(Theme.card)
    }
}
