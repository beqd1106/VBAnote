import Foundation
import UserNotifications

/// 毎日の学習リマインド（端末内の通知だけ。サーバーは使わない）。
///
/// - 繰り返し通知1本ではなく「この先7日分を1日1本ずつ」予約する。
///   こうすると、その日すでに学習していれば当日の分だけ取り消せる（学習済みの日は鳴らさない）。
/// - アプリを開くたび・設定を変えるたびに予約し直すので、7日以上開かなくても最後の予約までは届く。
enum StudyReminder {
    static let enabledKey = "reminder.enabled"
    static let hourKey = "reminder.hour"
    static let minuteKey = "reminder.minute"
    /// 全資格共通の「最後に学習した日」（yyyy-MM-dd）。資格ごとのストアをまたいで判定するために使う
    static let lastStudyDayKey = "reminder.lastStudyDay"
    static let idPrefix = "study.reminder."
    static let daysAhead = 7

    // MARK: - 純粋関数（テスト対象）

    /// 予約する日時の一覧。今日は「まだ学習していない」かつ「時刻が来ていない」ときだけ含める。
    static func fireDates(now: Date, hour: Int, minute: Int, studiedToday: Bool,
                          days: Int = daysAhead, calendar cal: Calendar = .current) -> [Date] {
        let start = cal.startOfDay(for: now)
        return (0..<days).compactMap { offset -> Date? in
            guard let day = cal.date(byAdding: .day, value: offset, to: start),
                  let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return nil }
            if offset == 0 && (studiedToday || fire <= now) { return nil }
            return fire
        }
    }

    /// 通知の文面。毎日同じだと見なくなるので、日付で少しずつ変える（ただし煽らない）
    static func message(for date: Date, calendar cal: Calendar = .current) -> (title: String, body: String) {
        let bodies = [
            "今日の5問、約3分で終わります。",
            "1問だけでも大丈夫。続けることがいちばんの近道です。",
            "前に間違えた問題が復習を待っています。",
            "通勤や休憩のあいだに、聞き流しもどうぞ。",
            "昨日の自分より、5問ぶん前へ。",
        ]
        let i = (cal.ordinality(of: .day, in: .era, for: date) ?? 0) % bodies.count
        return ("資格note", bodies[i])
    }

    static func identifier(for date: Date, calendar cal: Calendar = .current) -> String {
        idPrefix + dayString(date, calendar: cal)
    }

    static func dayString(_ date: Date, calendar cal: Calendar = .current) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - 設定値

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var hour: Int { UserDefaults.standard.object(forKey: hourKey) as? Int ?? 20 }
    static var minute: Int { UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 0 }
    static var studiedToday: Bool {
        UserDefaults.standard.string(forKey: lastStudyDayKey) == dayString(.now)
    }

    // MARK: - 端末の通知とのやりとり

    /// 学習したときに呼ぶ。今日の通知を取り消し、「今日は学習済み」を記録する。
    static func markStudiedToday() {
        let today = dayString(.now)
        guard UserDefaults.standard.string(forKey: lastStudyDayKey) != today else { return }
        UserDefaults.standard.set(today, forKey: lastStudyDayKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: .now)])
    }

    /// 通知の許可を求める。許可されたら true
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 予約をすべて作り直す（オフなら消すだけ）
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        for date in fireDates(now: .now, hour: hour, minute: minute, studiedToday: studiedToday) {
            let m = message(for: date)
            let content = UNMutableNotificationContent()
            content.title = m.title
            content.body = m.body
            content.sound = .default
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            let request = UNNotificationRequest(identifier: identifier(for: date), content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            try? await center.add(request)
        }
    }
}
