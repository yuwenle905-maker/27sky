// CategoryView.swift — 前5个分类视图（仪表盘 + 时间轴列表）
import SwiftUI
import SwiftData

struct CategoryView: View {
    let category: ExpenseCategory

    @Environment(\.modelContext) private var ctx
    @Query private var allRecords: [ExpenseRecord]
    @Query private var budgets: [CategoryBudget]

    @State private var showAddSheet = false
    @State private var showBudgetEdit = false
    @State private var newBudgetText = ""
    @State private var showClearConfirm = false
    @State private var clearMode: ClearMode = .week
    @State private var recordToDelete: ExpenseRecord?
    @State private var showDeleteConfirm = false

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    enum ClearMode { case week, month }

    // 当前分类本月记录
    private var monthRecords: [ExpenseRecord] {
        allRecords.filter {
            $0.category == category && $0.date.isSameMonth(as: Date())
        }.sorted { $0.date > $1.date }
    }

    // 当前分类本周记录
    private var weekRecords: [ExpenseRecord] {
        let now = Date()
        return allRecords.filter {
            $0.category == category &&
            $0.date >= now.startOfWeek &&
            $0.date <= now.endOfWeek
        }
    }

    private var monthTotal: Double { monthRecords.reduce(0) { $0 + $1.amount } }
    private var weekTotal: Double  { weekRecords.reduce(0) { $0 + $1.amount } }

    private var budget: CategoryBudget? {
        budgets.first { $0.category == category }
    }

    private var remaining: Double {
        (budget?.monthlyBudget ?? 0) - monthTotal
    }

    private var isOverBudget: Bool { remaining < 0 }

    // 按日期分组
    private var groupedRecords: [(String, [ExpenseRecord])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        var dict: [String: [ExpenseRecord]] = [:]
        var order: [String] = []
        for r in monthRecords {
            let key = formatter.string(from: r.date)
            if dict[key] == nil {
                dict[key] = []
                order.append(key)
            }
            dict[key]!.append(r)
        }
        return order.map { ($0, dict[$0]!) }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 16) {
                        // 仪表盘卡片
                        dashboardCard
                        // 时间轴列表
                        timelineList
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 100)
                }
                .background(Color(.systemGroupedBackground))

                // 悬浮加号按钮
                addButton
            }
            .navigationTitle("\(category.icon) \(category.displayName)")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showAddSheet) {
            AddExpenseSheet(defaultCategory: category)
        }
        .alert("修改本月额度", isPresented: $showBudgetEdit) {
            TextField("输入新额度", text: $newBudgetText)
                .keyboardType(.decimalPad)
            Button("保存") {
                if let val = Double(newBudgetText), val > 0 {
                    budget?.monthlyBudget = val
                    haptic.impactOccurred()
                }
            }
            Button("取消", role: .cancel) {}
        }
        .confirmationDialog(
            "清空账单",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("清空本周账单", role: .destructive) {
                clearMode = .week
                clearRecords()
            }
            Button("清空本月账单", role: .destructive) {
                clearMode = .month
                clearRecords()
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 仪表盘卡片
    private var dashboardCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                // 月总计
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本月已花")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(monthTotal, specifier: "%.2f")")
                            .font(.title2.bold())
                            .foregroundColor(category.accentColor)
                    }
                    Spacer()
                    // 本周（住房不显示）
                    if category != .housing {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("本周已花")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("¥\(weekTotal, specifier: "%.2f")")
                                .font(.title3.bold())
                                .foregroundColor(category.accentColor)
                        }
                    }
                }

                Divider()

                // 剩余额度
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("本月额度")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("¥\(budget?.monthlyBudget ?? 0, specifier: "%.0f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isOverBudget ? "⚠️ 已超支" : "剩余额度")
                            .font(.caption)
                            .foregroundColor(isOverBudget ? .red : .secondary)
                        Text("¥\(remaining, specifier: "%.2f")")
                            .font(isOverBudget ? .title2 : .title3)
                            .fontWeight(isOverBudget ? .bold : .semibold)
                            .foregroundColor(isOverBudget ? .red : .green)
                            .scaleEffect(isOverBudget ? 1.05 : 1.0)
                            .animation(.spring(response: 0.3), value: isOverBudget)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
            )
            .onLongPressGesture {
                newBudgetText = String(format: "%.0f", budget?.monthlyBudget ?? 0)
                haptic.impactOccurred()
                showBudgetEdit = true
            }

            // 更多操作菜单
            Menu {
                Button(role: .destructive) {
                    clearMode = .week
                    showClearConfirm = true
                } label: {
                    Label("清空本周账单", systemImage: "trash")
                }
                Button(role: .destructive) {
                    clearMode = .month
                    showClearConfirm = true
                } label: {
                    Label("清空本月账单", systemImage: "trash.fill")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .padding(16)
            }
        }
    }

    // MARK: - 时间轴列表
    private var timelineList: some View {
        VStack(spacing: 0) {
            if groupedRecords.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("本月暂无记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                ForEach(groupedRecords, id: \.0) { dateStr, records in
                    VStack(alignment: .leading, spacing: 0) {
                        // 日期节点
                        HStack {
                            Circle()
                                .fill(category.accentColor)
                                .frame(width: 8, height: 8)
                            Text(dateStr)
                                .font(.caption.bold())
                                .foregroundColor(category.accentColor)
                            Spacer()
                            Text("¥\(records.reduce(0){$0+$1.amount}, specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // 当日记录
                        ForEach(records) { record in
                            recordRow(record)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private func recordRow(_ record: ExpenseRecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.note.isEmpty ? "无备注" : record.note)
                    .font(.subheadline)
                    .foregroundColor(record.note.isEmpty ? .secondary : .primary)
                Text(record.date, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("¥\(record.amount, specifier: "%.2f")")
                .font(.subheadline.bold())
                .foregroundColor(category.accentColor)

            // 删除按钮
            Button {
                recordToDelete = record
                showDeleteConfirm = true
                haptic.impactOccurred()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red.opacity(0.7))
                    .padding(.leading, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .alert("删除这笔账单？", isPresented: $showDeleteConfirm) {
            Button("删除", role: .destructive) {
                if let r = recordToDelete {
                    withAnimation(.spring(response: 0.35)) {
                        ctx.delete(r)
                    }
                    haptic.impactOccurred()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let r = recordToDelete {
                Text("¥\(r.amount, specifier: "%.2f")  \(r.note.isEmpty ? "无备注" : r.note)")
            }
        }
    }

    // MARK: - 悬浮加号
    private var addButton: some View {
        Button {
            haptic.impactOccurred()
            showAddSheet = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [category.accentColor, category.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: category.accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }

    // MARK: - 清空逻辑
    private func clearRecords() {
        let now = Date()
        let toDelete: [ExpenseRecord]
        switch clearMode {
        case .week:
            toDelete = allRecords.filter {
                $0.category == category &&
                $0.date >= now.startOfWeek &&
                $0.date <= now.endOfWeek
            }
        case .month:
            toDelete = monthRecords
        }
        toDelete.forEach { ctx.delete($0) }
        haptic.impactOccurred()
    }
}
