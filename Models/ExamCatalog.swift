import SwiftUI

/// 1本のアプリで複数の資格を学べるようにするための資格カタログ。
/// 中身は Resources/exams.json（note_factory/gen_multi.py が configs.py から生成。手で編集しない）。
struct ExamSpec: Codable, Identifiable, Hashable {
    struct DomainSpec: Codable, Hashable {
        let id: String
        let title: String
        let shortTitle: String
        let weight: Double
        let color: String
        let icon: String
    }
    struct NextCertSpec: Codable, Hashable {
        let title: String
        let subtitle: String
        /// このアプリに収録している資格ならそのキー（タップで切り替える）
        let examKey: String?
    }
    struct WeekSpec: Codable, Hashable {
        let week: Int
        let title: String
        let detail: String
        let domains: [String]
    }

    let key: String
    let brandPrefix: String
    let examShortName: String
    let examFullName: String
    /// 資格選択画面の見出しグループ（例：IT・クラウド）
    let group: String
    /// 資格選択画面の一言説明
    let blurb: String
    /// 資格選択画面のSF Symbol
    let icon: String
    let officialSite: String
    let organizerNotice: String
    let mockCount: Int
    let mockMinutes: Int
    let passScore: Int
    let mockNote: String
    let servicesTitle: String
    let servicesSubtitle: String
    let servicesSearchPlaceholder: String
    let nextCerts: [NextCertSpec]
    let finalChecklist: [String]
    let keyTermIds: [String]
    let domains: [DomainSpec]
    let roadmap: [WeekSpec]
    let questionCount: Int
    let lessonCount: Int

    var id: String { key }
}

/// 資格カタログと「いま学習中の資格」を管理する。
/// 学習中の資格は UserDefaults に保存し、進捗データは資格ごとに別のストアへ分ける。
@MainActor
final class ExamCatalog: ObservableObject {
    static let shared = ExamCatalog()

    /// 収録している全資格（選択画面の並び順）
    static var all: [ExamSpec] { ExamContext.all }

    private static let selectedKey = "selectedExamKey"

    /// いま学習中の資格（未選択なら nil＝資格選択画面を出す）
    @Published private(set) var selected: ExamSpec?
    /// 切替画面を開く直前に学習していた資格（「もどる」で戻れるようにする）
    @Published private(set) var previous: ExamSpec?

    private init() {
        let saved = UserDefaults.standard.string(forKey: Self.selectedKey)
        let spec = Self.all.first { $0.key == saved }
        selected = spec
        if let spec { ExamContext.activate(spec) }
    }

    /// 資格を選ぶ（または切り替える）。コンテンツを読み直してから画面へ反映する。
    func select(_ spec: ExamSpec) {
        UserDefaults.standard.set(spec.key, forKey: Self.selectedKey)
        ExamContext.activate(spec)
        previous = nil
        selected = spec
    }

    /// 資格選択画面へ戻る（進捗は資格ごとに残る）
    func showPicker() {
        previous = selected
        selected = nil
    }

    /// 切替画面を閉じて、もとの資格に戻る
    func cancelPicker() {
        guard let previous else { return }
        selected = previous
        self.previous = nil
    }
}

/// 現在の資格。ExamInfo / ExamDomain / ContentRepository はここを参照する。
/// 資格選択前に参照された場合（テストなど）は先頭の資格を使う。
enum ExamContext {
    static let all: [ExamSpec] = {
        guard let url = Bundle.main.url(forResource: "exams", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([ExamSpec].self, from: data),
              !list.isEmpty else {
            fatalError("exams.json が見つからないか読み込めません。note_factory/gen_multi.py で生成してください。")
        }
        return list
    }()

    private(set) static var current: ExamSpec = all[0]

    static func activate(_ spec: ExamSpec) {
        current = spec
        ContentRepository.reload()
    }
}
