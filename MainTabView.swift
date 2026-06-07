// MainTabView.swift — 底部6个Tab导航
import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(Array(ExpenseCategory.allCases.enumerated()), id: \.offset) { index, cat in
                CategoryView(category: cat)
                    .tabItem {
                        Label(cat.displayName, systemImage: cat.tabIcon)
                    }
                    .tag(index)
            }
            StatisticsView()
                .tabItem {
                    Label("统计", systemImage: "chart.bar.fill")
                }
                .tag(5)
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(6)
        }
        .tint(.accentColor)
    }
}
