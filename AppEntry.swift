// AppEntry.swift — App 入口 + SwiftData 容器
import SwiftUI
import SwiftData

@main
struct 随手记App: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                ExpenseRecord.self,
                CategoryBudget.self,
                SavingsRecord.self
            )
            // 初始化默认额度
            let ctx = container.mainContext
            let existing = try ctx.fetch(FetchDescriptor<CategoryBudget>())
            if existing.isEmpty {
                let defaults: [(ExpenseCategory, Double)] = [
                    (.housing, 3000),
                    (.social,  1000),
                    (.food,    1500),
                    (.other,   800),
                    (.smoking, 300)
                ]
                defaults.forEach { ctx.insert(CategoryBudget(category: $0.0, monthlyBudget: $0.1)) }
                try ctx.save()
            }
        } catch {
            fatalError("SwiftData 初始化失败: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            LockScreenView()
                .modelContainer(container)
        }
    }
}
