// StatisticsView.swift — 统计视图（红黑榜 + 累计结余 + 穿透下钻）
import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var allRecords: [ExpenseRecord]
    @Query private var budgets: [CategoryBudget]
    @Query private var savings: [SavingsRecord]

    @State private var showResetConfirm = false
    @State private var showBudgetEdit = false
    @State private var editingBudgetText = ""
    @State private var showSavingsEdit = false
    @State private var editingSavingsText = ""
    @State private var navigationPath = NavigationPath()

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    // 本月汇总
    private var thisMonthRecords: [ExpenseRecord] {
        allRecords.filter { $0.date.isSameMonth(as: Date()) }
    }

    private var totalBudget: Double { budgets.reduce(0) { $0 + $1.monthlyBudget } }
    private var totalSpent: Double  { thisMonthRecords.reduce(0) { $0 + $1.amount } }
    private var totalRemaining: Double { totalBudget - totalSpent }
    private var isOverBudget: Bool { totalRemaining < 0 }

    // 累计结余（只累加正数月份）
    private var totalSavings: Double {
        savings.filter { $0.amount > 0 && $0.isCarriedOver }.reduce(0) { $0 + $1.amount }
    }

    // 跨年判断
    private var hasMultipleYears: Bool {
        let years = Set(allRecords.map { $0.date.year })
        return years.count > 1
    }

    // 历史月份分组 (不含当月)
    private var historicalMonths: [MonthSummary] {
        let past = allRecords.filter { !$0.date.isSameMonth(as: Date()) }
        var dict: [String: [ExpenseRecord]] = [:]
        for r in past {
            let key = "\(r.date.year)-\(String(format: "%02d", r.date.month))"
            dict[key, default: []].append(r)
        }
        return dict.map { key, records in
            let parts = key.split(separator: "-")
            let year = Int(parts[0])!
            let month = Int(parts[1])!
            let spent = records.reduce(0) { $0 + $1.amount }
            let budget = totalBudget
            return MonthSummary(year: year, month: month, spent: spent, budget: budget, records: records)
        }.sorted { a, b in
            a.year != b.year ? a.year > b.year : a.month > b.month
        }
    }

    private var surplusMonths:  [MonthSummary] { historicalMonths.filter { $0.remaining >= 0 } }
    private var deficitMonths:  [MonthSummary] { historicalMonths.filter { $0.remaining < 0 } }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 16) {
                    // 本月总览
                    monthOverviewCard

                    // 累计金库
                    savingsVaultCard

                    // 红黑榜
                    rankingCards

                    // 导出CSV
                    exportButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("📊 统计")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: MonthSummary.self) { summary in
                MonthDetailView(summary: summary)
            }
            .navigationDestination(for: MonthListType.self) { type in
                MonthListView(
                    months: type == .surplus ? surplusMonths : deficitMonths,
                    title: type == .surplus ? "🟢 总计结余" : "🔴 总计超支",
                    isSurplus: type == .surplus
                )
            }
        }
        .confirmationDialog("确认重置", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("重置当月全类目数据", role: .destructive) {
                resetCurrentMonth()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作将清空本月所有消费记录，不可恢复。")
        }
    }

    // MARK: - 本月总览卡片
    private var monthOverviewCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("本月总览")
                    .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("重置当月", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 20) {
                statItem(
                    title: "总额度",
                    value: "¥\(String(format: "%.0f", totalBudget))",
                    color: .blue
                )
                Divider().frame(height: 40)
                statItem(
                    title: "已花费",
                    value: "¥\(String(format: "%.2f", totalSpent))",
                    color: .orange
                )
                Divider().frame(height: 40)
                VStack(spacing: 4) {
                    Text(isOverBudget ? "⚠️ 超支" : "剩余")
                        .font(.caption)
                        .foregroundColor(isOverBudget ? .red : .secondary)
                    Text("¥\(String(format: "%.2f", totalRemaining))")
                        .font(isOverBudget ? .title3 : .subheadline)
                        .fontWeight(isOverBudget ? .bold : .semibold)
                        .foregroundColor(isOverBudget ? .red : .green)
                }
            }

            // 各分类进度条
            ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                categoryProgressRow(cat)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }

    private func categoryProgressRow(_ cat: ExpenseCategory) -> some View {
        let spent = allRecords.filter { $0.category == cat && $0.date.isSameMonth(as: Date()) }.reduce(0) { $0 + $1.amount }
        let budget = budgets.first { $0.category == cat }?.monthlyBudget ?? 1
        let ratio = min(spent / budget, 1.0)
        let over = spent > budget

        return VStack(spacing: 4) {
            HStack {
                Text("\(cat.icon) \(cat.displayName)")
                    .font(.caption.bold())
                    .foregroundColor(cat.accentColor)
                Spacer()
                Text("¥\(String(format: "%.0f", spent)) / ¥\(String(format: "%.0f", budget))")
                    .font(.caption)
                    .foregroundColor(over ? .red : .secondary)
                    .fontWeight(over ? .bold : .regular)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(over ? Color.red : cat.accentColor)
                        .frame(width: geo.size.width * ratio, height: 6)
                        .animation(.spring(response: 0.5), value: ratio)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - 累计金库卡片
    private var savingsVaultCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("💰 累计结余金库")
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                Text("¥\(String(format: "%.2f", totalSavings))")
                    .font(.title.bold())
                    .foregroundColor(.green)
            }
            Spacer()
            Image(systemName: "banknote.fill")
                .font(.system(size: 32))
                .foregroundColor(.green.opacity(0.6))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .green.opacity(0.08), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - 红黑榜卡片
    private var rankingCards: some View {
        HStack(spacing: 12) {
            // 结余榜
            Button {
                navigationPath.append(MonthListType.surplus)
            } label: {
                rankCard(
                    icon: "🟢",
                    title: "总计结余",
                    count: surplusMonths.count,
                    total: surplusMonths.reduce(0) { $0 + $1.remaining },
                    color: .green
                )
            }

            // 超支榜
            Button {
                navigationPath.append(MonthListType.deficit)
            } label: {
                rankCard(
                    icon: "🔴",
                    title: "总计超支",
                    count: deficitMonths.count,
                    total: deficitMonths.reduce(0) { $0 + abs($1.remaining) },
                    color: .red
                )
            }
        }
    }

    private func rankCard(icon: String, title: String, count: Int, total: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(icon).font(.title2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(title)
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            Text("\(count) 个月")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("¥\(String(format: "%.2f", total))")
                .font(.title3.bold())
                .foregroundColor(color)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        )
    }

    // MARK: - 导出按钮
    private var exportButton: some View {
        Button {
            exportCSV()
        } label: {
            Label("导出 CSV 备份", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .foregroundColor(.blue)
                .cornerRadius(12)
        }
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.subheadline.bold()).foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 重置当月
    private func resetCurrentMonth() {
        let toDelete = allRecords.filter { $0.date.isSameMonth(as: Date()) }
        toDelete.forEach { ctx.delete($0) }
        haptic.impactOccurred()
    }

    // MARK: - 导出CSV
    private func exportCSV() {
        var csv = "日期,类目,金额,备注\n"
        let sorted = allRecords.sorted { $0.date > $1.date }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        for r in sorted {
            csv += "\(fmt.string(from: r.date)),\(r.category.displayName),\(r.amount),\(r.note)\n"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("随手记账单.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?
            .rootViewController?.present(av, animated: true)
    }
}

// MARK: - 月份列表视图
enum MonthListType: Hashable { case surplus, deficit }

struct MonthListView: View {
    let months: [MonthSummary]
    let title: String
    let isSurplus: Bool

    var body: some View {
        List {
            ForEach(months) { summary in
                NavigationLink(value: summary) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(summary.year)年\(summary.month)月")
                                .font(.subheadline.bold())
                            Text("花费 ¥\(String(format: "%.2f", summary.spent))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text((isSurplus ? "+" : "") + "¥\(String(format: "%.2f", summary.remaining))")
                            .font(.subheadline.bold())
                            .foregroundColor(isSurplus ? .green : .red)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MonthSummary.self) { summary in
            MonthDetailView(summary: summary)
        }
    }
}

// MARK: - 月份详情（穿透下钻）
struct MonthDetailView: View {
    let summary: MonthSummary

    private var byCategory: [(ExpenseCategory, [ExpenseRecord])] {
        ExpenseCategory.allCases.compactMap { cat in
            let records = summary.records.filter { $0.category == cat }
            return records.isEmpty ? nil : (cat, records.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("总花费")
                    Spacer()
                    Text("¥\(String(format: "%.2f", summary.spent))")
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                }
                HStack {
                    Text("结余 / 超支")
                    Spacer()
                    Text("¥\(String(format: "%.2f", summary.remaining))")
                        .fontWeight(.bold)
                        .foregroundColor(summary.remaining >= 0 ? .green : .red)
                }
            } header: { Text("月度汇总") }

            ForEach(byCategory, id: \.0) { cat, records in
                Section {
                    ForEach(records) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.note.isEmpty ? "无备注" : r.note)
                                    .font(.subheadline)
                                Text(r.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("¥\(String(format: "%.2f", r.amount))")
                                .fontWeight(.semibold)
                                .foregroundColor(cat.accentColor)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    HStack {
                        Text("\(cat.icon) \(cat.displayName)")
                        Spacer()
                        Text("¥\(String(format: "%.2f", records.reduce(0){$0+$1.amount}))")
                            .fontWeight(.bold)
                    }
                }
            }
        }
        .navigationTitle("\(summary.year)年\(summary.month)月明细")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 月份汇总数据模型
struct MonthSummary: Hashable, Identifiable {
    var id: String { "\(year)-\(month)" }
    let year: Int
    let month: Int
    let spent: Double
    let budget: Double
    let records: [ExpenseRecord]

    var remaining: Double { budget - spent }

    func hash(into hasher: inout Hasher) {
        hasher.combine(year)
        hasher.combine(month)
    }

    static func == (lhs: MonthSummary, rhs: MonthSummary) -> Bool {
        lhs.year == rhs.year && lhs.month == rhs.month
    }
}
