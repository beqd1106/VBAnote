import SwiftUI
import SwiftData

@main
struct VBAnoteApp: App {
    /// SwiftData コンテナ（ローカル完結）。将来 CloudKit へ拡張する場合はここを差し替える。
    let container: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self,
            AnswerRecord.self,
            ReviewItem.self,
            QuestionMeta.self,
            MockExamResult.self,
            StudyDayLog.self,
            LessonProgress.self,
        ])
        // 通常はディスク永続化。万一ストアを作成できない環境（CIのテスト実行など）では
        // インメモリにフォールバックし、起動クラッシュを防ぐ。
        do {
            container = try ModelContainer(for: schema)
        } catch {
            let inMemory = ModelConfiguration(isStoredInMemoryOnly: true)
            do {
                container = try ModelContainer(for: schema, configurations: inMemory)
            } catch {
                fatalError("SwiftData コンテナの初期化に失敗しました: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(container)
                .tint(Theme.orange)
        }
    }
}
