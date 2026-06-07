// Widget.swift — 2x2 桌面小组件
import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Entry
struct BudgetEntry: TimelineEntry {
    let date: Date
    let totalRemaining: Double
    let totalSavings: Double
    let isOverBudget: Bool
}

// MARK: - Provider
struct BudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry {
        BudgetEntry(date: Date(), totalRemaining: 1280.50, totalSavings: 3600.00, isOverBudget: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let entry = loadEntry()
        // 每30分钟刷新一次
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadEntry() -> BudgetEntry {
        // 从 UserDefaults App Group 读取（需要配置 App Group）
        let defaults = UserDefaults(suiteName: "group.com.yourapp.随手记") ?? .standard
        let remaining = defaults.double(forKey: "widget_remaining")
        let savings   = defaults.double(forKey: "widget_savings")
        return BudgetEntry(
            date: Date(),
            totalRemaining: remaining,
            totalSavings: savings,
            isOverBudget: remaining < 0
        )
    }
}

// MARK: - Widget 视图
struct BudgetWidgetView: View {
    var entry: BudgetEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                colors: entry.isOverBudget
                    ? [Color(hex: "FF416C"), Color(hex: "FF4B2B")]
                    : [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                // 标题行
                HStack {
                    Text("💰 随手记")
                        .font(.caption2.bold())
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                    Image(systemName: entry.isOverBudget ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(entry.isOverBudget ? .yellow : .green)
                }

                Spacer()

                // 本月剩余
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.isOverBudget ? "⚠️ 本月超支" : "本月剩余")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text("¥\(String(format: "%.2f", entry.totalRemaining))")
                        .font(.title3)
                        .fontWeight(entry.isOverBudget ? .bold : .semibold)
                        .foregroundColor(entry.isOverBudget ? .white : .green)
                        .minimumScaleFactor(0.7)
                }

                Divider().background(.white.opacity(0.2))

                // 累计结余
                VStack(alignment: .leading, spacing: 3) {
                    Text("💰 累计金库")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    Text("¥\(String(format: "%.2f", entry.totalSavings))")
                        .font(.subheadline.bold())
                        .foregroundColor(.yellow)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(14)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

// MARK: - Widget 配置
struct BudgetWidget: Widget {
    let kind = "BudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BudgetProvider()) { entry in
            BudgetWidgetView(entry: entry)
        }
        .configurationDisplayName("随手记 - 预算总览")
        .description("实时查看本月剩余额度和累计结余金库")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 在主 App 中同步数据到 Widget
// 在 CategoryView 和 StatisticsView 中调用此函数更新小组件数据
func syncWidgetData(remaining: Double, savings: Double) {
    let defaults = UserDefaults(suiteName: "group.com.yourapp.随手记") ?? .standard
    defaults.set(remaining, forKey: "widget_remaining")
    defaults.set(savings,   forKey: "widget_savings")
    WidgetCenter.shared.reloadAllTimelines()
}
