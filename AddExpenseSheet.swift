// AddExpenseSheet.swift — 记账弹窗（支持补账）
import SwiftUI
import SwiftData

struct AddExpenseSheet: View {
    @Environment(\.modelContext) private var ctx
    @Environment(\.dismiss) private var dismiss

    var defaultCategory: ExpenseCategory

    @State private var selectedCategory: ExpenseCategory
    @State private var amount = ""
    @State private var note = ""
    @State private var selectedDate = Date()
    @State private var showDatePicker = false

    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let notificationHaptic = UINotificationFeedbackGenerator()

    init(defaultCategory: ExpenseCategory) {
        self.defaultCategory = defaultCategory
        _selectedCategory = State(initialValue: defaultCategory)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var dateButtonLabel: String {
        if isToday { return "今天（\(formattedDate(selectedDate)）" }
        return formattedDate(selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // 金额输入（大号，最突出）
                    amountSection

                    // 日期选择
                    dateSection

                    // 备注
                    noteSection

                    // 分类切换
                    categorySection

                    // 保存按钮
                    saveButton
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - 金额区
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("金额")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("¥")
                    .font(.title.bold())
                    .foregroundColor(selectedCategory.accentColor)
                TextField("0.00", text: $amount)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundColor(selectedCategory.accentColor)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - 日期区
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日期")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                Button {
                    withAnimation(.spring(response: 0.35)) {
                        showDatePicker.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(selectedCategory.accentColor)
                        Text(dateButtonLabel)
                            .font(.subheadline.bold())
                            .foregroundColor(isToday ? selectedCategory.accentColor : .primary)
                        if isToday {
                            Text("今天")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(selectedCategory.accentColor.opacity(0.15))
                                .foregroundColor(selectedCategory.accentColor)
                                .cornerRadius(6)
                        }
                        Spacer()
                        Image(systemName: showDatePicker ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                if showDatePicker {
                    Divider().padding(.horizontal, 16)
                    DatePicker(
                        "",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 8)
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }

    // MARK: - 备注区
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注（可选）")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            TextField("今天花了什么？", text: $note)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
        }
    }

    // MARK: - 分类切换
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = cat
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Text(cat.icon)
                                    .font(.subheadline)
                                Text(cat.displayName)
                                    .font(.subheadline.bold())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == cat
                                          ? cat.accentColor
                                          : Color(.secondarySystemGroupedBackground))
                            )
                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedCategory == cat ? Color.clear : Color(.systemGray4), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - 保存按钮
    private var saveButton: some View {
        Button {
            save()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(isToday ? "立即记账" : "补录账单")
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: amount.isEmpty || Double(amount) == nil
                        ? [Color.gray, Color.gray.opacity(0.7)]
                        : [selectedCategory.accentColor, selectedCategory.accentColor.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: selectedCategory.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(amount.isEmpty || Double(amount) == nil)
    }

    // MARK: - 保存逻辑
    private func save() {
        guard let amountVal = Double(amount), amountVal > 0 else {
            notificationHaptic.notificationOccurred(.error)
            return
        }
        let record = ExpenseRecord(
            amount: amountVal,
            note: note,
            date: selectedDate,
            category: selectedCategory
        )
        ctx.insert(record)
        haptic.impactOccurred()
        dismiss()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        f.locale = Locale(identifier: "zh_CN")
        return f.string(from: date)
    }
}
