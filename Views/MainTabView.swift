import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var store: StudyStore

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house.fill") }

            LibraryView()
                .tabItem { Label("学ぶ", systemImage: "book.fill") }

            PracticeHubView()
                .tabItem { Label("演習", systemImage: "checklist") }

            AnalysisView()
                .tabItem { Label("分析", systemImage: "chart.bar.fill") }

            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape.fill") }
        }
    }
}
