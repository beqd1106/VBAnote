import SwiftUI
import SwiftData

/// 起動直後のルート。StudyStore を生成し、オンボーディング完了状態で分岐する。
struct RootView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var store: StudyStoreHolder = .init()

    var body: some View {
        Group {
            if let studyStore = store.store {
                // StudyStore を直接監視する子Viewで分岐する。
                // （RootView はホルダしか監視しないため、ここで @ObservedObject を張らないと
                //   プロフィール作成後にオンボーディング→ホームへ切り替わらない）
                RootRouterView(store: studyStore)
            } else {
                // コンテキスト注入前の一瞬
                AppBackground()
            }
        }
        .onAppear { store.configure(context: context) }
    }
}

/// StudyStore を監視し、オンボーディング完了状態で画面を切り替えるルーター。
private struct RootRouterView: View {
    @ObservedObject var store: StudyStore
    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingFlowView()
            }
        }
        .environmentObject(store)
    }
}

/// @StateObject で ModelContext を受け取るための薄いホルダ。
/// （StudyStore 自体は init に context が必要なため、onAppear で遅延生成する）
@MainActor
final class StudyStoreHolder: ObservableObject {
    @Published var store: StudyStore?
    func configure(context: ModelContext) {
        if store == nil { store = StudyStore(context: context) }
    }
}
