import SwiftUI
import UIKit

/// 学習カレンダー。日ごとのがんばり度を色の濃さで見せ、画像とCSVで書き出せる。
struct StudyCalendarView: View {
    @EnvironmentObject var store: StudyStore
    @State private var monthOffset = 0
    @State private var selectedDay: Date?
    @State private var shareItems: ShareItems?
    @State private var exportError: String?

    private let cal = Calendar.current

    var body: some View {
        let records = store.dailyRecords()
        let month = displayedMonth
        let monthRecords = records.values.filter { cal.isDate($0.day, equalTo: month, toGranularity: .month) }
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: Theme.Space.l) {
                    streakCard
                    Card {
                        VStack(spacing: Theme.Space.m) {
                            monthHeader(month)
                            CalendarGrid(month: month, records: records, selectedDay: $selectedDay)
                            LevelLegend()
                        }
                    }
                    MonthSummaryCard(records: monthRecords)
                    if let day = selectedDay {
                        dayDetailCard(records[day] ?? DailyStudyRecord(day: day))
                    }
                    exportCard(month: month, records: records, monthRecords: monthRecords)
                }
                .padding(Theme.Space.l)
            }
        }
        .navigationTitle("学習カレンダー")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItems) { items in
            ActivityView(items: items.items)
        }
        .alert("書き出せませんでした", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    // MARK: - 連続学習

    private var streakCard: some View {
        Card {
            HStack(spacing: Theme.Space.l) {
                stat(icon: "flame.fill", color: Theme.orange, value: "\(store.studyStreak())日", caption: "連続学習")
                Divider().frame(height: 56)
                stat(icon: "calendar", color: Theme.blue, value: "\(store.studyDays().count)日", caption: "累計学習日")
            }
        }
    }

    private func stat(icon: String, color: Color, value: String, caption: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(color)
            Text(value).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.navy)
            Text(caption).captionStyle()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 月の切り替え

    private func monthHeader(_ month: Date) -> some View {
        HStack {
            Button {
                monthOffset -= 1; selectedDay = nil
            } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("前の月")
            Spacer()
            Text(CalendarFormat.monthTitle(month)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
            Spacer()
            Button {
                monthOffset += 1; selectedDay = nil
            } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .disabled(monthOffset >= 0)
            .accessibilityLabel("次の月")
        }
        .foregroundStyle(Theme.blue)
    }

    // MARK: - 選んだ日の内訳

    private func dayDetailCard(_ r: DailyStudyRecord) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack {
                    Text(CalendarFormat.dayTitle(r.day)).font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                    Spacer()
                    LevelBadge(level: r.level)
                }
                if r.questions == 0 && r.lessonsCompleted == 0 {
                    Text("この日の学習記録はありません。").font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
                } else {
                    detailRow("解いた問題", "\(r.questions)問")
                    if let rate = r.correctRate {
                        detailRow("正解", "\(r.correct)問（\(Int((rate * 100).rounded()))%）")
                    }
                    if r.mockQuestions > 0 { detailRow("うち模擬試験", "\(r.mockQuestions)問") }
                    if r.lessonsCompleted > 0 { detailRow("履修したレッスン", "\(r.lessonsCompleted)件") }
                    if r.questions > 0 { detailRow("学習時間の目安", "約\(r.estimatedMinutes)分") }
                }
            }
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 14)).foregroundStyle(Theme.inkSoft)
            Spacer()
            Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(Theme.ink)
        }
    }

    // MARK: - 書き出し

    private func exportCard(month: Date, records: [Date: DailyStudyRecord], monthRecords: [DailyStudyRecord]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up").foregroundStyle(Theme.blue)
                    Text("記録を書き出す").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                }
                Text("画像は表示中の月のカレンダー、CSVはこれまでの全期間の日別記録です。共有メニューから写真への保存やファイルへの保存ができます。")
                    .font(.system(size: 13)).foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Theme.Space.s) {
                    PrimaryButton(title: "画像", icon: "photo") {
                        exportImage(month: month, records: records, monthRecords: monthRecords)
                    }
                    SecondaryButton(title: "CSV", icon: "tablecells") {
                        exportCSV(records: records)
                    }
                }
            }
        }
    }

    @MainActor
    private func exportImage(month: Date, records: [Date: DailyStudyRecord], monthRecords: [DailyStudyRecord]) {
        let card = CalendarShareImage(month: month, records: records, monthRecords: monthRecords,
                                      streak: store.studyStreak())
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        guard let image = renderer.uiImage else {
            exportError = "画像を作れませんでした。もう一度お試しください。"
            return
        }
        shareItems = ShareItems(items: [image])
    }

    private func exportCSV(records: [Date: DailyStudyRecord]) {
        guard !records.isEmpty else {
            exportError = "まだ学習記録がありません。問題を解くと記録されます。"
            return
        }
        do {
            let url = try StudyRecordCSV.write(records: records)
            shareItems = ShareItems(items: [url])
        } catch {
            exportError = "CSVファイルを保存できませんでした（\(error.localizedDescription)）。"
        }
    }

    private var displayedMonth: Date {
        cal.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
    }
}

// MARK: - カレンダー本体（画面と書き出し画像で共用）

private struct CalendarGrid: View {
    let month: Date
    let records: [Date: DailyStudyRecord]
    /// nil なら選択できない（書き出し画像用）
    var selectedDay: Binding<Date?>? = nil

    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array(["日","月","火","水","木","金","土"].enumerated()), id: \.offset) { i, w in
                    Text(w).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(i == 0 ? Theme.orange : i == 6 ? Theme.blue : Theme.inkSoft)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(Array(CalendarFormat.monthGrid(for: month).enumerated()), id: \.offset) { _, week in
                HStack(spacing: 6) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, date in
                        if let date {
                            cell(date)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private func cell(_ date: Date) -> some View {
        let day = cal.startOfDay(for: date)
        let level = records[day]?.level ?? 0
        let isFuture = day > cal.startOfDay(for: .now)
        let isSelected = selectedDay?.wrappedValue == day
        let content = Text("\(cal.component(.day, from: date))")
            .font(.system(size: 13, weight: level >= 3 ? .bold : .medium))
            .foregroundStyle(level >= 3 ? .white : isFuture ? Theme.inkSoft.opacity(0.5) : Theme.ink)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(LevelColor.fill(level)))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Theme.navy : cal.isDateInToday(date) ? Theme.blue : .clear,
                            lineWidth: isSelected ? 2 : 1.5)
            )
        if let selectedDay, !isFuture {
            Button {
                selectedDay.wrappedValue = isSelected ? nil : day
            } label: { content }
            .buttonStyle(.plain)
            .accessibilityLabel("\(CalendarFormat.dayTitle(day))、がんばり度\(DailyStudyRecord.levelLabel(level))")
        } else {
            content
        }
    }
}

/// がんばり度の色。0は無色、1〜4でオレンジを濃くする
private enum LevelColor {
    static func fill(_ level: Int) -> Color {
        switch level {
        case 0: return Theme.line.opacity(0.45)
        case 1: return Theme.orange.opacity(0.22)
        case 2: return Theme.orange.opacity(0.45)
        case 3: return Theme.orange.opacity(0.75)
        default: return Theme.orange
        }
    }
}

private struct LevelLegend: View {
    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            Text("少ない").font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
            ForEach(0..<5) { level in
                RoundedRectangle(cornerRadius: 3).fill(LevelColor.fill(level)).frame(width: 14, height: 14)
            }
            Text("多い").font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("色が濃い日ほど多く学習しています")
    }
}

private struct LevelBadge: View {
    let level: Int
    var body: some View {
        Text(DailyStudyRecord.levelLabel(level).components(separatedBy: "（").first ?? "")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(level >= 3 ? .white : Theme.orange)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(level == 0 ? Theme.line.opacity(0.6) : LevelColor.fill(max(level, 2))))
    }
}

// MARK: - 月のまとめ

private struct MonthSummaryCard: View {
    let records: [DailyStudyRecord]

    var body: some View {
        let studied = records.filter { $0.level > 0 }
        let questions = records.reduce(0) { $0 + $1.questions }
        let correct = records.reduce(0) { $0 + $1.correct }
        let minutes = records.reduce(0) { $0 + $1.estimatedMinutes }
        Card {
            VStack(alignment: .leading, spacing: Theme.Space.m) {
                Text("この月のまとめ").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.navy)
                HStack(spacing: 0) {
                    item("\(studied.count)日", "学習した日")
                    item("\(questions)問", "解いた問題")
                    item(questions == 0 ? "—" : "\(Int((Double(correct) / Double(questions) * 100).rounded()))%", "正解率")
                    item("約\(minutes)分", "学習時間")
                }
            }
        }
    }

    private func item(_ value: String, _ caption: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(caption).font(.system(size: 11)).foregroundStyle(Theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 書き出し画像

/// 共有用の画像（幅390pt固定で3倍に書き出す）
private struct CalendarShareImage: View {
    let month: Date
    let records: [Date: DailyStudyRecord]
    let monthRecords: [DailyStudyRecord]
    let streak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.l) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AppInfo.displayName).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.orange)
                    Text("\(CalendarFormat.monthTitle(month))の学習記録")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(Theme.navy)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.orange)
                    Text("\(streak)日連続").font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.ink)
                }
            }
            CalendarGrid(month: month, records: records)
            LevelLegend()
            MonthSummaryCard(records: monthRecords)
        }
        .padding(Theme.Space.xl)
        .frame(width: 390)
        .background(Theme.bg)
    }
}

// MARK: - CSV

enum StudyRecordCSV {
    /// 最初の学習日から今日までを1日1行で書き出す（学習しなかった日も0で入れる）。
    /// Excelで文字化けしないようUTF-8のBOMを付ける。
    static func write(records: [Date: DailyStudyRecord]) throws -> URL {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let first = records.keys.min() ?? today
        var lines = ["日付,曜日,解いた問題数,正解数,正解率(%),うち模擬試験,履修したレッスン数,学習時間の目安(分),がんばり度(0-4)"]
        var day = first
        while day <= today {
            let r = records[day] ?? DailyStudyRecord(day: day)
            let rate = r.correctRate.map { String(Int(($0 * 100).rounded())) } ?? ""
            lines.append([CalendarFormat.csvDate(day), CalendarFormat.weekday(day),
                          "\(r.questions)", "\(r.correct)", rate, "\(r.mockQuestions)",
                          "\(r.lessonsCompleted)", "\(r.estimatedMinutes)", "\(r.level)"].joined(separator: ","))
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        let text = "\u{FEFF}" + lines.joined(separator: "\r\n") + "\r\n"
        let name = "\(AppInfo.displayName)_学習記録_\(CalendarFormat.fileDate(today)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try text.data(using: .utf8)!.write(to: url, options: .atomic)
        return url
    }
}

// MARK: - 共有シート

private struct ShareItems: Identifiable {
    let id = UUID()
    let items: [Any]
}

private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - 表記

private enum AppInfo {
    static var displayName: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "note"
    }
}

enum CalendarFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = format
        return f
    }
    private static let month = formatter("yyyy年 M月")
    private static let day = formatter("M月d日（E）")
    private static let csv = formatter("yyyy/MM/dd")
    private static let file = formatter("yyyyMMdd")
    private static let week = formatter("E")

    static func monthTitle(_ d: Date) -> String { month.string(from: d) }
    static func dayTitle(_ d: Date) -> String { day.string(from: d) }
    static func csvDate(_ d: Date) -> String { csv.string(from: d) }
    static func fileDate(_ d: Date) -> String { file.string(from: d) }
    static func weekday(_ d: Date) -> String { week.string(from: d) }

    /// 月の日付を週ごとの配列に（前後の空白はnil）
    static func monthGrid(for date: Date) -> [[Date?]] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: date),
              let firstWeekday = cal.dateComponents([.weekday], from: interval.start).weekday else { return [] }
        let daysInMonth = cal.range(of: .day, in: .month, for: date)?.count ?? 30
        var cells: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        for d in 0..<daysInMonth {
            cells.append(cal.date(byAdding: .day, value: d, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0+7]) }
    }
}
