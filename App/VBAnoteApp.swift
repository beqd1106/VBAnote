import SwiftUI
import SwiftData

@main
struct VBAnoteApp: App {
    @StateObject private var catalog = ExamCatalog.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if let exam = catalog.selected {
                    // 資格ごとに別のストア・別の画面ツリーにする（.id で切替時に作り直す）
                    RootView()
                        .modelContainer(StoreFactory.container(for: exam.key))
                        .id(exam.key)
                } else {
                    ExamPickerView()
                }
            }
            .environmentObject(catalog)
            .tint(Theme.orange)
        }
    }
}

/// 資格ごとの SwiftData コンテナ（ローカル完結）。進捗が資格をまたいで混ざらないようファイルを分ける。
/// 将来 CloudKit へ拡張する場合はここを差し替える。
@MainActor
enum StoreFactory {
    private static var cache: [String: ModelContainer] = [:]

    private static func storeURL(for examKey: String) -> URL {
        URL.applicationSupportDirectory.appending(path: "\(examKey).store")
    }

    /// その資格をすでに学び始めているか（資格選択画面の「学習中」表示用）
    static func hasProgress(for examKey: String) -> Bool {
        FileManager.default.fileExists(atPath: storeURL(for: examKey).path)
    }

    static func container(for examKey: String) -> ModelContainer {
        if let c = cache[examKey] { return c }
        let schema = Schema([
            UserProfile.self,
            AnswerRecord.self,
            ReviewItem.self,
            QuestionMeta.self,
            MockExamResult.self,
            StudyDayLog.self,
            LessonProgress.self,
        ])
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = storeURL(for: examKey)
        let container: ModelContainer
        // 通常はディスク永続化。万一ストアを作成できない環境（CIのテスト実行など）では
        // インメモリにフォールバックし、起動クラッシュを防ぐ。
        do {
            container = try ModelContainer(for: schema, configurations: ModelConfiguration(url: url))
        } catch {
            let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: inMemory)
            } catch {
                fatalError("SwiftData コンテナの初期化に失敗しました: \(error)")
            }
        }
        cache[examKey] = container
        return container
    }
}
